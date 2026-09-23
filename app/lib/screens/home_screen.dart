import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/theme.dart';
import '../widgets/studio_widgets.dart';
import 'compose_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen(
      {super.key,
      required this.state,
      required this.openSessions,
      required this.openSettings});
  final AppState state;
  final VoidCallback openSessions;
  final VoidCallback openSettings;

  void compose(BuildContext context, String task) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ComposeScreen(state: state, task: task)));

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 30),
            children: [
              Row(children: [
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: mint, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.auto_awesome_rounded,
                        size: 19, color: ink)),
                const SizedBox(width: 12),
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('matsuri',
                          style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7)),
                      StudioLabel('STUDIO / 2026'),
                    ])),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                        border: Border.all(color: line),
                        borderRadius: BorderRadius.circular(30)),
                    child: const Text('EARLY BUILD',
                        style: TextStyle(
                            color: muted,
                            fontSize: 9,
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 38),
              const StudioLabel('A LITTLE CURIOSITY. A LOT OF POSSIBILITY.',
                  color: mint),
              const SizedBox(height: 14),
              const Text('Small ideas.\nReal impact.',
                  style: TextStyle(
                      fontSize: 46,
                      height: 1.04,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -2.1)),
              const SizedBox(height: 16),
              const Text(
                  'A space to turn everyday problems into\nsomething useful, with AI.',
                  style: TextStyle(color: muted, fontSize: 14, height: 1.6)),
              const SizedBox(height: 26),
              StudioCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                StudioLabel('YOUR NEXT EXPLORATION',
                                    color: mint),
                                SizedBox(height: 12),
                                Text('Make sense\nof something.',
                                    style: TextStyle(
                                        fontSize: 25,
                                        height: 1.15,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: -0.7)),
                                SizedBox(height: 12),
                                Text('Bring a text, a question,\nor an idea.',
                                    style: TextStyle(
                                        color: muted,
                                        fontSize: 13,
                                        height: 1.5)),
                              ])),
                          const ExcludeSemantics(child: OrbitArt()),
                        ]),
                    const SizedBox(height: 12),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                            onPressed: () =>
                                compose(context, 'Explore an idea'),
                            child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Start a session'),
                                  SizedBox(width: 12),
                                  Icon(Icons.arrow_forward_rounded, size: 19),
                                ]))),
                  ])),
              const SizedBox(height: 24),
              Row(children: [
                const Expanded(child: StudioLabel('PICK A STARTING POINT')),
                Text('${state.sessions.length} saved',
                    style: const TextStyle(color: muted, fontSize: 11)),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                    child: _QuickCard(
                        icon: Icons.short_text_rounded,
                        title: 'Simplify text',
                        subtitle: 'Find the meaning',
                        color: mint,
                        onTap: () => compose(context, 'Simplify text'))),
                const SizedBox(width: 12),
                Expanded(
                    child: _QuickCard(
                        icon: Icons.checklist_rounded,
                        title: 'Find next steps',
                        subtitle: 'Turn text into action',
                        color: coral,
                        onTap: () => compose(context, 'Find next steps'))),
              ]),
              const SizedBox(height: 18),
              InkWell(
                  onTap: openSettings,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Icon(
                            state.ai.ready
                                ? Icons.check_circle_outline
                                : Icons.link_rounded,
                            color: muted,
                            size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(
                                state.ai.ready
                                    ? state.ai.status
                                    : 'Local drafts work. Connect AI in Setup.',
                                style: const TextStyle(
                                    color: muted, fontSize: 12))),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 16, color: muted),
                      ]))),
              if (state.storageWarning != null)
                Text(state.storageWarning!,
                    style: const TextStyle(color: coral)),
              const SizedBox(height: 12),
              const Center(
                  child: StudioLabel('MADE TO BEGIN. BUILT WITH FLUTTER.')),
            ]),
      );
}

class _QuickCard extends StatelessWidget {
  const _QuickCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.color,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
      color: surface,
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(21),
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 24),
                    const SizedBox(height: 21),
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(subtitle,
                        style: const TextStyle(color: muted, fontSize: 10)),
                  ]))));
}
