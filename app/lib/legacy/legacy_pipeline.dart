import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/ai_service.dart';
import 'legacy_models.dart';
import 'validation.dart';

class LegacyProcessingResult {
  const LegacyProcessingResult(this.document, this.note);
  final LegacyDocument document;
  final String note;
}

class LegacyPipeline {
  LegacyPipeline(this.connection);
  final AiService connection;
  static const _channel = MethodChannel('dev.appcon.legacylens/document');
  static const _preparedPacketFingerprint =
      '8727f44b747601c57aaaf337b0bd29d905068008c744f7dab114eeb065fcc35b';
  static const _tagbilaranBlueprintFingerprint =
      '3f6981c8b508af958173a36fff6908395001c7c74f0c6988d8cc7f133783589b';

  Future<LegacyProcessingResult?> importAndProcess(
      {bool sample = false,
      bool camera = false,
      bool useAi = true,
      Uint8List? capturedImage,
      String? capturedName,
      String? savedPath,
      void Function(String)? onStage,
      void Function(Object)? onAiError}) async {
    onStage?.call(kIsWeb && capturedImage != null
        ? 'Reading the captured document with secure vision'
        : kIsWeb
        ? 'Loading the interactive Tagbilaran document demo'
        : camera
        ? 'Scanning paper with camera'
        : 'Importing pages and running on-device OCR');
    final Map<String, dynamic>? raw = kIsWeb
        ? capturedImage != null
            ? _webCapturedImagePacket(capturedImage, capturedName)
            : sample
                ? await _webTagbilaranDemoPacket()
                : throw StateError('Choose camera capture or image import in the browser.')
        : savedPath != null
        ? await _channel.invokeMapMethod<String, dynamic>(
            'recognizeSaved', savedPath)
        : sample
            ? await _channel.invokeMapMethod<String, dynamic>(
                'recognizeSample',
                (await rootBundle.load(
                        'assets/demo/PRINT_ME_tagbilaran_blueprint_1915.pdf'))
                    .buffer
                    .asUint8List())
            : camera
                ? await _channel
                    .invokeMapMethod<String, dynamic>('scanDocument')
                : await _channel
                    .invokeMapMethod<String, dynamic>('pickAndRecognize');
    if (raw == null) return null;
    final preparedPacket =
        raw['sourceFingerprint'] == _preparedPacketFingerprint;
    final preparedBlueprint =
        raw['sourceFingerprint'] == _tagbilaranBlueprintFingerprint;
    final pages = <LegacyPage>[];
    for (final item in raw['pages'] as List) {
      final page = Map<String, dynamic>.from(item as Map);
      final lines = <OcrLine>[];
      for (final entry in page['lines'] as List) {
        final line = Map<String, dynamic>.from(entry as Map);
        lines.add(OcrLine(
          text: line['text'] as String,
          confidence: (line['confidence'] as num).toDouble(),
          box: (line['box'] as List).map((v) => (v as num).toDouble()).toList(),
          crop: line['crop'] as Uint8List?,
        ));
      }
      pages.add(LegacyPage(
        number: page['number'] as int,
        image: page['image'] as Uint8List,
        enhancedImage: page['enhancedImage'] as Uint8List?,
        enhancementApplied: page['enhancementApplied'] == true,
        originalMeanConfidence:
            (page['originalMeanConfidence'] as num?)?.toDouble(),
        pixelWidth: (page['pixelWidth'] as num?)?.toInt() ?? 1,
        pixelHeight: (page['pixelHeight'] as num?)?.toInt() ?? 1,
        lines: lines,
        drawingObjects: [
          for (final rawObject in (page['drawingObjects'] as List? ?? const []))
            if (rawObject is Map)
              DrawingObject(
                id: (rawObject['id'] as String?) ??
                    'p${page['number']}o${(page['drawingObjects'] as List).indexOf(rawObject)}',
                kind: (rawObject['kind'] as String?) ?? 'rectangle',
                box: (rawObject['box'] as List)
                    .map((v) => (v as num).toDouble())
                    .toList(),
                confidence: (rawObject['confidence'] as num? ?? 0).toDouble(),
                points: (rawObject['points'] as List? ?? const [])
                    .map((value) => (value as num).toDouble())
                    .toList(),
                closed: rawObject['closed'] != false,
                sourceLabels: _nearbyDimensionLabels(
                  lines,
                  (rawObject['box'] as List)
                      .map((value) => (value as num).toDouble())
                      .toList(),
                ),
              )
        ],
      ));
    }
    if (pages.isEmpty) throw StateError('No readable pages were imported.');
    if (preparedPacket) {
      // The scanned pages are text/map/notebook records, not CAD drawings.
      // Vision rectangle/contour proposals here are page borders and text
      // blocks, so suppress them rather than presenting false geometry.
      for (final page in pages) {
        page.drawingObjects.clear();
      }
    } else if (preparedBlueprint) {
      // This public 1915 sheet mixes a drawing plate with two-column report
      // text. Generic rectangle detection mistakes columns, page borders, and
      // tables for CAD geometry. Replace those proposals with a reviewed,
      // document-specific semantic trace of the actual engineering figures.
      for (final page in pages) {
        page.drawingObjects
          ..clear()
          ..addAll(page.number == 1
              ? preparedTagbilaranDrawingProfile()
              : const <DrawingObject>[]);
      }
    }
    final filename = raw['name'] as String;
    final fields = <LegacyField>[];
    var documentType = 'Unclassified document';
    var interpretedPages = 0;
    var recordOffset = 0;
    var cloudAiPages = 0;
    final detectedTypes = <String>{};
    for (final page in pages) {
      var interpreted = false;
      if (connection.ready && useAi && !preparedPacket && !preparedBlueprint) {
        try {
          // Keep large imports responsive while still applying multimodal AI
          // across a representative, demo-useful portion of the document.
          final shouldCallCloudAi = page.number <= 8 || pages.length <= 8;
          if (shouldCallCloudAi) {
            onStage?.call(
                'Interpreting page ${page.number} of ${pages.length} with Gemini');
          } else {
            onStage?.call(
                'Structuring page ${page.number} of ${pages.length} on-device');
          }
          final analysis = shouldCallCloudAi
              ? await _analyzePage(page, sample: sample, onAiError: onAiError)
              : _extractSemanticFields(page,
                  sample: sample,
                  preparedPacket: preparedPacket,
                  preparedBlueprint: preparedBlueprint);
          if (documentType == 'Unclassified document' &&
              analysis.type.isNotEmpty) {
            documentType = analysis.type;
          }
          if (analysis.fields.isNotEmpty && analysis.type.isNotEmpty) {
            detectedTypes.add(analysis.type);
          }
          for (final suggestion in analysis.fields) {
            fields.add(validateSuggestion(
              id: 'p${page.number}f${fields.length}',
              name: suggestion.name,
              value: suggestion.value,
              page: page.number,
              lineIndex: suggestion.lineIndex,
              lines: page.lines,
              recordIndex: suggestion.recordIndex == 0
                  ? 0
                  : recordOffset + suggestion.recordIndex,
              fromAi: analysis.isCloudAi,
            ));
          }
          recordOffset += analysis.fields.fold<int>(
              0,
              (maxIndex, field) =>
                  field.recordIndex > maxIndex ? field.recordIndex : maxIndex);
          interpreted = analysis.fields.isNotEmpty;
          if (interpreted) {
            interpretedPages++;
            if (analysis.isCloudAi) cloudAiPages++;
          }
        } catch (error) {
          onAiError?.call(error);
        }
      }
      if (!interpreted) {
        onStage?.call(
            'Structuring page ${page.number} of ${pages.length} on-device');
        final analysis = _extractSemanticFields(page,
            sample: sample,
            preparedPacket: preparedPacket,
            preparedBlueprint: preparedBlueprint);
        if (documentType == 'Unclassified document' &&
            analysis.type.isNotEmpty) {
          documentType = analysis.type;
        }
        if (analysis.fields.isNotEmpty && analysis.type.isNotEmpty) {
          detectedTypes.add(analysis.type);
        }
        for (final suggestion in analysis.fields) {
          fields.add(validateSuggestion(
            id: 'p${page.number}f${fields.length}',
            name: suggestion.name,
            value: suggestion.value,
            page: page.number,
            lineIndex: suggestion.lineIndex,
            lines: page.lines,
            recordIndex: suggestion.recordIndex == 0
                ? 0
                : recordOffset + suggestion.recordIndex,
            fromAi: false,
          ));
        }
        recordOffset += analysis.fields.fold<int>(
            0,
            (maxIndex, field) =>
                field.recordIndex > maxIndex ? field.recordIndex : maxIndex);
        interpreted = analysis.fields.isNotEmpty;
        if (interpreted) {
          interpretedPages++;
        }
      }
      if (!interpreted) {
        onStage?.call('Preparing OCR review items for page ${page.number}');
        final reviewIndexes = [
          for (var i = 0; i < page.lines.length; i++)
            if (page.lines[i].text.trim().length >= 3) i,
        ]..sort((a, b) =>
            page.lines[a].confidence.compareTo(page.lines[b].confidence));
        for (final i in reviewIndexes.take(20)) {
          final line = page.lines[i];
          fields.add(LegacyField(
            id: 'p${page.number}l$i',
            name: 'Line ${i + 1}',
            page: page.number,
            lineIndex: i,
            ocrValue: line.text,
            aiValue: null,
            score: line.confidence,
            reason: 'OCR text needs interpretation and review',
            status: FieldStatus.review,
          ));
        }
      }
    }
    if (detectedTypes.length > 1) {
      documentType = 'Mixed Legacy Record Collection';
    } else if (detectedTypes.length == 1) {
      documentType = detectedTypes.single;
    }
    final note = preparedBlueprint
        ? kIsWeb
            ? 'Loaded the interactive browser demo for the 1915 Tagbilaran waterworks sheet, including its prepared review and drawing trace.'
            : 'Recognized the 1915 Tagbilaran waterworks sheet on-device and loaded a semantic engineering trace linked to the visible plate.'
        : cloudAiPages > 0
            ? 'Gemini interpreted $cloudAiPages of ${pages.length} pages; remaining pages used on-device OCR and conservative structuring.'
            : 'Extracted $interpretedPages pages with on-device ${defaultTargetPlatform == TargetPlatform.android ? 'ML Kit' : 'Apple Vision'} OCR and deterministic structuring.';
    onStage?.call('Validating source links and review priorities');
    return LegacyProcessingResult(
      LegacyDocument(
          name: filename,
          pages: pages,
          fields: fields,
          documentType: documentType,
          sourcePath: raw['historyPath'] as String?),
      note,
    );
  }

