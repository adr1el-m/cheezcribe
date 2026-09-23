import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_state.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/studio_widgets.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen(
      {super.key, required this.state, required this.task, this.session});
  final AppState state;
  final String task;
  final StudioSession? session;
  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  late final input = TextEditingController(text: widget.session?.input ?? '');
  late final id =
      widget.session?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
  late final createdAt = widget.session?.createdAt ?? DateTime.now();
  bool busy = false;
  String? error;
  late String? output = widget.session?.output;
  late String? responseModel = widget.session?.model;
  late int? latency = widget.session?.latencyMs;
  bool get ready => widget.state.ai.ready;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(refreshConnection);
  }

  void refreshConnection() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.state.removeListener(refreshConnection);
    input.dispose();
    super.dispose();
  }

  Future<void> perform({required bool generate}) async {
    final text = input.text.trim();
    if (text.isEmpty) {
      setState(() => error = 'Add some text or an idea first.');
      return;
    }
    if (text.length > 4000) {
      setState(() => error = 'Use up to 4,000 characters for this session.');
      return;
    }
    if (busy) return;
    if (generate && !ready) {
      setState(() => error =
          'Connect a Firebase project in Setup first. You can save a draft now.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    var receivedAnswer = false;
    try {
      if (generate) {
        setState(() {
          output = null;
          responseModel = null;
          latency = null;
        });
        // Preserve the prompt before a network request so a failed request has a local draft.
        await widget.state.save(StudioSession(
            id: id, task: widget.task, input: text, createdAt: createdAt));
        final answer = await widget.state.ai.generate(widget.task, text);
        if (!mounted) return;
        setState(() {
          output = answer.text;
          responseModel = answer.model;
          latency = answer.latencyMs;
        });
        receivedAnswer = true;
      }
      await widget.state.save(StudioSession(
          id: id,
          task: widget.task,
          input: text,
          createdAt: createdAt,
          output: output,
          model: responseModel,
          latencyMs: latency));
      if (!mounted) return;
      showStudioMessage(
          context,
          generate
              ? 'Response saved on this device.'
              : 'Draft saved on this device.');
      if (!generate) Navigator.of(context).pop();
    } on TimeoutException {
      if (mounted) {
        setState(() => error = 'The AI request timed out. Your draft is saved. '
            'Check the connection before retrying; the provider may still finish the previous request.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = receivedAnswer
            ? 'The response is visible, but saving failed. Copy it before leaving.'
            : generate
                ? 'The request could not complete. Check connection, quota and App Check. Your input is still here.'
                : 'The draft could not be saved. Your input is still here; please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.task, style: const TextStyle(fontSize: 18))),
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(24), children: [
          const StudioLabel('LET’S START WITH WHAT YOU HAVE', color: mint),
          const SizedBox(height: 15),
          Text(
              switch (widget.task) {
                'Simplify text' => 'Less confusion.\nMore clarity.',
                'Find next steps' => 'From information\nto action.',
                _ => 'Give your idea\nsome room.',
              },
              style: const TextStyle(
                  fontSize: 34,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1)),
          const SizedBox(height: 20),
          const Text(
              'Start with non-sensitive text. When AI is connected, your input is sent to a hosted model.',
              style: TextStyle(color: muted, height: 1.5, fontSize: 13)),
          const SizedBox(height: 24),
          TextField(
              controller: input,
              enabled: !busy,
              minLines: 6,
              maxLines: 12,
              maxLength: 4000,
              decoration: const InputDecoration(
                  labelText: 'Your starting point',
                  hintText:
                      'Paste text or describe what you’re thinking about…'),
              onChanged: (_) {
                if (output != null) {
                  setState(() {
                    output = null;
                    responseModel = null;
                    latency = null;
                  });
                }
              }),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: ready && !busy ? () => perform(generate: true) : null,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.auto_awesome_rounded, size: 19),
              label: Text(busy
                  ? 'Working…'
                  : ready
                      ? 'Generate with AI'
                      : 'Connect AI to generate')),
          const SizedBox(height: 10),
          OutlinedButton(
              onPressed: busy ? null : () => perform(generate: false),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18))),
              child: const Text('Save draft')),
          if (error != null) ...[
            const SizedBox(height: 16),
            Semantics(
                liveRegion: true,
                child: Text(error!,
                    style: const TextStyle(color: coral, height: 1.5))),
          ],
          if (output != null) ...[
            const SizedBox(height: 28),
            const StudioLabel('MODEL RESPONSE', color: mint),
            const SizedBox(height: 10),
            Text('$responseModel • ${latency ?? 0} ms',
                style: const TextStyle(color: muted, fontSize: 11)),
            const SizedBox(height: 14),
            StudioCard(
                child: SelectableText(output!,
                    style: const TextStyle(height: 1.65))),
            const SizedBox(height: 12),
            const Text(
                'Generated content can be wrong. Review it against your original input before acting.',
                style: TextStyle(color: muted, fontSize: 12, height: 1.5)),
            TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: output!));
                  if (context.mounted) {
                    showStudioMessage(context, 'Response copied.');
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 17),
                label: const Text('Copy response')),
          ],
        ])),
      );
}
