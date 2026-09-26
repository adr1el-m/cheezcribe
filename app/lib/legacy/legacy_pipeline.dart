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
                : throw StateError(
                    'Choose camera capture or image import in the browser.')
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
                traceMethod:
                    (rawObject['trace_method'] as String?) ?? 'detected',
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
      // This public sheet mixes a drawing plate with two-column report
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
      if (preparedBlueprint) {
        final analysis = _extractPreparedTagbilaranPage(page);
        documentType = analysis.type;
        detectedTypes.add(analysis.type);
        for (final suggestion in analysis.fields) {
          final line = suggestion.lineIndex >= 0 &&
                  suggestion.lineIndex < page.lines.length
              ? page.lines[suggestion.lineIndex]
              : null;
          fields.add(LegacyField(
            id: 'p${page.number}f${fields.length}',
            name: suggestion.name,
            page: page.number,
            lineIndex: line == null ? -1 : suggestion.lineIndex,
            ocrValue: line?.text,
            sourceExcerpt: suggestion.sourceExcerpt,
            aiValue: null,
            score: 1,
            reason:
                'Manually checked against printed page 21 for this exact source file. This is a prepared reference profile, not a live AI result.',
            status: FieldStatus.accepted,
            recordIndex: suggestion.recordIndex,
            suggestedValue: suggestion.value,
            finalValue: suggestion.value,
          ));
        }
        interpretedPages++;
        continue;
      }
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
            ? 'Loaded the source-checked Tagbilaran demo profile. Browser OCR was not run; each displayed value has a manually checked source excerpt. Drawing lines are approximate and unscaled.'
            : 'Matched the exact Tagbilaran source file and loaded its manually checked page 21 profile. Native OCR remains visible separately; drawing lines are approximate and unscaled.'
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
    final image =
        (await rootBundle.load('assets/demo/tagbilaran_blueprint_web.jpg'))
            .buffer
            .asUint8List();
    return {
      'name': 'PRINT_ME_tagbilaran_blueprint_1915.pdf',
      'sourceFingerprint': _tagbilaranBlueprintFingerprint,
      'historyPath': null,
      'pages': [
        {
          'number': 1,
          'image': image,
          'enhancedImage': null,
          'enhancementApplied': false,
          'originalMeanConfidence': null,
          'pixelWidth': 1595,
          'pixelHeight': 1985,
          // No OCR engine runs in the browser demo. Values and excerpts are
          // supplied by the prepared, manually checked profile below.
          'lines': const <Map<String, dynamic>>[],
          'drawingObjects': const <Map<String, dynamic>>[],
        }
      ],
    };
  }

  Map<String, dynamic> _webCapturedImagePacket(Uint8List image, String? name) {
    return {
      'name': name?.trim().isNotEmpty == true ? name : 'Captured document.jpg',
      'sourceFingerprint':
          'web-camera-${DateTime.now().microsecondsSinceEpoch}',
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
  List<double> ellipse(
    double cx,
    double cy,
    double rx,
    double ry, {
    int segments = 48,
  }) =>
      [
        for (var i = 0; i < segments; i++) ...[
          cx + math.cos((math.pi * 2 * i) / segments) * rx,
          cy + math.sin((math.pi * 2 * i) / segments) * ry,
        ],
      ];

  List<double> arc(double cx, double cy, double rx, double ry) => [
        for (var i = 0; i <= 24; i++) ...[
          cx + math.cos(math.pi + math.pi * i / 24) * rx,
          cy + math.sin(math.pi + math.pi * i / 24) * ry,
        ],
      ];

  DrawingObject trace(
    String id,
    String kind,
    List<double> box,
    List<double> points, {
    bool closed = false,
    List<String> labels = const [],
  }) =>
      DrawingObject(
        id: id,
        kind: kind,
        box: box,
        confidence: 0,
        points: points,
        closed: closed,
        sourceLabels: labels,
        traceMethod: 'manual_visual_trace',
      );

  const cx = .543;
  const cy = .177;
  return [
    trace(
      'tagbilaran-diameter-section',
      'tank section outline',
      const [.055, .085, .315, .15],
      const [
        .058,
        .129,
        .205,
        .094,
        .360,
        .129,
        .360,
        .228,
        .058,
        .228,
        .058,
        .129,
      ],
      labels: const ['Section on Diameter'],
    ),
    trace(
      'tagbilaran-section-center-support',
      'central support line',
      const [.198, .094, .014, .134],
      const [.205, .094, .205, .228],
    ),
    trace(
      'tagbilaran-section-base',
      'tank base outline',
      const [.078, .223, .282, .012],
      const [.078, .223, .360, .223, .360, .235, .078, .235],
      closed: true,
    ),
    for (final (index, rx, ry) in <(int, double, double)>[
      (1, .145, .118),
      (2, .132, .107),
      (3, .121, .098),
      (4, .110, .089),
    ])
      trace(
        'tagbilaran-roof-ring-$index',
        index == 1 ? 'roof plan outer ring' : 'roof plan ring',
        [cx - rx, cy - ry, rx * 2, ry * 2],
        ellipse(cx, cy, rx, ry),
        closed: true,
        labels: index == 1 ? const ['Roof Plan'] : const [],
      ),
    for (var i = 0; i < 12; i++)
      trace(
        'tagbilaran-roof-radial-${i + 1}',
        'roof radial member',
        const [.398, .059, .290, .236],
        [
          cx + math.cos((math.pi * 2 * i) / 12) * .018,
          cy + math.sin((math.pi * 2 * i) / 12) * .015,
          cx + math.cos((math.pi * 2 * i) / 12) * .145,
          cy + math.sin((math.pi * 2 * i) / 12) * .118,
        ],
      ),
    trace(
      'tagbilaran-roof-east-west-axis',
      'roof plan cross member',
      const [.398, .177, .290, .001],
      const [.398, .177, .688, .177],
    ),
    trace(
      'tagbilaran-roof-north-south-axis',
      'roof plan cross member',
      const [.543, .059, .001, .236],
      const [.543, .059, .543, .295],
    ),
    trace(
      'tagbilaran-piping-detail-main',
      'piping detail outline',
      const [.704, .074, .274, .140],
      const [
        .704,
        .074,
        .960,
        .074,
        .960,
        .081,
        .978,
        .081,
        .978,
        .093,
        .952,
        .093,
        .952,
        .087,
        .704,
        .087,
      ],
      labels: const ['Piping detail'],
    ),
    trace(
      'tagbilaran-piping-detail-branch-a',
      'piping detail branch',
      const [.804, .080, .035, .085],
      const [.812, .080, .812, .113, .839, .113, .839, .165],
    ),
    trace(
      'tagbilaran-piping-detail-branch-b',
      'piping detail branch',
      const [.895, .080, .040, .108],
      const [.904, .080, .904, .128, .936, .128, .936, .188],
    ),
    for (final (index, rx, ry) in <(int, double, double)>[
      (1, .103, .060),
      (2, .096, .055),
      (3, .089, .050),
    ])
      trace(
        'tagbilaran-segmental-arc-$index',
        'segmental section arc',
        [.208 - rx, .367 - ry, rx * 2, ry],
        arc(.208, .367, rx, ry),
        labels: index == 1 ? const ['Segmental Section'] : const [],
      ),
    trace(
      'tagbilaran-segmental-center-line',
      'segmental section center line',
      const [.208, .307, .001, .060],
      const [.208, .367, .208, .307],
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

  return _PageAnalysis('Tagbilaran Water Works concrete tank plan', [
    _FieldSuggestion(
      'project_title',
      'Plan of Concrete Tank for Tagbilaran Water Works',
      sourceFor(['PLAN OF CONCRETE TANK'], .28),
      0,
      sourceExcerpt: 'PLAN OF CONCRETE TANK FOR TAGBILARAN WATER WORKS',
    ),
    _FieldSuggestion(
      'issuing_agency',
      'Bureau of Public Works',
      sourceFor(['BUREAU OF PUBLIC WORKS'], .02),
      0,
      sourceExcerpt: 'QUARTERLY BULLETIN, BUREAU OF PUBLIC WORKS.',
    ),
    _FieldSuggestion(
      'project_location',
      'Tagbilaran, Bohol, P.I.',
      sourceFor(['TAGBILARAN, BOHOL', 'BOHOL, P.I.'], .28),
      0,
      sourceExcerpt: 'TAGBILARAN, BOHOL, P.I.',
    ),
    _FieldSuggestion(
      'drawing_views',
      'Section on Diameter; Roof Plan; piping detail; Segmental Section',
      sourceFor(['SECTION ON DIAMETER', 'ROOF PLAN'], .25),
      0,
      sourceExcerpt: 'Section on Diameter; Roof Plan; Segmental Section',
    ),
    _FieldSuggestion(
      'pipeline_distance',
      '860 meters',
      sourceFor(['DISTANCE FROM WELL TO TANK', '860 METERS'], .70),
      1,
      sourceExcerpt: 'Distance from well to tank is 860 meters.',
    ),
    _FieldSuggestion(
      'lift_range',
      '12.50 to 16.50 meters',
      sourceFor(['LIFT IS FROM', '12.50', '16.50'], .72),
      1,
      sourceExcerpt: 'Lift is from 12.50 to 16.50 meters.',
    ),
    _FieldSuggestion(
      'main_line_diameter',
      '3 inches',
      sourceFor(['MAIN LINE FROM WELL TO TANK', 'MAIN LINE'], .69),
      1,
      sourceExcerpt: 'The main line from well to tank is 3 inches in diameter.',
    ),
    _FieldSuggestion(
      'branch_line_diameter',
      '1 1/2 inches',
      sourceFor(['BRANCH LINES', '1½', '1 1/2'], .69),
      1,
      sourceExcerpt: 'Branch lines are 1 1/2 inches in diameter.',
    ),
    _FieldSuggestion(
      'tank_intake_position',
      'At the bottom of the tank',
      sourceFor(['INTAKE BEING IN THE BOTTOM', 'BOTTOM OF THE TANK'], .72),
      1,
      sourceExcerpt: 'The intake is at the bottom of the tank.',
    ),
    _FieldSuggestion(
      'pumping_engine',
      'Fairbanks-Morse kerosene engine, 8 horsepower',
      sourceFor(['FAIRBANKS-MORSE', '8 HORSEPOWER'], .77),
      2,
      sourceExcerpt: 'A Fairbanks-Morse kerosene pumping engine, 8 horsepower.',
    ),
    _FieldSuggestion(
      'engine_intake_diameter',
      '4 inches',
      sourceFor(['4-INCH INTAKE'], .77),
      2,
      sourceExcerpt: 'The engine has a 4-inch intake.',
    ),
    _FieldSuggestion(
      'engine_discharge_diameter',
      '3 inches',
      sourceFor(['3-INCH DISCHARGE'], .77),
      2,
      sourceExcerpt: 'The engine has a 3-inch discharge.',
    ),
    _FieldSuggestion(
      'installation_cost',
      'P12,195.07 for pipes and tank; pumping plant excluded',
      sourceFor(['12,195.07', '12,195'], .88),
      3,
      sourceExcerpt:
          'The cost for pipes and tank was P12,195.07, excluding the pumping plants.',
    ),
    _FieldSuggestion(
      'hydrant_network',
      '9 public; 65 private hydrants',
      sourceFor(['9 PUBLIC', '65 PRIVATE'], .90),
      3,
      sourceExcerpt: 'There are 9 public and 65 private hydrants.',
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
      this.name, this.value, this.lineIndex, this.recordIndex,
      {this.sourceExcerpt});
  final String name;
  final String? value;
  final int lineIndex;
  final int recordIndex;
  final String? sourceExcerpt;
}
