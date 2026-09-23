import 'dart:typed_data';
import 'package:appcon_starter/legacy/legacy_models.dart';
import 'package:appcon_starter/legacy/validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const lines = [
    OcrLine(text: 'Ramon Dela Cruz', confidence: 0.97, box: [0, 0, 1, 0.1]),
    OcrLine(text: 'O231', confidence: 0.72, box: [0, 0.1, 1, 0.1]),
  ];

  test('agreement can be a ready candidate but is never called verified', () {
    final field = validateSuggestion(
        id: '1',
        name: 'full_name',
        value: 'Ramon Dela Cruz',
        page: 1,
        lineIndex: 0,
        lines: lines);
    expect(field.status, FieldStatus.ready);
    expect(field.finalValue, 'Ramon Dela Cruz');
    expect(field.score, lessThanOrEqualTo(1));
  });

  test('OCR conflict and unsupported value are routed to review', () {
    final conflict = validateSuggestion(
        id: '2',
        name: 'file_no',
        value: '0231',
        page: 1,
        lineIndex: 1,
        lines: lines);
    final unsupported = validateSuggestion(
        id: '3',
        name: 'location',
        value: 'Manila',
        page: 1,
        lineIndex: -1,
        lines: lines);
    expect(conflict.needsReview, isTrue);
    expect(conflict.finalValue, isNull);
    expect(conflict.reason, contains('disagree'));
    expect(unsupported.needsReview, isTrue);
    expect(unsupported.reason, contains('No source line'));
  });

  test('review decisions change export values and preserve provenance', () {
    final field = validateSuggestion(
        id: '2',
        name: 'file_no',
        value: '0231',
        page: 1,
        lineIndex: 1,
        lines: lines);
    final document = LegacyDocument(
        name: 'directory.jpg',
        documentType: 'directory',
        pages: [LegacyPage(number: 1, image: Uint8List(0), lines: lines)],
        fields: [field]);
    expect(document.exportJson(), contains('"value": null'));
    document.decide('2', FieldStatus.edited, '0231');
    expect(document.needsReview, 0);
    expect(document.exportJson(), contains('"ocr_value": "O231"'));
    expect(document.exportCsv(), contains('"0231","edited"'));
  });

  test('grouped directory export creates a reusable record row', () {
    final name = validateSuggestion(
        id: 'n',
        name: 'full_name',
        value: 'Ramon Dela Cruz',
        page: 1,
        lineIndex: 0,
        lines: lines,
        recordIndex: 1);
    final number = validateSuggestion(
        id: 'i',
        name: 'file_no',
        value: '0231',
        page: 1,
        lineIndex: 1,
        lines: lines,
        recordIndex: 1);
    final document = LegacyDocument(
        name: 'directory.jpg',
        documentType: 'directory',
        pages: [LegacyPage(number: 1, image: Uint8List(0), lines: lines)],
        fields: [name, number]);
    expect(document.exportRecordsCsv(), contains('requires_review'));
    document.decide('i', FieldStatus.accepted, '0231');
    expect(document.exportRecordsCsv(),
        contains('"1","ready","Ramon Dela Cruz","0231"'));
  });

  test('quality report separates OCR confidence from accuracy claims', () {
    final document = LegacyDocument(
      name: 'faded.jpg',
      documentType: 'scan',
      pages: [
        LegacyPage(
          number: 1,
          image: Uint8List(0),
          lines: lines,
          enhancementApplied: true,
        ),
      ],
      fields: const [],
    );
    expect(document.meanOcrConfidence, closeTo(0.845, 0.001));
    expect(document.lowConfidenceLines, 1);
    expect(
        document.qualityReport['claim_boundary'], contains('not an accuracy'));
    expect(document.exportJson(), contains('enhanced_pages'));
  });

  test('detected drawing rectangles export as review-required SVG and DXF', () {
    const object = DrawingObject(
      id: 'p1rect1',
      kind: 'rectangle',
      box: [0.1, 0.2, 0.3, 0.4],
      confidence: 0.91,
    );
    final document = LegacyDocument(
      name: 'plan.jpg',
      documentType: 'drawing',
      pages: [
        LegacyPage(
          number: 1,
          image: Uint8List(0),
          lines: const [],
          drawingObjects: const [object],
        ),
      ],
      fields: const [],
    );
    expect(document.drawingObjectCount, 1);
    expect(document.exportSvg(), contains('id="p1rect1"'));
    expect(document.exportSvg(), contains('data-units="normalized"'));
    expect(document.exportDxf(), contains('LWPOLYLINE'));
    expect(document.exportJson(), contains('normalized_page'));
  });

  test('smart CAD preserves traced points, labels, and reviewed scale', () {
    const object = DrawingObject(
      id: 'p1contour1',
      kind: 'contour',
      box: [0.1, 0.2, 0.5, 0.25],
      points: [0.1, 0.2, 0.6, 0.2, 0.55, 0.45, 0.1, 0.45],
      confidence: 0.5,
      sourceLabels: ['2500 mm'],
    );
    final document = LegacyDocument(
      name: 'plan.jpg',
      documentType: 'drawing',
      pages: [
        LegacyPage(
          number: 1,
          image: Uint8List(0),
          lines: const [],
          pixelWidth: 1000,
          pixelHeight: 500,
          drawingObjects: const [object],
        ),
      ],
      fields: const [],
    );

    document.calibrateCad(object: object, knownWidth: 2500, unit: 'mm');

    expect(document.cadPageWidth, 5000);
    expect(document.exportSvg(), contains('data-units="mm"'));
    expect(document.exportSvg(), contains('2500 mm'));
    expect(document.exportDxf(), contains(r'$INSUNITS'));
    expect(document.exportDxf(), contains('CONTOUR_REVIEW'));
    expect(document.exportDxf(), contains('SOURCE_LABELS'));
    expect(document.exportJson(), contains('p1contour1'));
  });
}
