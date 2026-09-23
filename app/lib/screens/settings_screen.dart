import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/studio_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) => SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
        const StudioLabel('THE FOUNDATION', color: mint),
        const SizedBox(height: 14),
        const Text('Ready for what’s next.',
            style: TextStyle(
                fontSize: 33,
                height: 1.1,
                fontWeight: FontWeight.w600,
                letterSpacing: -1)),
        const SizedBox(height: 24),
        StudioCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.auto_awesome_rounded, color: mint, size: 21),
            SizedBox(width: 10),
            Text('AI connection',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17))
          ]),
          const SizedBox(height: 14),
          Text(state.ai.status,
              style: const TextStyle(color: coral, fontSize: 13)),
          const SizedBox(height: 14),
          const Text(
              'The interface and local drafts work now. Real generation needs your Firebase project, '
              'an enabled Gemini model and App Check registration.',
              style: TextStyle(color: muted, fontSize: 13, height: 1.6)),
          const SizedBox(height: 20),
          const _Step('01', 'Enable AI Logic',
              'Use the registered practice project or a team project.'),
          const _Step('02', 'Connect this app',
              'Run FlutterFire for each platform you will demo.'),
          const _Step('03', 'Register App Check',
              'Allow your simulator debug token for local testing.'),
          const _Step('04', 'Choose your model',
              'Rebuild with the enabled model ID and Firebase flag.'),
          const SizedBox(height: 8),
          TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(const ClipboardData(
                    text:
                        'cd app\nflutterfire configure --project=YOUR_PROJECT_ID --platforms=ios,android\n'
                        'flutter run --dart-define=FIREBASE_ENABLED=true --dart-define=AI_MODEL=YOUR_ENABLED_MODEL'));
                if (context.mounted) {
                  showStudioMessage(context,
                      'Setup commands copied. Use your own project and model.');
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 17),
              label: const Text('Copy setup commands')),
        ])),
        const SizedBox(height: 16),
        StudioCard(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const StudioLabel('APPCON 2026', color: mint),
          const SizedBox(height: 12),
          const Text('Team 08 challenge.',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          const Text(
              'Legacy Knowledge Digitization & Asset Redefinition. This is a starting foundation; '
              'the document and asset workflow will follow the team’s product idea.',
              style: TextStyle(color: muted, fontSize: 13, height: 1.6)),
          const SizedBox(height: 14),
          const Divider(color: line),
          const SizedBox(height: 10),
          const _Info('Framework', 'Flutter / Dart'),
          const _Info('AI provider', 'Firebase AI Logic / Gemini'),
          const _Info('Saved sessions', 'On this device'),
          const _Info('License', 'MIT • authored code'),
          _Info('Version', '0.1.0 • ${state.sessions.length} sessions'),
        ])),
        const SizedBox(height: 22),
        const Text(
            'No fake AI responses. No account needed for local drafts. '
            'Connected AI sends your submitted input to a hosted model.',
            style: TextStyle(color: muted, fontSize: 11, height: 1.7)),
      ]));
}

class _Step extends StatelessWidget {
  const _Step(this.number, this.title, this.subtitle);
  final String number, title, subtitle;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(number,
            style: const TextStyle(
                color: mint, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(subtitle,
              style: const TextStyle(color: muted, fontSize: 11, height: 1.5)),
        ])),
      ]));
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(color: muted, fontSize: 12))),
        Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11))),
      ]));
}
