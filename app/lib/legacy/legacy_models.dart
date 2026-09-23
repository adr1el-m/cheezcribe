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
      {required this.number, required this.image, required this.lines});
  final int number;
  final Uint8List image;
  final List<OcrLine> lines;
  String get ocrText => lines.map((line) => line.text).join('\n');
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
        'fields': fields.map((field) => field.toJson()).toList(),
      });

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
}
