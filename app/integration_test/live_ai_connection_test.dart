import 'package:appcon_starter/services/ai_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const runLiveAi = bool.fromEnvironment('LIVE_AI_TEST', defaultValue: false);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'configured Gemini provider returns a real response',
    (_) async {
      final service = FirebaseAiService();
      await service.connect();
      expect(service.ready, isTrue, reason: service.status);
      final latency = await service.pingConnection();
      expect(latency, greaterThan(0));
      expect(service.status, contains('Active'));
    },
    skip: !runLiveAi,
  );
}
