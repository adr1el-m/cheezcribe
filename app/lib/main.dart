import 'package:flutter/material.dart';
import 'core/app_state.dart';
import 'core/theme.dart';
import 'screens/shell.dart';
import 'services/ai_service.dart';
import 'services/draft_store.dart';
import 'legacy/legacy_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(PaperazziApp(connection: FirebaseAiService()));
}

Future<void> runPreparationStarter() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state =
      AppState(store: PreferenceDraftStore(), ai: FirebaseAiService());
  await state.load();
  runApp(MatsuriApp(state: state));
  // The UI opens immediately; cloud initialization is optional and independent.
  state.connectAi();
}

class MatsuriApp extends StatelessWidget {
  const MatsuriApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Matsuri Studio',
        debugShowCheckedModeBanner: false,
        theme: studioTheme,
        home: ColoredBox(
          color: ink,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: StudioShell(state: state),
            ),
          ),
        ),
      );
}