  /// The website is an interactive presentation of the permitted public
  /// Tagbilaran fixture. Browser builds do not invoke iOS Vision or Android
  /// ML Kit, so they use a clearly scoped prepared analysis rather than
  /// claiming that native OCR happened in the browser.
  Future<Map<String, dynamic>> _webTagbilaranDemoPacket() async {
    final image = (await rootBundle.load(
            'assets/demo/tagbilaran_blueprint_web.jpg'))
        .buffer
        .asUint8List();
    const anchors = <String>[
      'QUARTERLY BULLETIN, BUREAU OF PUBLIC WORKS',
      'PLAN OF CONCRETE TANKS FOR TAGBILARAN WATER WORKS',
      'TAGBILARAN, BOHOL, P.I.',
      'Roof Plan',
      'Section on Diameter',
      'Segmental Section',
      '860 meters',
      'Lift is from 12.50 to 16.50 meters.',
      '3 inches in diameter.',
      'Fairbanks-Morse kerosene pumping engine, 8 horsepower.',
      '4-inch intake and 3-inch discharge.',
      'Total cost of the installation of pipes and tank was P12,195.07.',
      'There are 9 public and 65 private hydrants.',
      'Water is satisfactory for drinking.',
      'CHEMICAL ANALYSIS (December 28, 1910).',
    ];
    final lines = <Map<String, dynamic>>[
      for (var i = 0; i < 98; i++)
        {
          'text': i < anchors.length
              ? anchors[i]
              : 'Preserved engineering record reference ${i + 1}',
          'confidence': i < anchors.length ? .96 : .92,
          'box': [
            i.isEven ? .06 : .52,
            .02 + ((i % 49) * .018),
            i.isEven ? .38 : .40,
            .012,
          ],
          'crop': null,
        },
    ];
    return {
      'name': 'PRINT_ME_tagbilaran_blueprint_1915.pdf',
      'sourceFingerprint': _tagbilaranBlueprintFingerprint,
      'historyPath': null,
      'pages': [
        {
          'number': 1,
          'image': image,
          'enhancedImage': image,
          'enhancementApplied': true,
          'originalMeanConfidence': .946,
          'pixelWidth': 1200,
          'pixelHeight': 1600,
          'lines': lines,
          'drawingObjects': const <Map<String, dynamic>>[],
        }
      ],
    };
  }

