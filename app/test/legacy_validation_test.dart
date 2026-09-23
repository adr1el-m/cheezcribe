import 'dart:typed_data';
import 'package:appcon_starter/legacy/legacy_models.dart';
import 'package:appcon_starter/legacy/legacy_pipeline.dart';
import 'package:appcon_starter/legacy/session_checkpoint_store.dart';
import 'package:appcon_starter/legacy/validation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test('on-device structuring is never labeled as a Gemini suggestion', () {
    final field = validateSuggestion(
      id: 'local',
      name: 'official_name',
      value: 'Ramon Dela Cruz',
      page: 1,
      lineIndex: 0,
      lines: lines,
      fromAi: false,
    );
    expect(field.ocrValue, 'Ramon Dela Cruz');
    expect(field.aiValue, isNull);
    expect(field.reason, isNot(contains('Gemini')));
  });

  test('checkpoint storage removes legacy payloads and stays compact',
      () async {
    SharedPreferences.setMockInitialValues({
      'legacylens_structured_checkpoints_v1': [List.filled(40000, 'x').join()],
    });
    final fields = [
      for (var i = 0; i < 2000; i++)
        LegacyField(
          id: '$i',
          name: 'field_$i',
          page: 1,
          lineIndex: 0,
          ocrValue: 'value_$i',
          aiValue: null,
          score: .9,
          reason: 'test',
          status: FieldStatus.review,
        ),
    ];
    final document = LegacyDocument(
      name: 'large.pdf',
      documentType: 'directory',
      pages: [LegacyPage(number: 1, image: Uint8List(0), lines: lines)],
      fields: fields,
    );

    final count = await SessionCheckpointStore().save(document);
    final prefs = await SharedPreferences.getInstance();
    final summaries = prefs.getStringList('paperazzi_checkpoint_summaries_v2')!;

    expect(count, 1);
    expect(prefs.containsKey('legacylens_structured_checkpoints_v1'), isFalse);
    expect(summaries.single.length, lessThan(1000));
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

  test('on-device intelligence structures gazetteer rows from OCR evidence',
      () {
    final page = LegacyPage(
      number: 1,
      image: Uint8List(0),
      lines: const [
        OcrLine(
            text: 'Abucay o 7,200, 25 SE 3 mi',
            confidence: .95,
            box: [0, 0, 1, .1]),
        OcrLine(
            text: 'Abujog o 9,100, i Leyte, S 35 mi.',
            confidence: .92,
            box: [0, .1, 1, .1]),
        OcrLine(
            text: 'Aguilar o 4,400, see Salassa.',
            confidence: .94,
            box: [0, .2, 1, .1]),
        OcrLine(
            text: 'Alaminos o 8,000, 21 mi.',
            confidence: .91,
            box: [0, .3, 1, .1]),
      ],
    );

    final insight = inspectSpecializedLegacyPage(page);
    expect(insight['type'], 'Philippine Gazetteer and Military Reference');
    expect(insight['names'], containsAll(['place_name', 'population']));
    expect(insight['values'], containsAll(['Abucay', '7,200', 'Abujog']));
  });

  test('on-device intelligence identifies engineering map metadata', () {
    final page = LegacyPage(
      number: 2,
      image: Uint8List(0),
      lines: const [
        OcrLine(
            text: 'MAP OF CITY OF MANILA AND VICINITY',
            confidence: .98,
            box: [0, 0, 1, .1]),
        OcrLine(
            text: 'SCALE 6 Inches = 1 Mile 1:10560',
            confidence: .96,
            box: [0, .1, 1, .1]),
        OcrLine(
            text: 'Office of Department Engineer, Phil. Dept.',
            confidence: .94,
            box: [0, .2, 1, .1]),
        OcrLine(
            text: 'Corrected to March 1919',
            confidence: .92,
            box: [0, .3, 1, .1]),
        OcrLine(text: 'MANILA HARBOR', confidence: .99, box: [0, .4, 1, .1]),
      ],
    );

    final insight = inspectSpecializedLegacyPage(page);
    expect(insight['type'], 'Historical Engineering Map');
    expect(insight['names'],
        containsAll(['map_title', 'map_scale', 'issuing_office', 'map_date']));
  });

  test('on-device intelligence identifies technical notebook evidence', () {
    final page = LegacyPage(
      number: 3,
      image: Uint8List(0),
      lines: const [
        OcrLine(text: 'March 10th 1876', confidence: .93, box: [0, 0, 1, .1]),
        OcrLine(
            text: 'The transmitting instrument was constructed this morning',
            confidence: .91,
            box: [0, .1, 1, .1]),
        OcrLine(
            text: 'M the mouth piece and S the armature',
            confidence: .90,
            box: [0, .2, 1, .1]),
        OcrLine(
            text: 'with the receiving instrument',
            confidence: .89,
            box: [0, .3, 1, .1]),
        OcrLine(
            text: 'The sound was audible and quite distinct',
            confidence: .88,
            box: [0, .4, 1, .1]),
      ],
    );

    final insight = inspectSpecializedLegacyPage(page);
    expect(insight['type'], 'Technical Laboratory Notebook');
    expect(
        insight['names'],
        containsAll([
          'experiment_date',
          'technical_component',
          'experiment_observation',
          'reference_transcription',
          'apparatus_components',
        ]));
    expect(
        insight['values'],
        contains(
            'The improved instrument shown in Fig. 1 was constructed this morning and tried this evening.'));
  });

  test('prepared public-record packet has deterministic linked insights', () {
    LegacyPage page(int number, List<String> text) => LegacyPage(
          number: number,
          image: Uint8List(0),
          lines: [
            for (var i = 0; i < text.length; i++)
              OcrLine(
                  text: text[i],
                  confidence: .72,
                  box: [0, .08 + (i * .12), 1, .08]),
          ],
        );

    final gazetteer = inspectPreparedPacketPage(
        page(1, ['Abucay o 7,200', 'Abujog o 9,100', 'Alaminos o 8,000']));
    final map = inspectPreparedPacketPage(
        page(2, ['MAP OF CITY OF MANILA', 'SCALE 1:10560', 'MANILA HARBOR']));
    final bell = inspectPreparedPacketPage(page(3, [
      'March 10th 1876',
      'The improved instrument was constructed',
      'M the mouth piece and S the armature',
      'quite clearly and intelligibly'
    ]));

    expect(gazetteer['type'], 'Philippine Gazetteer and Military Reference');
    expect(gazetteer['values'], containsAll(['Abucay', '7,200', 'Alegria']));
    expect(gazetteer['linked'], 30);
    expect(map['values'], contains('6 inches = 1 mile; 1:10,560'));
    expect(map['linked'], 6);
    expect(bell['values'], contains('March 10, 1876'));
    expect(bell['linked'], 7);
  });
}
