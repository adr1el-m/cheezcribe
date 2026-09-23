import 'package:flutter/material.dart';
import '../core/app_state.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/studio_widgets.dart';
import 'compose_screen.dart';

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key, required this.state});
  final AppState state;
  Future<void> delete(BuildContext context, StudioSession session) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Delete this session?'),
              content: const Text(
                  'Its local draft and response will be removed from this device.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Keep')),
                TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'))
              ],
            ));
    if (confirmed != true) return;
    try {
      await state.delete(session.id);
    } catch (_) {
      if (context.mounted) {
        showStudioMessage(
            context, 'Could not delete this session. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
        const StudioLabel('YOUR WORKSPACE', color: mint),
        const SizedBox(height: 14),
        const Text('Keep the spark.',
            style: TextStyle(
                fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: -1)),
        const SizedBox(height: 10),
        const Text('Drafts and responses saved on this device.',
            style: TextStyle(color: muted, height: 1.5)),
        const SizedBox(height: 28),
        if (state.sessions.isEmpty)
          StudioCard(
              child: Column(children: [
            const SizedBox(height: 20),
            const Icon(Icons.layers_outlined, size: 46, color: mint),
            const SizedBox(height: 20),
            const Text('A clean slate.',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            const Text(
                'Your first session starts with a little curiosity.\nSave an idea and come back to it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: muted, fontSize: 13, height: 1.6)),
            const SizedBox(height: 22),
            FilledButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => ComposeScreen(
                            state: state, task: 'Explore an idea'))),
                child: const Text('Create a session')),
            const SizedBox(height: 16),
          ])),
        for (final session in state.sessions)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: StudioCard(
                  padding: 0,
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
                    title: Text(session.input.replaceAll('\n', ' '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, height: 1.4)),
                    subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                            '${session.task} · ${session.completed ? 'AI response' : 'Draft'}',
                            style: TextStyle(
                                color: session.completed ? mint : muted,
                                fontSize: 11))),
                    trailing: IconButton(
                        tooltip: 'Delete session',
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 20, color: muted),
                        onPressed: () => delete(context, session)),
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => ComposeScreen(
                                state: state,
                                task: session.task,
                                session: session))),
                  ))),
        const SizedBox(height: 20),
        const Text(
            'Local storage is for practice drafts, not important records. '
            'Copy anything you need to keep. Removing the app removes its local data.',
            style: TextStyle(color: muted, fontSize: 11, height: 1.6)),
      ]));
}
