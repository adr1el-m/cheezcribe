part of '../legacy_app.dart';

extension _VerifyView on _PaperazziHomeState {
  List<Widget> _verify(LegacyDocument doc) {
    final queue = reviewOnlyPending
        ? doc.fields.where((f) => f.needsReview).toList()
        : doc.fields;
    final field = doc.fields.where((f) => f.id == selectedId).firstOrNull ??
        queue.firstOrNull ??
        doc.fields.firstOrNull;

    final header = _queueBar(doc, queue, field);
    if (field == null) {
      return [
        header.padded(),
        const SizedBox(height: 16),
        PzPanel(
          child: Text('No extracted fields to verify in this document.',
              style: Pz.meta.copyWith(color: Pz.graphite)),
        ).padded(),
      ];
    }

    final (page, line, lineIndex) = _PaperazziHomeState._sourceFor(doc, field);
    final zone = line == null ? null : _PaperazziHomeState._zoneOf(line.box);
    final status = _PaperazziHomeState._statusOf(field);
    final (statusLabel, statusColor) = PzStatusBadge.describe(status);
    final suggestion = field.aiValue ?? field.suggestedValue;
    final detected = suggestion ?? field.ocrValue;
    final confidence = line?.confidence;
    final revision = field.ocrValue == null || field.finalValue == null
        ? null
        : _PaperazziHomeState._editDistance(
            field.ocrValue!.trim(), field.finalValue!.trim());
    final reference = [
      'Page ${_PaperazziHomeState._pad(field.page)}',
      if (zone != null) 'Zone $zone',
      if (lineIndex >= 0) 'Line ${_PaperazziHomeState._pad(lineIndex + 1, 3)}',
    ];

    return [
      header.padded(),
      const SizedBox(height: 22),
      Row(
        children: [
          const PzLabel('Source crop', color: Pz.graphite),
          const Spacer(),
          PzSourceReference(parts: reference),
        ],
      ).padded(),
      const SizedBox(height: 10),
      Container(
        height: 124,
        decoration: BoxDecoration(
          color: Pz.paper,
          borderRadius: BorderRadius.circular(Pz.rCard),
          border: Border.all(color: Pz.line),
        ),
        child: PzCornerBrackets(
          inset: 8,
          length: 12,
          stroke: 1.3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Center(
              child: line?.crop != null && line!.crop!.isNotEmpty
                  ? Image.memory(line.crop!,
                      fit: BoxFit.contain, gaplessPlayback: true)
                  : page != null && line != null && _canZoom(page, line)
                      ? _zoomedRegion(page, line)
                      : page != null
                          ? Image.memory(page.image,
                              fit: BoxFit.contain, gaplessPlayback: true)
                          : const Icon(Icons.image_not_supported_outlined,
                              color: Pz.muted),
            ),
          ),
        ),
      ).padded(),
      Row(
        children: [
          Expanded(
            child: Text(
              (line?.crop != null && line!.crop!.isNotEmpty) ||
                      (page != null && line != null && _canZoom(page, line))
                  ? 'Original scan region'
                  : 'No line region · showing full page',
              maxLines: 2,
              style: Pz.meta.copyWith(fontSize: 11.5, color: Pz.muted),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              HapticFeedback.selectionClick();
              _update(() {
                pageIndex = (field.page - 1).clamp(0, doc.pages.length - 1);
                showTextOverlay = true;
                showEnhanced = doc.pages[pageIndex].enhancementApplied;
                reviewView = _ReviewView.document;
              });
            },
            icon: const Icon(Icons.center_focus_strong_outlined, size: 16),
            label: const Text('Locate on page'),
          ),
        ],
      ).padded(),
      const SizedBox(height: 10),
      PzPanel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PzLabel(
                      'Detected value · ${_PaperazziHomeState._fieldLabel(field.name)}'),
                  const SizedBox(height: 8),
                  SelectableText(detected ?? '—',
                      style: Pz.figure.copyWith(fontSize: 26)),
                ],
              ),
            ),
            const Divider(),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _metaCell(
                      'Confidence',
                      confidence == null
                          ? '—'
                          : '${(confidence * 100).round()}%',
                      color: confidence == null
                          ? Pz.steel
                          : confidence >= .85
                              ? Pz.verified
                              : Pz.review),
                  const VerticalDivider(width: 1),
                  _metaCell('Status', statusLabel, color: statusColor),
                  const VerticalDivider(width: 1),
                  _metaCell(
                      'Review score', '${(field.score * 100).round()}/100'),
                ],
              ),
            ),
          ],
        ),
      ).padded(),
      const SizedBox(height: 26),
      const PzSectionHeader('Change log').padded(),
      PzPanel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PzDataRow(
              label: lineIndex >= 0
                  ? 'Source · OCR line ${_PaperazziHomeState._pad(lineIndex + 1, 3)}'
                  : 'Source · OCR',
              value: field.ocrValue ?? 'No linked OCR text',
            ),
            const Divider(),
            PzDataRow(
              label: field.aiValue != null
                  ? 'Suggestion · cloud (Gemini)'
                  : 'Suggestion · on-device',
              value: suggestion ?? 'No supported interpretation',
            ),
            const Divider(),
            PzDataRow(
              label: 'Current value',
              value: field.status == FieldStatus.unreadable
                  ? 'Marked unreadable'
                  : field.finalValue ?? 'Awaiting verification',
              valueStyle: Pz.value.copyWith(fontWeight: FontWeight.w700),
              indicator: field.needsReview ? Pz.review : statusColor,
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 11, 14, 12),
              child: Row(
                children: [
                  const SizedBox(width: 96, child: PzLabel('Revision')),
                  Expanded(
                      child: Align(
                          alignment: Alignment.centerLeft,
                          child: PzRevisionIndicator(changes: revision))),
                ],
              ),
            ),
            const Divider(),
            PzDataRow(label: 'Routing reason', value: field.reason),
          ],
        ),
      ).padded(),
      const SizedBox(height: 12),
      PzPanel(
        padding: EdgeInsets.zero,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _metaCell('Archive', _PaperazziHomeState._title(doc.name)),
              const VerticalDivider(width: 1),
              _metaCell('Page', _PaperazziHomeState._pad(field.page)),
              const VerticalDivider(width: 1),
              _metaCell(
                  'Record',
                  field.recordIndex > 0
                      ? _PaperazziHomeState._pad(field.recordIndex)
                      : 'Header'),
            ],
          ),
        ),
      ).padded(),
      const SizedBox(height: 20),
      Row(
        children: [
          Expanded(
            child: PzPrimaryButton(
              label: 'Confirm',
              icon: Icons.check,
              onPressed: detected == null
                  ? null
                  : () => decide(field, FieldStatus.accepted, detected),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PzSecondaryButton(
              label: 'Edit',
              icon: Icons.edit_outlined,
              height: 48,
              onPressed: () => edit(field),
            ),
          ),
        ],
      ).padded(),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(
            child: PzSecondaryButton(
              label: 'Keep OCR',
              icon: Icons.text_fields,
              onPressed: field.ocrValue == null || field.ocrValue == detected
                  ? null
                  : () => decide(field, FieldStatus.accepted, field.ocrValue),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PzSecondaryButton(
              label: 'Mark unreadable',
              color: Pz.error,
              onPressed: () => decide(field, FieldStatus.unreadable, null),
            ),
          ),
        ],
      ).padded(),
      const SizedBox(height: 10),
      Text(
        'Each decision is saved to the device checkpoint and exported with its source reference.',
        style: Pz.meta.copyWith(fontSize: 11.5, color: Pz.muted),
      ).padded(),
      const SizedBox(height: 28),
      PzSectionHeader(reviewOnlyPending ? 'Verification queue' : 'All fields',
              trailing: '${queue.length}')
          .padded(),
      _roster(queue, field).padded(),
    ];
  }

  bool _canZoom(LegacyPage page, OcrLine line) =>
      page.pixelWidth > 1 &&
      page.pixelHeight > 1 &&
      line.box.length >= 4 &&
      line.box[2] > 0 &&
      line.box[3] > 0;

  /// Shows the page scaled so the OCR line's box fills the frame, with a
  /// little surrounding context.
  Widget _zoomedRegion(LegacyPage page, OcrLine line) =>
      LayoutBuilder(builder: (context, constraints) {
        const padX = .02, padY = .012;
        final l = (line.box[0] - padX).clamp(0.0, 1.0);
        final t = (line.box[1] - padY).clamp(0.0, 1.0);
        final w = (line.box[2] + padX * 2).clamp(0.01, 1.0 - l);
        final h = (line.box[3] + padY * 2).clamp(0.01, 1.0 - t);
        final aspect = (w * page.pixelWidth) / (h * page.pixelHeight);
        var width = constraints.maxWidth;
        var height = width / aspect;
        if (height > constraints.maxHeight) {
          height = constraints.maxHeight;
          width = height * aspect;
        }
        final fullWidth = width / w;
        final fullHeight = fullWidth * page.pixelHeight / page.pixelWidth;
        return SizedBox(
          width: width,
          height: height,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.topLeft,
              minWidth: 0,
              minHeight: 0,
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: Transform.translate(
                offset: Offset(-l * fullWidth, -t * fullHeight),
                child: SizedBox(
                  width: fullWidth,
                  height: fullHeight,
                  child: Image.memory(page.image,
                      fit: BoxFit.fill, gaplessPlayback: true),
                ),
              ),
            ),
          ),
        );
      });

  Widget _queueBar(
      LegacyDocument doc, List<LegacyField> queue, LegacyField? field) {
    final index =
        field == null ? -1 : queue.indexWhere((f) => f.id == field.id);
    Widget tab(String label, bool active, VoidCallback onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Pz.rChip),
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? Pz.navy : Pz.card,
              borderRadius: BorderRadius.circular(Pz.rChip),
              border: Border.all(color: active ? Pz.navy : Pz.lineStrong),
            ),
            child: Text(label.toUpperCase(),
                style: Pz.label.copyWith(
                    fontSize: 10,
                    color: active ? Colors.white : Pz.steel,
                    fontFeatures: Pz.tabular)),
          ),
        );

    return Row(
      children: [
        tab('Review ${doc.needsReview}', reviewOnlyPending, () {
          HapticFeedback.selectionClick();
          _update(() {
            reviewOnlyPending = true;
            if (field != null && field.resolved) {
              selectedId =
                  doc.fields.where((f) => f.needsReview).firstOrNull?.id;
            }
          });
        }),
        const SizedBox(width: 6),
        tab('All ${doc.fields.length}', !reviewOnlyPending, () {
          HapticFeedback.selectionClick();
          _update(() => reviewOnlyPending = false);
        }),
        const Spacer(),
        _stepButton(
            Icons.chevron_left,
            'Previous field',
            index > 0
                ? () => _update(() => selectedId = queue[index - 1].id)
                : null),
        SizedBox(
          width: 64,
          child: Text(
            index >= 0
                ? '${_PaperazziHomeState._pad(index + 1)} / ${_PaperazziHomeState._pad(queue.length)}'
                : '— / ${_PaperazziHomeState._pad(queue.length)}',
            textAlign: TextAlign.center,
            style: Pz.value.copyWith(fontSize: 12.5, color: Pz.steel),
          ),
        ),
        _stepButton(
            Icons.chevron_right,
            'Next field',
            index >= 0 && index < queue.length - 1
                ? () => _update(() => selectedId = queue[index + 1].id)
                : null),
      ],
    );
  }

  Widget _roster(List<LegacyField> queue, LegacyField current) {
    if (queue.isEmpty) {
      return PzPanel(
        child: Text('Queue clear. Every field has a decision.',
            style: Pz.meta.copyWith(color: Pz.verified)),
      );
    }
    const limit = 40;
    final shown = queue.take(limit).toList();
    return PzPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, f) in shown.indexed) ...[
            if (i > 0) const Divider(),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                _update(() => selectedId = f.id);
              },
              child: Container(
                color:
                    f.id == current.id ? Pz.blue.withValues(alpha: .05) : null,
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(_PaperazziHomeState._pad(i + 1),
                          style: Pz.meta
                              .copyWith(fontSize: 11.5, color: Pz.muted)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_PaperazziHomeState._fieldLabel(f.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Pz.cardTitle.copyWith(
                                  fontSize: 13.5,
                                  color:
                                      f.id == current.id ? Pz.blue : Pz.navy)),
                          Text(_PaperazziHomeState._displayValue(f) ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Pz.meta.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    PzStatusBadge(_PaperazziHomeState._statusOf(f),
                        dense: true),
                  ],
                ),
              ),
            ),
          ],
          if (queue.length > limit) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                  '${queue.length - limit} more · use the stepper to continue',
                  style: Pz.meta),
            ),
          ],
        ],
      ),
    );
  }
}
