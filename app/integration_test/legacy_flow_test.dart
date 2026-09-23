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
  Future<void> connect() async {}
  @override
  Future<AiAnswer> generate(String task, String input) =>
      throw UnimplementedError();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('native OCR reads the synthetic directory with source crops', () async {
    final result = await LegacyPipeline(OfflineConnection())
        .importAndProcess(sample: true);
    expect(result, isNotNull);
    final lines = result!.document.pages.single.lines;
    // Synthetic fixture only: visible OCR evidence for an honest demo metric.
    // ignore: avoid_print
    print('VISION_OCR_LINES: ${lines.map((line) => line.text).join(' | ')}');
    expect(lines.length, greaterThan(5));
    expect(lines.map((line) => line.text).join(' '), contains('Ramon'));
    const expectedRecordCells = [
      '0217',
      'Ramon Dela Cruz',
      'Manila',
      '1978',
      '0231',
      'Elena Santos',
      'Quezon City',
      '1978',
      '0246',
      'Luis Mercado',
      'Pasig',
      '1978',
      '0288',
      'Maria Reyes',
      'Makati',
      '1978',
    ];
    var nextLine = 0;
    var exactCells = 0;
    for (final expected in expectedRecordCells) {
      while (nextLine < lines.length && lines[nextLine].text != expected) {
        nextLine++;
      }
      if (nextLine < lines.length) {
        exactCells++;
        nextLine++;
      }
    }
    // ignore: avoid_print
    print(
        'VISION_SYNTHETIC_EXACT_CELLS: $exactCells/${expectedRecordCells.length}');
    expect(exactCells, expectedRecordCells.length);
    expect(lines.any((line) => line.crop != null && line.crop!.isNotEmpty),
        isTrue);
    expect(result.document.fields.length, lines.length);
  });

  testWidgets('synthetic directory runs through native OCR and review',
      (tester) async {
    await tester.pumpWidget(LegacyLensApp(connection: OfflineConnection()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try synthetic sample'));
    for (var attempt = 0; attempt < 80; attempt++) {
      await tester.pump(const Duration(seconds: 1));
      if (find
          .textContaining('Synthetic test document')
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    expect(find.textContaining('Synthetic test document'), findsOneWidget);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();
    expect(find.text('Review queue'), findsOneWidget);
    expect(find.text('SOURCE CROP'), findsOneWidget);
  });
}