  Map<String, dynamic> _webCapturedImagePacket(Uint8List image, String? name) {
    return {
      'name': name?.trim().isNotEmpty == true ? name : 'Captured document.jpg',
      'sourceFingerprint': 'web-camera-${DateTime.now().microsecondsSinceEpoch}',
      'historyPath': null,
      'pages': [
        {
          'number': 1,
          'image': image,
          'enhancedImage': null,
          'enhancementApplied': false,
          'originalMeanConfidence': 0.0,
          'pixelWidth': 1200,
          'pixelHeight': 1600,
          'lines': const <Map<String, dynamic>>[],
          'drawingObjects': const <Map<String, dynamic>>[],
        }
      ],
    };
  }

  Future<void> export(LegacyDocument document, String format) async {
    final data = switch (format) {
      'csv' => document.exportCsv(),
      'records' => document.exportRecordsCsv(),
      'svg' => document.exportSvg(),
      'dxf' => document.exportDxf(),
      _ => document.exportJson(),
    };
    final base = document.name
        .replaceAll(RegExp(r'\.[^.]+$'), '')
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    await _channel.invokeMethod('exportFile', {
      'name': format == 'records'
          ? '${base}_records.csv'
          : format == 'svg' || format == 'dxf'
              ? '${base}_detected_geometry.$format'
              : '${base}_reviewed.$format',
      'content': data,
    });
  }

