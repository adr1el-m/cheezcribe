import 'dart:typed_data';

import 'package:appcon_starter/legacy/legacy_app.dart';
import 'package:appcon_starter/legacy/legacy_pipeline.dart';
import 'package:appcon_starter/services/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

class OfflineConnection implements AiService {
  @override
  bool get ready => false;
  @override
  String get status => 'OCR only';
  @override
  String get activeModel => 'gemini-2.5-flash';
  @override
  String get customApiKey => '';
  @override
  Future<void> connect() async {}
  @override
  Future<void> setCustomApiKey(String key) async {}
  @override
  Future<void> setActiveModel(String model) async {}
  @override
  Future<int> pingConnection() async => 0;
  @override
  Future<AiAnswer> generate(String task, String input) =>
      throw UnimplementedError();
  @override
  Future<String?> analyzeDocument({
    required Uint8List imageBytes,
    required String ocrText,
    required int pageNumber,
  }) async =>
      null;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('native OCR reads the bundled 1915 sample with source crops', () async {
    final result = await LegacyPipeline(OfflineConnection())
        .importAndProcess(sample: true);
    expect(result, isNotNull);
    final lines = result!.document.pages.single.lines;
    final page = result.document.pages.single;
    // One bundled fixture only: visible OCR evidence, not an accuracy metric.
    // ignore: avoid_print
    print('NATIVE_OCR_LINES: ${lines.map((line) => line.text).join(' | ')}');
    expect(lines.length, greaterThan(5));
    final recognized = lines.map((line) => line.text).join(' ').toLowerCase();
    expect(recognized, contains('tagbilaran'));
    expect(recognized, contains('860 meters'));
    expect(lines.any((line) => line.crop != null && line.crop!.isNotEmpty),
        isTrue);
    expect(page.enhancedImage, isNotNull);
    expect(page.enhancedImage, isNotEmpty);
    // ignore: avoid_print
    print('NATIVE_DRAWING_OBJECTS: ${page.drawingObjects.length}');
    expect(result.document.fields, isNotEmpty);
  });

  testWidgets('bundled sample runs through native OCR and review',
      (tester) async {
    await tester.pumpWidget(LegacyLensApp(connection: OfflineConnection()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try bundled 1915 sample'));
    for (var attempt = 0; attempt < 80; attempt++) {
      await tester.pump(const Duration(seconds: 1));
      if (find
          .textContaining('Bundled 1915 evaluation sample')
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    expect(
        find.textContaining('Bundled 1915 evaluation sample'), findsOneWidget);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Review queue'), findsOneWidget);
    expect(find.text('SOURCE CROP'), findsOneWidget);
  });
}
