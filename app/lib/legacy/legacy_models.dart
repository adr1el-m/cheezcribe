import 'dart:convert';
import 'dart:typed_data';

class OcrLine {
  const OcrLine(
      {required this.text,
      required this.confidence,
      required this.box,
      this.crop});
  final String text;
  final double confidence;

  /// Normalized left, top, width, height in the displayed page image.
  final List<double> box;
  final Uint8List? crop;
}

class LegacyPage {
  const LegacyPage(
      {required this.number,
      required this.image,
      required this.lines,
      this.enhancedImage,
      this.enhancementApplied = false,
      this.originalMeanConfidence,
      this.drawingObjects = const []});
  final int number;

  /// The untouched page used for evidence and export provenance.
  final Uint8List image;

  /// A contrast-normalized derivative used only to improve recognition.
  final Uint8List? enhancedImage;
  final bool enhancementApplied;
  final double? originalMeanConfidence;
  final List<OcrLine> lines;
  final List<DrawingObject> drawingObjects;
  String get ocrText => lines.map((line) => line.text).join('\n');
}

/// A deliberately narrow CAD primitive detected from a drawing page.
/// Coordinates are normalized to the page. Geometry remains unitless until a
/// reviewer supplies a scale; this avoids pretending pixels are engineering
/// measurements.
class DrawingObject {
  const DrawingObject({
    required this.id,
    required this.kind,
    required this.box,
    required this.confidence,
  });

  final String id;
  final String kind;
  final List<double> box;
  final double confidence;

  Map<String, Object> toJson() => {
        'id': id,
        'kind': kind,
        'box': box.map((v) => double.parse(v.toStringAsFixed(5))).toList(),
        'confidence': double.parse(confidence.toStringAsFixed(3)),
        'units': 'normalized_page',
        'review_required': true,
      };
}

enum FieldStatus { ready, review, accepted, edited, unreadable }

class LegacyField {
  const LegacyField({
    required this.id,
    required this.name,
    required this.page,
    required this.lineIndex,
    required this.ocrValue,
    required this.aiValue,
    required this.score,
    required this.reason,
    required this.status,
    this.recordIndex = 0,
    this.finalValue,
  });
  final String id;
  final String name;
  final int page;
  final int lineIndex;
  final String? ocrValue;
  final String? aiValue;

  /// Review priority estimate from observable signals; not a probability.
  final double score;
  final String reason;
  final FieldStatus status;

  /// Zero is document metadata; positive values group fields into records.
  final int recordIndex;
  final String? finalValue;

  bool get needsReview => status == FieldStatus.review;
  bool get resolved => status != FieldStatus.review;

  LegacyField decide(FieldStatus decision, String? value) => LegacyField(
        id: id,
        name: name,
        page: page,
        lineIndex: lineIndex,
        ocrValue: ocrValue,
        aiValue: aiValue,
        score: score,
        reason: reason,
        status: decision,
        recordIndex: recordIndex,
        finalValue: decision == FieldStatus.unreadable ? null : value,
      );

  Map<String, Object?> toJson() => {
        'record': recordIndex,
        'name': name,
        'value': finalValue,
        'status': status.name,
        'page': page,
        'source_line': lineIndex,
        'ocr_value': ocrValue,
        'ai_suggestion': aiValue,
        'review_score': double.parse(score.toStringAsFixed(2)),
        'review_reason': reason,
      };
}

class LegacyDocument {
  LegacyDocument(
      {required this.name,
      required this.pages,
      required this.fields,
      required this.documentType});
  final String name;
  final List<LegacyPage> pages;
  List<LegacyField> fields;
  final String documentType;
  int get needsReview => fields.where((f) => f.needsReview).length;
  int get resolved => fields.where((f) => f.resolved).length;
  int get readyCandidates =>
      fields.where((f) => f.status == FieldStatus.ready).length;
  bool get hasRecords => fields.any((f) => f.recordIndex > 0);
  int get totalOcrLines =>
      pages.fold(0, (total, page) => total + page.lines.length);
  double get meanOcrConfidence {
    if (totalOcrLines == 0) return 0;
    final total = pages.fold<double>(
        0, (sum, page) => sum + page.lines.fold(0, (s, l) => s + l.confidence));
    return total / totalOcrLines;
  }

