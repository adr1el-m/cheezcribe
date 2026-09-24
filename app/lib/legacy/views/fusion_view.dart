part of '../legacy_app.dart';

extension _FusionView on _PaperazziHomeState {
  Future<void> askFusion() async {
    final question = fusionInput.text.trim();
    if (question.length < 4 || fusionBusy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.lightImpact();
    _update(() {
      fusionBusy = true;
      fusionStage = FusionStage.understanding;
    });
    try {
      final outcome = await fusionPipeline.run(question, onStage: (stage) {
        if (mounted) _update(() => fusionStage = stage);
      });
      if (!mounted) return;
      _update(() {
        fusionResults.insert(0, outcome);
        fusionInput.clear();
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      debugPrint('Knowledge Fusion failed: $e');
      if (mounted) _toast('Knowledge Fusion could not complete. Try again.');
    } finally {
      if (mounted) {
        _update(() {
          fusionBusy = false;
          fusionStage = null;
        });
      }
    }
  }

  Future<void> openFusionSettings() async {
    HapticFeedback.lightImpact();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ControllerScope(
        initialText: fusionLlm.apiKey,
        builder: (keyController) => _ControllerScope(
          initialText: fusionLlm.model,
          builder: (modelController) => Padding(
            padding: EdgeInsets.fromLTRB(Pz.gutter, 20, Pz.gutter,
                MediaQuery.viewInsetsOf(sheetContext).bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PzLabel('Knowledge Fusion · OpenRouter', color: Pz.blue),
                const SizedBox(height: 6),
                const Text('Research provider', style: Pz.sectionTitle),
                const SizedBox(height: 4),
                Text(
                    'Your question and matching archive excerpts are sent to '
                    'OpenRouter for web research and synthesis. The key is kept '
                    'for this session only.',
                    style: Pz.meta),
                const SizedBox(height: 14),
                TextField(
                  controller: keyController,
                  obscureText: true,
                  style: Pz.value,
                  decoration: InputDecoration(
                    labelText: 'OpenRouter API key',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste_outlined,
                          size: 18, color: Pz.blue),
                      tooltip: 'Paste',
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          keyController.text = data!.text!.trim();
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: modelController,
                  style: Pz.value,
                  autocorrect: false,
                  decoration: const InputDecoration(
                      labelText: 'Model',
                      helperText: 'Any OpenRouter model id'),
                ),
                const SizedBox(height: 14),
                PzPanel(
                  padding: EdgeInsets.zero,
                  child: PzDataRow(
                    label: 'Knowledge index',
                    value:
                        '$indexedCount document${indexedCount == 1 ? '' : 's'} on this device',
                    note: 'Extracted text and fields only. No images.',
                    trailing: PzSecondaryButton(
                      label: 'Clear',
                      expand: false,
                      height: 36,
                      color: Pz.error,
                      onPressed: indexedCount == 0
                          ? null
                          : () async {
                              await knowledgeStore.clear();
                              await _refreshIndexCount();
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                              _toast('Knowledge index cleared.');
                            },
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                PzPrimaryButton(
                  label: 'Save',
                  height: 44,
                  onPressed: () {
                    fusionLlm.configure(
                        apiKey: keyController.text,
                        model: modelController.text);
                    _update(() {});
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _fusionPanel() => [
        const SizedBox(height: 18),
        Text('Ask Paperazzi anything about your documents.',
                style: Pz.body.copyWith(color: Pz.graphite))
            .padded(),
        const SizedBox(height: 12),
        _fusionComposer().padded(),
        const SizedBox(height: 8),
        _fusionStatusLine().padded(),
        if (fusionBusy) ...[
          const SizedBox(height: 16),
          _fusionProgress().padded(),
        ],
        const SizedBox(height: 18),
        _fusionLegend().padded(),
        for (final outcome in fusionResults) ...[
          const SizedBox(height: 26),
          _fusionOutcome(outcome).padded(),
        ],
        if (fusionResults.isEmpty && !fusionBusy) ...[
          const SizedBox(height: 18),
          PzPanel(
            color: Pz.paper,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PzLabel('How it works'),
                const SizedBox(height: 8),
                Text(
                  'Paperazzi searches your archived documents, researches '
                  'current sources on the web, compares the two, and writes a '
                  'cited article. Historical and current information stay '
                  'separate, and conflicts are shown instead of merged.',
                  style: Pz.body.copyWith(fontSize: 13.5),
                ),
              ],
            ),
          ).padded(),
        ],
      ];

  Widget _fusionComposer() => Container(
        decoration: BoxDecoration(
          color: Pz.card,
          borderRadius: BorderRadius.circular(Pz.rButton),
          border: Border.all(color: Pz.lineStrong),
        ),
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: fusionInput,
                enabled: !fusionBusy,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => askFusion(),
                style: Pz.value.copyWith(fontSize: 15),
                decoration: const InputDecoration(
                  hintText:
                      'e.g. What is the current maintenance procedure for Pump A?',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: IconButton.filled(
                tooltip: 'Ask',
                onPressed: fusionBusy ? null : askFusion,
                style: IconButton.styleFrom(
                  backgroundColor: Pz.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Pz.rButton)),
                ),
                icon: const Icon(Icons.arrow_upward, size: 20),
              ),
            ),
          ],
        ),
      );

  Widget _fusionStatusLine() => Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fusionLlm.ready ? Pz.verified : Pz.review,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fusionLlm.ready
                  ? 'OpenRouter · ${fusionLlm.model} · $indexedCount indexed document${indexedCount == 1 ? '' : 's'}'
                  : 'Archive search only · add an OpenRouter key for current sources',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Pz.meta.copyWith(fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: openFusionSettings,
            child: Text(fusionLlm.ready ? 'Settings' : 'Add key'),
          ),
        ],
      );

  Widget _fusionProgress() {
    const order = [
      FusionStage.archive,
      FusionStage.web,
      FusionStage.comparing,
      FusionStage.generating,
    ];
    final current = fusionStage?.index ?? 0;
    return PzPanel(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        children: [
          for (final stage in order)
            PzScannerStatusRow(
              label: switch (stage) {
                FusionStage.archive => 'Archive',
                FusionStage.web => 'Current',
                FusionStage.comparing => 'Compare',
                _ => 'Synthesis',
              },
              value: '${stage.label}…',
              state: stage.index < current
                  ? PzStepState.done
                  : stage.index == current
                      ? PzStepState.active
                      : PzStepState.pending,
            ),
        ],
      ),
    );
  }

  Widget _fusionLegend() {
    Widget item(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 3, height: 12, color: color),
            const SizedBox(width: 6),
            Text(label.toUpperCase(),
                style: Pz.label.copyWith(fontSize: 9.5, color: Pz.steel)),
          ],
        );
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        item(Pz.legacy, 'Legacy knowledge'),
        item(Pz.current, 'Current knowledge'),
        item(Pz.synthesis, 'AI synthesis'),
        item(Pz.conflict, 'Conflict'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _citeChip('L1', null, null),
            const SizedBox(width: 3),
            _citeChip('W1', null, null),
            const SizedBox(width: 6),
            Text('SOURCE EVIDENCE',
                style: Pz.label.copyWith(fontSize: 9.5, color: Pz.steel)),
          ],
        ),
      ],
    );
  }

  Widget _fusionOutcome(FusionOutcome outcome) {
    final a = outcome.article;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.subdirectory_arrow_right,
                size: 16, color: Pz.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(outcome.query.question,
                  style: Pz.meta.copyWith(
                      color: Pz.graphite, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (a == null) _archiveOnly(outcome) else _article(a),
      ],
    );
  }

  Widget _archiveOnly(FusionOutcome outcome) => PzPanel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: const BoxDecoration(
                  border: Border(left: BorderSide(color: Pz.review, width: 3))),
              padding: const EdgeInsets.fromLTRB(13, 11, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PzLabel('Archive search'),
                  const SizedBox(height: 4),
                  Text(outcome.message ?? 'No article was generated.',
                      style: Pz.meta.copyWith(color: Pz.graphite)),
                ],
              ),
            ),
            for (final e in outcome.archiveMatches.take(6)) ...[
              const Divider(),
              _legacyRow(e, null),
            ],
            if (outcome.archiveMatches.isEmpty) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                    'No archived document mentions this. Scan or import the '
                    'relevant records first.',
                    style: Pz.meta),
              ),
            ],
          ],
        ),
      );

  Widget _article(FusionArticle a) {
    final (confLabel, confColor) = switch (a.confidence) {
      FusionConfidence.high => ('High', Pz.verified),
      FusionConfidence.medium => ('Medium', Pz.review),
      FusionConfidence.low => ('Low', Pz.error),
    };
    return PzPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PzLabel('Paperazzi · Knowledge Fusion', color: Pz.blue),
                const SizedBox(height: 8),
                Text(a.title.toUpperCase(),
                    style: Pz.sectionTitle
                        .copyWith(fontSize: 17, letterSpacing: .4)),
              ],
            ),
          ),
          const Divider(),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _metaCell('Confidence', confLabel, color: confColor),
                const VerticalDivider(width: 1),
                _metaCell('Conflicts', a.hasConflicts ? 'Yes' : 'No',
                    color: a.hasConflicts ? Pz.conflict : Pz.verified),
                const VerticalDivider(width: 1),
                _metaCell('Sources',
                    '${a.legacySources.length} legacy · ${a.webSources.length} current'),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Text(a.confidenceReasons.join(' · '),
                style: Pz.meta.copyWith(fontSize: 11.5, color: Pz.muted)),
          ),
          const Divider(),
          _section(a, 'Overview', 'AI synthesis', Pz.synthesis, a.overview,
              empty: 'The sources did not support a summary answer.'),
          if (a.conflicts.isNotEmpty)
            for (final c in a.conflicts) _conflictBlock(a, c),
          _section(a, 'Historical Context', 'Legacy knowledge', Pz.legacy,
              a.historical,
              empty: 'No archived document addresses this question.'),
          _section(a, 'Current Information', 'Current knowledge', Pz.current,
              a.current,
              empty: a.webSources.isEmpty
                  ? 'No reliable current source was found. Nothing here is '
                      'presented as current.'
                  : 'The current sources did not address this question.'),
          _section(a, 'What Changed', 'AI synthesis', Pz.synthesis, a.changes,
              empty: a.webSources.isEmpty
                  ? 'Cannot compare without a current source.'
                  : 'No supported difference between the archive and current sources.'),
          _section(a, 'Key Findings', 'AI synthesis', Pz.synthesis, a.findings,
              empty: 'No additional findings.'),
          _sourcesSection(a),
          if (a.notices.isNotEmpty) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final n in a.notices)
                    PzNotice(n, color: Pz.review, icon: Icons.info_outline),
                ],
              ),
            ),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Text(
                'Generated ${_PaperazziHomeState._date(a.generatedAt)} · ${a.model}',
                style: Pz.meta.copyWith(fontSize: 11, color: Pz.muted)),
          ),
        ],
      ),
    );
  }

  Widget _section(FusionArticle a, String heading, String kind, Color color,
          List<FusionStatement> statements,
          {required String empty}) =>
      Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: color, width: 3),
            bottom: const BorderSide(color: Pz.line),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(13, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(heading, style: Pz.cardTitle)),
                PzLabel(kind, color: color, size: 9.5),
              ],
            ),
            const SizedBox(height: 8),
            if (statements.isEmpty)
              Text(empty, style: Pz.meta.copyWith(fontStyle: FontStyle.italic))
            else
              for (final s in statements)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: '${s.text} '),
                      for (final id in s.cites)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 3),
                            child: _citeChip(id, a, null),
                          ),
                        ),
                    ]),
                    style: Pz.body.copyWith(fontSize: 14, height: 1.5),
                  ),
                ),
          ],
        ),
      );

  Widget _conflictBlock(FusionArticle a, FusionConflict c) => Container(
        decoration: BoxDecoration(
          color: Pz.conflict.withValues(alpha: .04),
          border: const Border(
            left: BorderSide(color: Pz.conflict, width: 3),
            bottom: BorderSide(color: Pz.line),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(13, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber_outlined,
                    size: 16, color: Pz.conflict),
                const SizedBox(width: 6),
                const PzLabel('Conflict detected', color: Pz.conflict),
                const Spacer(),
                Flexible(
                  child: Text(c.attribute,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Pz.cardTitle.copyWith(fontSize: 13.5)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                      child: _conflictSide(a, 'Historical specification',
                          c.historicalValue, c.historicalCites, Pz.legacy)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _conflictSide(a, 'Current specification',
                          c.currentValue, c.currentCites, Pz.current)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(c.explanation,
                style: Pz.meta.copyWith(color: Pz.graphite, height: 1.45)),
          ],
        ),
      );

  Widget _conflictSide(FusionArticle a, String label, String value,
          List<String> cites, Color color) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Pz.card,
          border: Border(
            top: BorderSide(color: color, width: 2),
            left: const BorderSide(color: Pz.line),
            right: const BorderSide(color: Pz.line),
            bottom: const BorderSide(color: Pz.line),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PzLabel(label, size: 9.5),
            const SizedBox(height: 6),
            Text(value, style: Pz.figure.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Wrap(spacing: 3, runSpacing: 3, children: [
              for (final id in cites) _citeChip(id, a, null),
            ]),
          ],
        ),
      );

  Widget _sourcesSection(FusionArticle a) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Sources', style: Pz.cardTitle),
            const SizedBox(height: 6),
            if (a.legacySources.isEmpty && a.webSources.isEmpty)
              Text('No sources were cited.', style: Pz.meta),
            for (final e in a.legacySources) _legacyRow(e, a, dense: true),
            for (final w in a.webSources) _webRow(w, a),
          ],
        ),
      );

  Widget _legacyRow(LegacyEvidence e, FusionArticle? a, {bool dense = false}) =>
      InkWell(
        onTap: () => _showLegacySource(e),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: dense ? 0 : 14, vertical: dense ? 8 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _citeChip(e.id, null, null),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('[Internal] ${e.documentName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Pz.value.copyWith(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(
                      '${e.location[0].toUpperCase()}${e.location.substring(1)} · “${e.text}”',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Pz.meta.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: Pz.muted),
            ],
          ),
        ),
      );

  Widget _webRow(WebSource w, FusionArticle a) => InkWell(
        onTap: () => _showWebSource(w),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _citeChip(w.id, null, null),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('[External] ${w.title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Pz.value.copyWith(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(
                      '${w.domain} · ${w.tier.label} · retrieved ${_PaperazziHomeState._date(w.retrievedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Pz.meta.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 18, color: Pz.muted),
            ],
          ),
        ),
      );

  /// Citation chip. L = archive (sepia), W = web (blue). Tapping opens the
  /// source preview when the article is known.
  Widget _citeChip(String id, FusionArticle? a, VoidCallback? onTap) {
    final legacy = id.startsWith('L');
    final color = legacy ? Pz.legacy : Pz.current;
    VoidCallback? tap = onTap;
    if (tap == null && a != null) {
      final e = a.legacySources.where((s) => s.id == id).firstOrNull;
      final w = a.webSources.where((s) => s.id == id).firstOrNull;
      if (e != null) tap = () => _showLegacySource(e);
      if (w != null) tap = () => _showWebSource(w);
    }
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: legacy ? Pz.paper : Pz.blue.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: color.withValues(alpha: .6)),
      ),
      child: Text(id,
          style: TextStyle(
              fontSize: 10,
              height: 1.2,
              fontWeight: FontWeight.w700,
              letterSpacing: .3,
              color: color,
              fontFeatures: Pz.tabular)),
    );
    return tap == null
        ? chip
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              HapticFeedback.selectionClick();
              tap!();
            },
            child: chip,
          );
  }

  void _showLegacySource(LegacyEvidence e) {
    final doc = document;
    final open = doc != null && doc.name == e.documentName;
    final page =
        open ? doc.pages.where((p) => p.number == e.page).firstOrNull : null;
    final line = page != null &&
            e.line != null &&
            e.line! - 1 < page.lines.length &&
            e.line! >= 1
        ? page.lines[e.line! - 1]
        : null;
    final field = open && e.field != null
        ? doc.fields
            .where((f) =>
                f.page == e.page &&
                _PaperazziHomeState._fieldLabel(f.name) == e.field)
            .firstOrNull
        : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Pz.gutter, 20, Pz.gutter, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PzLabel('Legacy source · ${e.id}', color: Pz.legacy),
              const SizedBox(height: 6),
              Text(e.documentName, style: Pz.sectionTitle),
              Text(e.documentType, style: Pz.meta),
              const SizedBox(height: 14),
              if (page != null && line != null && _canZoom(page, line)) ...[
                Container(
                  height: 96,
                  decoration: BoxDecoration(
                    color: Pz.paper,
                    border: Border.all(color: Pz.line),
                    borderRadius: BorderRadius.circular(Pz.rCard),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: PzCornerBrackets(
                    inset: 0,
                    length: 10,
                    child: Center(child: _zoomedRegion(page, line)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              PzPanel(
                color: Pz.paper,
                child: SelectableText('“${e.text}”',
                    style: Pz.body.copyWith(fontSize: 15)),
              ),
              const SizedBox(height: 12),
              PzPanel(
                padding: EdgeInsets.zero,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _metaCell('Page', _PaperazziHomeState._pad(e.page)),
                      const VerticalDivider(width: 1),
                      _metaCell('Zone', e.zone ?? '—'),
                      const VerticalDivider(width: 1),
                      _metaCell(
                          'Line',
                          e.line == null
                              ? '—'
                              : _PaperazziHomeState._pad(e.line!, 3)),
                      const VerticalDivider(width: 1),
                      _metaCell(
                          'OCR',
                          e.ocrConfidence == null
                              ? '—'
                              : '${(e.ocrConfidence! * 100).round()}%'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${e.field == null ? '' : 'Field: ${e.field} · '}'
                'Archived ${_PaperazziHomeState._date(e.archivedAt)}. '
                'This is a historical record, not a current specification.',
                style: Pz.meta.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 16),
              if (open)
                PzPrimaryButton(
                  label: field != null ? 'Open in Verify' : 'Locate on page',
                  icon: Icons.center_focus_strong_outlined,
                  height: 44,
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _update(() {
                      pageIndex = (e.page - 1).clamp(0, doc.pages.length - 1);
                      showTextOverlay = true;
                      if (field != null) {
                        selectedId = field.id;
                        reviewOnlyPending = false;
                      }
                      tab = _Tab.review;
                      reviewView = field != null
                          ? _ReviewView.verify
                          : _ReviewView.document;
                    });
                  },
                )
              else
                Text('Open this document from Archive to see the scanned page.',
                    style: Pz.meta.copyWith(color: Pz.muted)),
            ],
          ),
        ),
      ),
    );
  }

  void _showWebSource(WebSource w) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Pz.gutter, 20, Pz.gutter, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PzLabel('Current source · ${w.id}', color: Pz.current),
              const SizedBox(height: 6),
              Text(w.title, style: Pz.sectionTitle),
              Text('${w.domain} · ${w.tier.label}', style: Pz.meta),
              const SizedBox(height: 14),
              PzPanel(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PzDataRow(label: 'URL', value: w.url),
                    const Divider(),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _metaCell('Retrieved',
                              _PaperazziHomeState._date(w.retrievedAt)),
                          const VerticalDivider(width: 1),
                          _metaCell(
                              'Published',
                              w.publishedAt == null
                                  ? 'Not stated'
                                  : _PaperazziHomeState._date(w.publishedAt!)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const PzLabel('Retrieved excerpt'),
              const SizedBox(height: 6),
              PzPanel(
                child: SelectableText(
                    w.excerpt.isEmpty
                        ? 'The search provider returned no excerpt for this page.'
                        : w.excerpt,
                    style: Pz.body.copyWith(fontSize: 13.5)),
              ),
              const SizedBox(height: 16),
              PzPrimaryButton(
                label: 'Copy link',
                icon: Icons.link,
                height: 44,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _copyToClipboard(w.url, 'Link');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
