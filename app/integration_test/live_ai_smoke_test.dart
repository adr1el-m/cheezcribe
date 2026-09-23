import 'package:appcon_starter/legacy/legacy_pipeline.dart';
import 'package:appcon_starter/services/ai_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('configured Gemini interprets the synthetic document', () async {
    if (!firebaseEnabled || aiModel.isEmpty) {
      throw StateError('Pass FIREBASE_ENABLED=true and an enabled AI_MODEL.');
    }
    final connection = FirebaseAiService();
    await connection.connect();
    // This status only establishes SDK initialization, not model access.
    // ignore: avoid_print
    print('LIVE_AI_STATUS: ${connection.status}');
    expect(connection.ready, isTrue);
    final result = await LegacyPipeline(connection).importAndProcess(
      sample: true,
      onAiError: (error) {
        final kind = error is FirebaseException
            ? error.code
            : error.runtimeType.toString();
        // ignore: avoid_print
        print('LIVE_AI_ERROR_KIND: $kind');
      },
    );
    expect(result, isNotNull);
    // ignore: avoid_print
    print(
        'LIVE_AI_RESULT: ${result!.note}; structured_fields=${result.document.fields.where((f) => f.aiValue != null).length}');
    expect(result.note, startsWith('OCR and Gemini interpretation completed'));
    expect(result.document.fields.any((f) => f.aiValue != null), isTrue);
  });
}