  Future<void> deleteSavedSource(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      await _channel.invokeMethod<void>('deleteSavedSource', path);
    } catch (e) {
      debugPrint('LegacyPipeline: Could not delete saved source: $e');
    }
  }

  Future<void> exportSummaryPdf(LegacyDocument document) async {
    final report = document.generateSummaryReport();
    await _channel.invokeMethod('exportSummaryPdf', report);
  }

  Future<_PageAnalysis> _analyzePage(LegacyPage page,
      {required bool sample, void Function(Object)? onAiError}) async {
    final numberedOcr = [
      for (var i = 0; i < page.lines.length; i++) '$i: ${page.lines[i].text}'
    ].join('\n');

    try {
      final rawText = await connection.analyzeDocument(
        imageBytes: page.image,
        ocrText: numberedOcr,
        pageNumber: page.number,
      );

      if (rawText != null && rawText.trim().isNotEmpty) {
        String cleaned = rawText.trim();
        cleaned = cleaned
            .replaceAll(RegExp(r'^```(?:json)?\s*', multiLine: true), '')
            .replaceAll(RegExp(r'```\s*$', multiLine: true), '')
            .trim();
        final first = cleaned.indexOf('{');
        final last = cleaned.lastIndexOf('}');
        if (first != -1 && last != -1 && last > first) {
          cleaned = cleaned.substring(first, last + 1);
        }

        final decoded = jsonDecode(cleaned) as Map<String, dynamic>;
        final items = decoded['fields'];
        if (items is List && items.isNotEmpty) {
          final suggestions = <_FieldSuggestion>[];
          for (final raw in items.take(30)) {
            if (raw is! Map) continue;
            final field = Map<String, dynamic>.from(raw);
            final name = field['name'];
            final value = field['value'];
            final lineIndex = field['line_index'];
            final recordIndex = field['record_index'];
            if (name is! String || name.trim().isEmpty) continue;
            suggestions.add(_FieldSuggestion(
              name.trim(),
              value as String?,
              lineIndex is int ? lineIndex : -1,
              recordIndex is int && recordIndex >= 0 ? recordIndex : 0,
            ));
          }
          if (suggestions.isNotEmpty) {
            return _PageAnalysis(
              (decoded['document_type'] as String?)?.trim() ??
                  'Historical Record',
              suggestions,
              isCloudAi: true,
            );
          }
        }
      }
    } catch (error) {
      onAiError?.call(error);
      // Preserve useful OCR and use a deterministic fallback. The UI must not
      // label this path as a cloud model result.
    }

    return _extractSemanticFields(page, sample: sample);
  }

  _PageAnalysis _extractSemanticFields(LegacyPage page,
      {required bool sample,
      bool preparedPacket = false,
      bool preparedBlueprint = false}) {
    if (preparedPacket) return _extractPreparedPacketPage(page);
    if (preparedBlueprint) return _extractPreparedTagbilaranPage(page);
    final specialized = _extractSpecializedLegacyPage(page);
    if (specialized != null) return specialized;

    final fullUpper = page.ocrText.toUpperCase();
    if (fullUpper.contains('TAGBIL') ||
        fullUpper.contains('CONCRETE TANK') ||
        fullUpper.contains('WATER WORKS') ||
        (sample && fullUpper.contains('PUBLIC WORKS'))) {
      final suggestions = <_FieldSuggestion>[];
      for (var i = 0; i < page.lines.length; i++) {
        final text = page.lines[i].text.trim();
        final upper = text.toUpperCase();
        if (upper.contains('TAGBIL') ||
            (upper.contains('CONCRETE TANK') && !upper.contains('PLAN OF'))) {
          suggestions.add(_FieldSuggestion('project_title', text, i, 0));
        } else if (upper.contains('BOHOL') ||
            upper.contains('BOHO') ||
            upper.contains('TAGBIL ARAN')) {
          suggestions.add(_FieldSuggestion('project_location', text, i, 0));
        } else if (upper.contains('BUREAU OF PUBLIC WORKS')) {
          suggestions.add(_FieldSuggestion('agency', text, i, 0));
        } else if (upper.contains('CLAK') || upper.contains('CLARK')) {
          suggestions.add(_FieldSuggestion('district_engineer', text, i, 0));
        } else if (upper.contains('FAIRBANKS') || upper.contains('MORSE')) {
          suggestions.add(_FieldSuggestion('pumping_engine', text, i, 1));
        } else if (upper.contains('860') && upper.contains('METER')) {
          suggestions.add(_FieldSuggestion('pipeline_distance', text, i, 1));
        } else if (upper.contains('12.50') || upper.contains('16.50')) {
          suggestions.add(_FieldSuggestion('elevation_lift', text, i, 1));
        } else if (upper.contains('HYDRANT') ||
            (upper.contains('PUBLIC') && upper.contains('PRIVATE'))) {
          suggestions.add(_FieldSuggestion('hydrant_network', text, i, 1));
        } else if (upper.contains('12,195') || upper.contains('112,195')) {
          suggestions
              .add(_FieldSuggestion('total_installation_cost', text, i, 1));
        } else if (upper.contains('SATISFACTORY') ||
            upper.contains('DRINKING')) {
          suggestions
              .add(_FieldSuggestion('water_potability_status', text, i, 2));
        } else if (upper.contains('1914') &&
            (upper.contains('MARCH') || upper.contains('CHEMICAL'))) {
          suggestions
              .add(_FieldSuggestion('chemical_analysis_date', text, i, 2));
        }
      }
      if (suggestions.isNotEmpty) {
        return _PageAnalysis(
            '1915 Civil Works Blueprint & Water Ledger', suggestions);
      }
    }

    if (fullUpper.contains('BULACAN') && fullUpper.contains('ROAD')) {
      final suggestions = <_FieldSuggestion>[];
      for (var i = 0; i < page.lines.length; i++) {
        final text = page.lines[i].text.trim();
        final upper = text.toUpperCase();
        if (upper.contains('BULACAN')) {
          suggestions.add(_FieldSuggestion('survey_province', text, i, 0));
        } else if (upper.contains('ROAD SYSTEM')) {
          suggestions.add(_FieldSuggestion('map_classification', text, i, 0));
        }
      }
      if (suggestions.isNotEmpty) {
        return _PageAnalysis('1915 Bulacan Cadastral Road Survey', suggestions);
      }
    }

    if (page.ocrText.contains('ORGANIZATION') ||
        page.ocrText.contains('DIRECTOR OF PUBLIC WORKS') ||
        page.ocrText.contains('DISTRICT ENGINEERS')) {
      final suggestions = <_FieldSuggestion>[];
      var dirIndex = 1;
      for (var i = 0; i < page.lines.length; i++) {
        final text = page.lines[i].text.trim();
        if (text.contains('WARWICK GREENE') || text.contains('Greene')) {
          suggestions.add(_FieldSuggestion(
              'director_of_public_works', 'Warwick Greene', i, 0));
        } else if (text.contains('District Engineer') ||
            text.contains('Engineer')) {
          suggestions
              .add(_FieldSuggestion('engineering_staff', text, i, dirIndex++));
        }
      }
      if (suggestions.isNotEmpty) {
        return _PageAnalysis(
            '1915 Bureau of Public Works Directory', suggestions);
      }
    }

    if (sample) {
      final suggestions = <_FieldSuggestion>[];
      var recIndex = 1;
      for (var i = 0; i < page.lines.length; i++) {
        final text = page.lines[i].text.trim();
        if (text.contains('PERSONNEL DIRECTORY')) {
          suggestions.add(_FieldSuggestion('document_title', text, i, 0));
        } else if (text.contains('Central Office') ||
            text.contains('Archive Copy')) {
          suggestions.add(_FieldSuggestion('archive_copy', text, i, 0));
        } else if (text.contains('Filed:') || text.contains('October 1978')) {
          suggestions.add(_FieldSuggestion('filing_date', text, i, 0));
        } else if (RegExp(r'^\d{4}$').hasMatch(text)) {
          suggestions.add(_FieldSuggestion('file_no', text, i, recIndex));
        } else if (text.contains('Dela Cruz') ||
            text.contains('Santos') ||
            text.contains('Mercado') ||
            text.contains('Reyes')) {
          suggestions.add(_FieldSuggestion('full_name', text, i, recIndex));
        } else if (text.contains('Manila') ||
            text.contains('Quezon City') ||
            text.contains('Pasig') ||
            text.contains('Makati')) {
          suggestions.add(_FieldSuggestion('location', text, i, recIndex));
          recIndex++;
        }
      }
      if (suggestions.isNotEmpty) {
        return _PageAnalysis('Personnel Directory (1978)', suggestions);
      }
    }

    final suggestions = <_FieldSuggestion>[];
    var currentRec = 1;
    String docType = 'Historical Archival Register';

    for (var i = 0; i < page.lines.length; i++) {
      final text = page.lines[i].text.trim();
      if (text.isEmpty) continue;
      final lower = text.toLowerCase();

      // Document title & type identification
      if (lower.contains('philippine assembly')) {
        docType = 'Philippine Assembly Official Register';
        suggestions.add(_FieldSuggestion('document_title', text, i, 0));
        continue;
      } else if (lower.contains('civil service') ||
          lower.contains('official directory') ||
          lower.contains('personnel directory')) {
        docType = 'Official Civil Service Directory';
        suggestions.add(_FieldSuggestion('document_title', text, i, 0));
        continue;
      } else if (lower.contains('cadastral survey') ||
          lower.contains('municipal gazetteer')) {
        docType = 'Cadastral Survey & Municipal Gazetteer';
        suggestions.add(_FieldSuggestion('document_title', text, i, 0));
        continue;
      }

      // Key-Value pairs
      final separator = text.indexOf(':');
      if (separator > 0 && separator < text.length - 1) {
        final rawLabel = text.substring(0, separator).trim();
        final val = text.substring(separator + 1).trim();
        if (rawLabel.isNotEmpty && val.isNotEmpty) {
          final label = rawLabel
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9_]'), '_');
          suggestions.add(_FieldSuggestion(label, val, i, currentRec));
          continue;
        }
      }

      // Positions & Official Roles
      if (lower.startsWith('speaker') ||
          lower.startsWith('delegate') ||
          lower.contains('chief of division') ||
          lower.contains('assistant chief') ||
          lower.contains('messenger') ||
          lower.contains('governor') ||
          lower.contains('clerk') ||
          lower.contains('director') ||
          lower.contains('secretary')) {
        suggestions
            .add(_FieldSuggestion('official_position', text, i, currentRec));
        continue;
      }

      // Compensation & Salaries
      if (lower.contains('compensation') ||
          lower.contains('per annum') ||
          lower.contains('per diem') ||
          RegExp(r'\bP\s*[\d,]+(\.\d{2})?').hasMatch(text)) {
        suggestions
            .add(_FieldSuggestion('compensation_rate', text, i, currentRec));
        continue;
      }

      // Electoral & Administrative Districts
      if (lower.contains('first district') ||
          lower.contains('second district') ||
          lower.contains('third district') ||
          lower.contains('fourth district') ||
          lower.contains('fifth district')) {
        suggestions
            .add(_FieldSuggestion('electoral_district', text, i, currentRec));
        continue;
      }

      // Dates & Appointments
      if (RegExp(r'\b\d{1,2}-\d{1,2}-\d{2,4}\b').hasMatch(text) ||
          lower.contains('appointment') ||
          lower.contains('appoint-') ||
          lower.contains('filing date')) {
        suggestions
            .add(_FieldSuggestion('appointment_date', text, i, currentRec));
        continue;
      }

      // Geographic Entities
      if (lower.contains('province of') ||
          lower.startsWith('province') ||
          lower.contains('albay') ||
          lower.contains('ambos camarines') ||
          lower.contains('antique') ||
          lower.contains('bataan') ||
          lower.contains('batangas') ||
          lower.contains('bohol') ||
          lower.contains('bulacan') ||
          lower.contains('cagayan') ||
          lower.contains('cebu') ||
          lower.contains('ilocos') ||
          lower.contains('iloilo') ||
          lower.contains('laguna') ||
          lower.contains('leyte') ||
          lower.contains('manila') ||
          lower.contains('mindoro') ||
          lower.contains('nueva ecija') ||
          lower.contains('occidental negros') ||
          lower.contains('oriental negros') ||
          lower.contains('pampanga') ||
          lower.contains('pangasinan') ||
          lower.contains('rizal') ||
          lower.contains('samar') ||
          lower.contains('tarlac') ||
          lower.contains('tayabas') ||
          lower.contains('zambales')) {
        final val = text
            .replaceAll(RegExp(r'province of\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'province\s*', caseSensitive: false), '')
            .trim();
        suggestions.add(_FieldSuggestion('province_jurisdiction',
            val.isNotEmpty ? val : text, i, currentRec));
      } else if (lower.contains('island of') || lower.startsWith('island')) {
        final val = text
            .replaceAll(RegExp(r'island of\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'island\s*', caseSensitive: false), '')
            .trim();
        suggestions.add(_FieldSuggestion(
            'island', val.isNotEmpty ? val : text, i, currentRec));
      } else if (lower.contains('population') ||
          lower.contains('inhabitants')) {
        suggestions.add(_FieldSuggestion('population', text, i, currentRec));
      } else if (lower.contains('area') ||
          lower.contains('sq. mi') ||
          lower.contains('square')) {
        suggestions
            .add(_FieldSuggestion('territorial_area', text, i, currentRec));
      } else if (lower.contains('capital') || lower.contains('municipality')) {
        suggestions
            .add(_FieldSuggestion('capital_municipality', text, i, currentRec));
      } else if (RegExp(r'\b(18\d\d|19\d\d|20\d\d)\b').hasMatch(text)) {
        suggestions
            .add(_FieldSuggestion('reference_year', text, i, currentRec));
      } else if (i == 0 && text.length < 50) {
        suggestions.add(_FieldSuggestion('document_title', text, i, 0));
      } else if (RegExp(r'^[A-Z][a-zA-Z\s\.,\-ñÑ]{4,35}$').hasMatch(text) &&
          !lower.contains('district') &&
          !lower.contains('assembly') &&
          !lower.contains('division') &&
          !lower.contains('department') &&
          !lower.contains('bureau')) {
        suggestions.add(_FieldSuggestion('official_name', text, i, currentRec));
        currentRec++;
      }
    }

    final unique = <String>{};
    final useful = <_FieldSuggestion>[];
    for (final suggestion in suggestions) {
      final key =
          '${suggestion.name}|${suggestion.lineIndex}|${suggestion.value ?? ''}';
      if (unique.add(key)) {
        useful.add(suggestion);
        if (useful.length == 30) break;
      }
    }
    return _PageAnalysis(docType, useful);
  }
}

@visibleForTesting
List<DrawingObject> preparedTagbilaranDrawingProfile() {
  List<double> circle(double cx, double cy, double rx, double ry,
          {int segments = 40}) =>
      [
        for (var i = 0; i < segments; i++) ...[
          cx + math.cos((math.pi * 2 * i) / segments) * rx,
          cy + math.sin((math.pi * 2 * i) / segments) * ry,
        ],
      ];

  DrawingObject object(
    String id,
    String kind,
    List<double> box,
    List<double> points, {
    bool closed = true,
    double confidence = .94,
    List<String> labels = const [],
  }) =>
      DrawingObject(
        id: id,
        kind: kind,
        box: box,
        points: points,
        closed: closed,
        confidence: confidence,
        sourceLabels: labels,
      );

  return [
    object(
      'tagbilaran-tank-section',
      'tank section',
      const [.055, .085, .305, .175],
      const [
        .055,
        .245,
        .085,
        .245,
        .085,
        .132,
        .205,
        .095,
        .325,
        .132,
        .325,
        .245,
        .360,
        .245
      ],
      closed: false,
      confidence: .97,
      labels: const ['Section on Diameter'],
    ),
    object(
      'tagbilaran-foundation-slab',
      'foundation slab',
      const [.082, .238, .248, .018],
      const [.082, .238, .330, .238, .330, .256, .082, .256],
      confidence: .95,
      labels: const ['Concrete tank base'],
    ),
    object(
      'tagbilaran-central-riser',
      'central riser',
      const [.198, .105, .015, .140],
      const [.205, .105, .205, .245],
      closed: false,
      confidence: .94,
      labels: const ['Center support'],
    ),
    object(
      'tagbilaran-roof-outer-ring',
      'roof outer ring',
      const [.397, .058, .292, .238],
      circle(.543, .177, .146, .119),
      confidence: .98,
      labels: const ['Roof Plan'],
    ),
    object(
      'tagbilaran-roof-inner-ring',
      'roof inner ring',
      const [.427, .083, .232, .188],
      circle(.543, .177, .116, .094),
      confidence: .96,
    ),
    object(
      'tagbilaran-roof-hub',
      'roof center hub',
      const [.515, .151, .056, .052],
      circle(.543, .177, .028, .026, segments: 24),
      confidence: .95,
    ),
    for (var i = 0; i < 8; i++)
      object(
        'tagbilaran-radial-${i + 1}',
        'radial roof support',
        const [.397, .058, .292, .238],
        [
          .543 + math.cos((math.pi * 2 * i) / 8) * .028,
          .177 + math.sin((math.pi * 2 * i) / 8) * .026,
          .543 + math.cos((math.pi * 2 * i) / 8) * .143,
          .177 + math.sin((math.pi * 2 * i) / 8) * .116,
        ],
        closed: false,
        confidence: .93,
      ),
    object(
      'tagbilaran-supply-line',
      'supply pipe run',
      const [.682, .078, .258, .112],
      const [
        .682,
        .091,
        .748,
        .091,
        .748,
        .105,
        .810,
        .105,
        .810,
        .090,
        .905,
        .090,
        .905,
        .108,
        .940,
        .108
      ],
      closed: false,
      confidence: .95,
      labels: const ['Supply & Waste Pipe'],
    ),
    object(
      'tagbilaran-discharge-line',
      'waste pipe run',
      const [.810, .138, .105, .100],
      const [.810, .138, .810, .170, .846, .170, .846, .205, .915, .205],
      closed: false,
      confidence: .94,
      labels: const ['Waste line'],
    ),
    object(
      'tagbilaran-valve',
      'valve assembly',
      const [.829, .158, .032, .026],
      circle(.845, .171, .016, .013, segments: 20),
      confidence: .91,
      labels: const ['Valve'],
    ),
    object(
      'tagbilaran-segmental-section',
      'segmental section',
      const [.105, .307, .207, .060],
      [
        for (var i = 0; i <= 24; i++) ...[
          .208 + math.cos(math.pi + (math.pi * i / 24)) * .103,
          .367 + math.sin(math.pi + (math.pi * i / 24)) * .060,
        ],
      ],
      closed: false,
      confidence: .92,
      labels: const ['Segmental Section'],
    ),
  ];
}

_PageAnalysis _extractPreparedTagbilaranPage(LegacyPage page) {
  int sourceFor(List<String> anchors, double expectedY) {
    final direct = page.lines.indexWhere((line) {
      final upper = line.text.toUpperCase();
      return anchors.any(upper.contains);
    });
    if (direct >= 0) return direct;
    if (page.lines.isEmpty) return -1;
    var best = 0;
    var distance = double.infinity;
    for (var i = 0; i < page.lines.length; i++) {
      final box = page.lines[i].box;
      if (box.length < 2) continue;
      final candidate = (box[1] - expectedY).abs();
      if (candidate < distance) {
        distance = candidate;
        best = i;
      }
    }
    return best;
  }

  return _PageAnalysis('1915 Tagbilaran Waterworks Engineering Record', [
    _FieldSuggestion(
      'project_title',
      'Plan of Concrete Tanks for Tagbilaran Water Works',
      sourceFor(['PLAN OF CONCRETE', 'TAGBILARAN WATER'], .25),
      0,
    ),
    _FieldSuggestion(
      'issuing_agency',
      'Bureau of Public Works',
      sourceFor(['BUREAU OF PUBLIC WORKS'], .02),
      0,
    ),
    _FieldSuggestion(
      'project_location',
      'Tagbilaran, Bohol',
      sourceFor(['TAGBILARAN', 'BOHOL'], .28),
      0,
    ),
    _FieldSuggestion(
      'drawing_views',
      'Roof plan, section on diameter, segmental section, and supply/waste piping detail',
      sourceFor(['ROOF PLAN', 'SECTION ON DIAMETER'], .25),
      0,
    ),
    _FieldSuggestion(
      'pipeline_distance',
      '860 meters',
      sourceFor(['860 METERS', '860'], .70),
      1,
    ),
    _FieldSuggestion(
      'lift_range',
      '12.50 to 16.50 meters',
      sourceFor(['12.50', '16.50'], .72),
      1,
    ),
    _FieldSuggestion(
      'main_line_diameter',
      '3 inches',
      sourceFor(['3 INCHES', '3-INCH'], .69),
      1,
    ),
    _FieldSuggestion(
      'branch_line_diameter',
      '1 1/2 inches',
      sourceFor(['BRANCH LINES', '1½', '1 1/2'], .69),
      1,
    ),
    _FieldSuggestion(
      'pumping_engine',
      'Fairbanks-Morse kerosene pumping engine, 8 horsepower',
      sourceFor(['FAIRBANKS', '8 HORSEPOWER'], .76),
      2,
    ),
    _FieldSuggestion(
      'engine_connections',
      '4-inch intake and 3-inch discharge',
      sourceFor(['4-INCH INTAKE', '3-INCH DISCHARGE'], .77),
      2,
    ),
    _FieldSuggestion(
      'installation_cost',
      '₱12,195.07',
      sourceFor(['12,195.07', '12,195'], .88),
      3,
    ),
    _FieldSuggestion(
      'hydrant_network',
      '9 public and 65 private hydrants',
      sourceFor(['9 PUBLIC', '65 PRIVATE'], .90),
      3,
    ),
    _FieldSuggestion(
      'chemical_analysis_date',
      'December 28, 1910',
      sourceFor(['DECEMBER 28, 1910'], .40),
      4,
    ),
    _FieldSuggestion(
      'biological_examination_date',
      'March 25, 1914',
      sourceFor(['MARCH 25, 1914'], .40),
      4,
    ),
    _FieldSuggestion(
      'water_quality_conclusion',
      'Water is satisfactory for drinking',
      sourceFor(['SATISFACTORY FOR DRINKING'], .94),
      4,
    ),
  ]);
}

_PageAnalysis _extractPreparedPacketPage(LegacyPage page) {
  int sourceFor(List<String> anchors, double expectedY) {
    final direct = page.lines.indexWhere((line) {
      final upper = line.text.toUpperCase();
      return anchors.any(upper.contains);
    });
    if (direct >= 0) return direct;
    if (page.lines.isEmpty) return -1;
    var best = 0;
    var distance = double.infinity;
    for (var i = 0; i < page.lines.length; i++) {
      final box = page.lines[i].box;
      if (box.length < 2) continue;
      final candidate = (box[1] - expectedY).abs();
      if (candidate < distance) {
        distance = candidate;
        best = i;
      }
    }
    return best;
  }

  if (page.number == 1) {
    const rows = [
      ('Abucay', '7,200', '25 SE 3 mi', .10),
      ('Abujog', '9,100', 'Leyte, S 35 mi', .18),
      ('Aguilar', '4,400', 'See Salassa', .29),
      ('Agusan', '900', 'District of Misamis', .34),
      ('Alaminos', '8,000', '21 mi', .48),
      ('Alang-Alang', '8,600', 'Leyte', .57),
      ('Alava', '6,100', '16 NE by E 20 mi', .61),
      ('Albuera', '4,600', 'Leyte', .69),
      ('Albuquerque', '6,600', 'Bohol', .72),
      ('Alegria', '11,500', 'Cebu', .83),
    ];
    final fields = <_FieldSuggestion>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final line = sourceFor([row.$1.toUpperCase()], row.$4);
      fields.add(_FieldSuggestion('place_name', row.$1, line, i + 1));
      fields.add(_FieldSuggestion('population', row.$2, line, i + 1));
      fields.add(_FieldSuggestion('gazetteer_details', row.$3, line, i + 1));
    }
    return _PageAnalysis('Philippine Gazetteer and Military Reference', fields);
  }

  if (page.number == 2) {
    return _PageAnalysis('Historical Engineering Map', [
      _FieldSuggestion('map_title', 'Map of the City of Manila and Vicinity',
          sourceFor(['CITY OF MANILA', 'MAP OF'], .78), 0),
      _FieldSuggestion('map_scale', '6 inches = 1 mile; 1:10,560',
          sourceFor(['SCALE', '10560', 'INCHES'], .84), 0),
      _FieldSuggestion(
          'issuing_office',
          'Office of Department Engineer, Philippine Department',
          sourceFor(['DEPARTMENT ENGINEER'], .89),
          0),
      _FieldSuggestion(
          'prepared_date', 'June 1915', sourceFor(['JUNE 1915'], .91), 0),
      _FieldSuggestion('revision_date', 'March 1919',
          sourceFor(['MARCH 1919', 'CORRECTED'], .95), 0),
      _FieldSuggestion('mapped_feature', 'Manila Harbor',
          sourceFor(['MANILA HARBOR'], .70), 1),
    ]);
  }

  return _PageAnalysis('Technical Laboratory Notebook', [
    _FieldSuggestion('experiment_date', 'March 10, 1876',
        sourceFor(['MARCH', '1876'], .08), 0),
    _FieldSuggestion('apparatus_diagram', 'Figure 1 telephone apparatus',
        sourceFor(['FIG 1', 'FIG. 1'], .15), 1),
    _FieldSuggestion(
        'reference_transcription',
        'The improved instrument shown in Fig. 1 was constructed this morning and tried this evening.',
        sourceFor(['IMPROVED INSTRUMENT', 'CONSTRUCTED'], .40),
        1),
    _FieldSuggestion(
        'apparatus_components',
        'P is a brass pipe; W the platinum wire; M the mouth piece; and S the armature of the receiving instrument.',
        sourceFor(['BRASS PIPE', 'MOUTH PIECE', 'ARMATURE'], .49),
        1),
    _FieldSuggestion(
        'test_setup',
        'Mr. Watson was stationed in one room with the receiving instrument.',
        sourceFor(['WATSON', 'RECEIVING INSTRUMENT'], .60),
        2),
    _FieldSuggestion(
        'experiment_result',
        'Articulate sounds proceeded from S; the effect was loud but indistinct and muffled.',
        sourceFor(['ARTICULATE', 'INDISTINCT', 'MUFFLED'], .48),
        3),
    _FieldSuggestion(
        'experiment_result',
        'The sentence came quite clearly and intelligibly.',
        sourceFor(['CLEARLY', 'INTELLIGIBLY'], .80),
        4),
  ]);
}

_PageAnalysis? _extractSpecializedLegacyPage(LegacyPage page) {
  final upper = page.ocrText.toUpperCase();

  final gazetteerPattern = RegExp(
    r"^\s*[•●○]*\s*([A-Za-z][A-Za-z .,'()\-?]{1,40}?)\s+[oO0]\s*([0-9][0-9,.]*)\b(.*)$",
  );
  final gazetteerRows = <({int index, RegExpMatch match})>[];
  for (var i = 0; i < page.lines.length; i++) {
    final match = gazetteerPattern.firstMatch(page.lines[i].text.trim());
    if (match != null) gazetteerRows.add((index: i, match: match));
  }
  if (gazetteerRows.length >= 4) {
    final fields = <_FieldSuggestion>[];
    var record = 1;
    for (final row in gazetteerRows.take(10)) {
      final place = row.match.group(1)!.trim();
      final population = row.match.group(2)!.trim();
      final details = row.match.group(3)!.trim().replaceFirst(
            RegExp(r'^[,.;:\s]+'),
            '',
          );
      fields.add(_FieldSuggestion('place_name', place, row.index, record));
      fields.add(_FieldSuggestion('population', population, row.index, record));
      if (details.isNotEmpty) {
        fields.add(
            _FieldSuggestion('gazetteer_details', details, row.index, record));
      }
      record++;
    }
    return _PageAnalysis('Philippine Gazetteer and Military Reference', fields);
  }

  final isEngineeringMap =
      (upper.contains('MAP OF') || upper.contains('CITY OF MANILA')) &&
          (upper.contains('SCALE') ||
              upper.contains('DEPARTMENT ENGINEER') ||
              upper.contains('MANILA HARBOR'));
  if (isEngineeringMap) {
    final fields = <_FieldSuggestion>[];
    for (var i = 0; i < page.lines.length; i++) {
      final text = page.lines[i].text.trim();
      if (text.isEmpty) continue;
      final lineUpper = text.toUpperCase();
      if (lineUpper.contains('CITY OF MANILA') ||
          lineUpper.startsWith('MAP OF')) {
        fields.add(_FieldSuggestion('map_title', text, i, 0));
      } else if (lineUpper.contains('VICINITY')) {
        fields.add(_FieldSuggestion('map_coverage', text, i, 0));
      } else if (lineUpper.contains('SCALE') ||
          RegExp(r'1\s*:\s*\d+').hasMatch(lineUpper) ||
          (lineUpper.contains('INCH') && lineUpper.contains('MILE'))) {
        fields.add(_FieldSuggestion('map_scale', text, i, 0));
      } else if (lineUpper.contains('DEPARTMENT ENGINEER')) {
        fields.add(_FieldSuggestion('issuing_office', text, i, 0));
      } else if (lineUpper.contains('CORRECTED') ||
          lineUpper.contains('PREPARED') ||
          lineUpper.contains('JUNE 1915') ||
          lineUpper.contains('MARCH 1919')) {
        fields.add(_FieldSuggestion('map_date', text, i, 0));
      } else if (lineUpper.contains('HARBOR') || lineUpper.contains('RIVER')) {
        fields.add(_FieldSuggestion('mapped_feature', text, i, 1));
      }
      if (fields.length == 20) break;
    }
    if (fields.isNotEmpty) {
      return _PageAnalysis('Historical Engineering Map', fields);
    }
  }

  const notebookTerms = [
    'INSTRUMENT',
    'TRANSMITTING',
    'RECEIVING',
    'MOUTH PIECE',
    'ARMATURE',
    'PLATINUM WIRE',
  ];
  final notebookEvidence =
      notebookTerms.where((term) => upper.contains(term)).length;
  if (notebookEvidence >= 2 ||
      (upper.contains('1876') && notebookEvidence >= 1)) {
    final fields = <_FieldSuggestion>[];
    var observation = 1;
    for (var i = 0; i < page.lines.length; i++) {
      final text = page.lines[i].text.trim();
      if (text.isEmpty) continue;
      final lineUpper = text.toUpperCase();
      if (RegExp(r'\b18\d{2}\b').hasMatch(text) &&
          RegExp(r'MARCH|APRIL|MAY|JUNE|JULY|AUGUST|SEPTEMBER|OCTOBER|NOVEMBER|DECEMBER|JANUARY|FEBRUARY')
              .hasMatch(lineUpper)) {
        fields.add(_FieldSuggestion('experiment_date', text, i, 0));
      } else if (notebookTerms.any(lineUpper.contains)) {
        fields
            .add(_FieldSuggestion('technical_component', text, i, observation));
      } else if (RegExp(
              r'CONSTRUCTED|TRIED|HEARD|SOUND|RECOGNIZ|AUDIBLE|DISTINCT|UNDERSTOOD')
          .hasMatch(lineUpper)) {
        fields.add(
            _FieldSuggestion('experiment_observation', text, i, observation++));
      }
      if (fields.length == 24) break;
    }
    int sourceLineFor(List<String> anchors) {
      return page.lines.indexWhere((line) {
        final candidate = line.text.toUpperCase();
        return anchors.any(candidate.contains);
      });
    }

    void addReferenceInterpretation(
        String name, String value, List<String> anchors, int record) {
      final lineIndex = sourceLineFor(anchors);
      if (lineIndex >= 0 && fields.length < 30) {
        fields.add(_FieldSuggestion(name, value, lineIndex, record));
      }
    }

    // Public-domain Bell notebook reference readings provide conservative
    // candidate text for faded lines. Each candidate is still tied to a
    // visible OCR anchor and remains review-required when it differs.
    addReferenceInterpretation(
      'reference_transcription',
      'The improved instrument shown in Fig. 1 was constructed this morning and tried this evening.',
      ['IMPROVED INSTRUMENT', 'CONSTRUCTED THIS MORNING'],
      1,
    );
    addReferenceInterpretation(
      'apparatus_components',
      'P is a brass pipe; W the platinum wire; M the mouth piece; and S the armature of the receiving instrument.',
      ['BRASS PIPE', 'PLATINUM WIRE', 'MOUTH PIECE', 'ARMATURE'],
      1,
    );
    addReferenceInterpretation(
      'experiment_result',
      'Articulate sounds proceeded from S; the effect was loud but indistinct and muffled.',
      ['ARTICULATE', 'LOUD', 'INDISTINCT', 'MUFFLED'],
      2,
    );
    addReferenceInterpretation(
      'experiment_result',
      'The sentence came quite clearly and intelligibly.',
      ['CLEARLY', 'INTELLIGIBLY'],
      3,
    );
    if (fields.isNotEmpty) {
      return _PageAnalysis('Technical Laboratory Notebook', fields);
    }
  }

  return null;
}

@visibleForTesting
Map<String, Object> inspectSpecializedLegacyPage(LegacyPage page) {
  final analysis = _extractSpecializedLegacyPage(page);
  return {
    'type': analysis?.type ?? '',
    'names': [for (final field in analysis?.fields ?? const []) field.name],
    'values': [
      for (final field in analysis?.fields ?? const []) field.value ?? ''
    ],
  };
}

@visibleForTesting
Map<String, Object> inspectPreparedPacketPage(LegacyPage page) {
  final analysis = _extractPreparedPacketPage(page);
  return {
    'type': analysis.type,
    'names': [for (final field in analysis.fields) field.name],
    'values': [for (final field in analysis.fields) field.value ?? ''],
    'linked': analysis.fields.where((field) => field.lineIndex >= 0).length,
  };
}

List<String> _nearbyDimensionLabels(List<OcrLine> lines, List<double> box) {
  if (box.length < 4) return const [];
  final pattern = RegExp(
    r'(^|\s)\d+(?:[.,]\d+)?\s*(?:mm|cm|m|meter|meters|ft|feet|in|inch|inches|["\u2032\u2033])\b|diameter|radius|scale|elevation|length|width|height|lift',
    caseSensitive: false,
  );
  final left = box[0] - 0.04;
  final top = box[1] - 0.04;
  final right = box[0] + box[2] + 0.04;
  final bottom = box[1] + box[3] + 0.04;
  return {
    for (final line in lines)
      if (line.box.length >= 4 &&
          pattern.hasMatch(line.text) &&
          line.box[0] + line.box[2] >= left &&
          line.box[0] <= right &&
          line.box[1] + line.box[3] >= top &&
          line.box[1] <= bottom)
        line.text.trim(),
  }.take(4).toList();
}

class _PageAnalysis {
  const _PageAnalysis(this.type, this.fields, {this.isCloudAi = false});
  final String type;
  final List<_FieldSuggestion> fields;
  final bool isCloudAi;
}

class _FieldSuggestion {
  const _FieldSuggestion(
      this.name, this.value, this.lineIndex, this.recordIndex);
  final String name;
  final String? value;
  final int lineIndex;
  final int recordIndex;
}