  int get lowConfidenceLines => pages.fold(
      0,
      (total, page) =>
          total + page.lines.where((line) => line.confidence < 0.80).length);
  int get drawingObjectCount =>
      pages.fold(0, (total, page) => total + page.drawingObjects.length);
  double get sourceLinkedRate => fields.isEmpty
      ? 0
      : fields.where((f) => f.lineIndex >= 0).length / fields.length;

  Map<String, Object> get qualityReport => {
        'ocr_lines': totalOcrLines,
        'mean_ocr_confidence':
            double.parse(meanOcrConfidence.toStringAsFixed(3)),
        'low_confidence_lines': lowConfidenceLines,
        'source_linked_rate': double.parse(sourceLinkedRate.toStringAsFixed(3)),
        'fields_requiring_review': needsReview,
        'reviewed_or_ready_fields': resolved,
        'enhanced_pages': pages.where((p) => p.enhancementApplied).length,
        'drawing_objects': drawingObjectCount,
        'claim_boundary':
            'Quality indicators route review; they are not an accuracy percentage.',
      };

  void decide(String id, FieldStatus decision, String? value) {
    fields = [
      for (final field in fields)
        field.id == id ? field.decide(decision, value) : field
    ];
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'format': 'legacylens.v1',
        'source': name,
        'document_type': documentType,
        'field_count': fields.length,
        'requires_review': needsReview,
        'quality': qualityReport,
        'drawings': [
          for (final page in pages)
            if (page.drawingObjects.isNotEmpty)
              {
                'page': page.number,
                'objects': page.drawingObjects.map((o) => o.toJson()).toList(),
              }
        ],
        'fields': fields.map((field) => field.toJson()).toList(),
      });

  String exportSvg() {
    final objects = pages.expand((page) => page.drawingObjects).toList();
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln(
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 1000">')
      ..writeln(
          '<!-- Unitless detected rectangles. Review and set scale before engineering use. -->')
      ..writeln('<g fill="none" stroke="#2563eb" stroke-width="3">');
    for (final object in objects) {
      if (object.box.length < 4) continue;
      final x = object.box[0] * 1000;
      final y = object.box[1] * 1000;
      final width = object.box[2] * 1000;
      final height = object.box[3] * 1000;
      buffer.writeln(
          '<rect id="${object.id}" x="${x.toStringAsFixed(2)}" y="${y.toStringAsFixed(2)}" width="${width.toStringAsFixed(2)}" height="${height.toStringAsFixed(2)}" data-confidence="${object.confidence.toStringAsFixed(3)}"/>');
    }
    buffer.writeln('</g></svg>');
    return buffer.toString();
  }

  String exportDxf() {
    final buffer = StringBuffer()
      ..writeln('0\nSECTION\n2\nHEADER\n0\nENDSEC')
      ..writeln('0\nSECTION\n2\nENTITIES');
    for (final object in pages.expand((page) => page.drawingObjects)) {
      if (object.box.length < 4) continue;
      final x1 = object.box[0] * 1000;
      final y1 = (1 - object.box[1] - object.box[3]) * 1000;
      final x2 = x1 + object.box[2] * 1000;
      final y2 = y1 + object.box[3] * 1000;
      buffer
        ..writeln('0\nLWPOLYLINE\n8\nDETECTED_GEOMETRY\n90\n4\n70\n1')
        ..writeln('10\n${x1.toStringAsFixed(3)}\n20\n${y1.toStringAsFixed(3)}')
        ..writeln('10\n${x2.toStringAsFixed(3)}\n20\n${y1.toStringAsFixed(3)}')
        ..writeln('10\n${x2.toStringAsFixed(3)}\n20\n${y2.toStringAsFixed(3)}')
        ..writeln('10\n${x1.toStringAsFixed(3)}\n20\n${y2.toStringAsFixed(3)}');
    }
    buffer.writeln('0\nENDSEC\n0\nEOF');
    return buffer.toString();
  }

  String exportCsv() {
    const columns = [
      'record',
      'name',
      'value',
      'status',
      'page',
      'source_line',
      'ocr_value',
      'ai_suggestion',
      'review_score',
      'review_reason'
    ];
    String cell(Object? value) =>
        '"${(value ?? '').toString().replaceAll('"', '""')}"';
    return [
      columns.join(','),
      for (final field in fields)
        columns.map((key) => cell(field.toJson()[key])).join(',')
    ].join('\r\n');
  }

  /// A wide table for document types with entries such as directories.
  /// Field-level CSV and JSON retain the complete review provenance.
  String exportRecordsCsv() {
    final records = <int, List<LegacyField>>{};
    final names = <String>{};
    for (final field in fields.where((f) => f.recordIndex > 0)) {
      records.putIfAbsent(field.recordIndex, () => []).add(field);
      names.add(field.name);
    }
    final columns = names.toList();
    String cell(Object? value) =>
        '"${(value ?? '').toString().replaceAll('"', '""')}"';
    return [
      ['record', 'review_state', ...columns].join(','),
      for (final entry in records.entries)
        [
          cell(entry.key),
          cell(entry.value.any((f) => f.needsReview)
              ? 'requires_review'
              : 'ready'),
          for (final name in columns)
            cell(entry.value
                .where((f) => f.name == name)
                .firstOrNull
                ?.finalValue),
        ].join(','),
    ].join('\r\n');
  }

  String generateExecutiveAbstract() {
    final pageCount = pages.length;
    return 'This $documentType contains $pageCount scanned page${pageCount == 1 ? '' : 's'}. '
        'LegacyLens preserved the source, extracted $totalOcrLines OCR lines, and prepared '
        '${fields.length} reviewable structured fields with source references. '
        '$needsReview unresolved value${needsReview == 1 ? '' : 's'} remain explicitly marked for human review.';
  }

  Map<String, dynamic> generateSummaryReport() {
    final abstractText = generateExecutiveAbstract();
    final totalLines = pages.fold<int>(0, (acc, p) => acc + p.lines.length);
    final avgConfidence = totalLines == 0
        ? 0.0
        : pages.fold<double>(
                0.0,
                (acc, p) =>
                    acc +
                    p.lines
                        .fold<double>(0.0, (lAcc, l) => lAcc + l.confidence)) /
            totalLines;

    final keyEntities = <Map<String, String>>[];
    for (final field in fields.take(25)) {
      final val = field.finalValue ?? field.aiValue ?? field.ocrValue;
      if (val != null && val.trim().isNotEmpty) {
        keyEntities.add({
          'record': '${field.recordIndex}',
          'name': field.name,
          'value': val.trim(),
          'status': field.status.name,
        });
      }
    }

    return {
      'title': name.replaceAll(RegExp(r'\.[^.]+$'), '').replaceAll('_', ' '),
      'documentType': documentType,
      'pageCount': pages.length,
      'filename': name,
      'abstract': abstractText,
      'fieldCount': fields.length,
      'needsReview': needsReview,
      'resolved': resolved,
      'qualityScore':
          '${(avgConfidence * 100).toStringAsFixed(1)}% mean OCR confidence',
      'keyEntities': keyEntities,
      'stats': {
        'totalLines': totalLines,
        'avgConfidence': avgConfidence,
        'sourceLinkedRate': sourceLinkedRate,
        'auditTimestamp': DateTime.now().toIso8601String(),
      },
    };
  }
}
