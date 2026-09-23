part of '../legacy_app.dart';

extension _ReviewShell on _PaperazziHomeState {
  Widget _reviewView() {
    final doc = document;
    if (doc == null) {
      return _emptyReview('Document Understanding',
          'Scan or import a document to see its extracted record, verify values against the source, and export.');
    }
    final title = switch (reviewView) {
      _ReviewView.document => 'Document Understanding',
      _ReviewView.verify => 'Verify Detail',
      _ReviewView.drawing => 'Drawing Intelligence',
      _ReviewView.export => 'Export',
    };
    return ListView(
      padding: const EdgeInsets.only(bottom: 36),
      children: [
        PzTopBar(
          overline: _PaperazziHomeState._title(doc.name),
          title: title,
          actions: [
            PzIconButton(
              icon: Icons.close,
              tooltip: 'Close document',
              color: Pz.steel,
              onPressed: busy ? null : _closeDocument,
            ),
          ],
        ),
        const SizedBox(height: 12),
        PzEngTabs(
          tabs: const ['Document', 'Verify', 'Drawing', 'Export'],
          index: reviewView.index,
          onChanged: (i) {
            HapticFeedback.selectionClick();
            _update(() => reviewView = _ReviewView.values[i]);
          },
        ).padded(),
        _messages().padded(),
        const SizedBox(height: 18),
        ...switch (reviewView) {
          _ReviewView.document => _understanding(doc),
          _ReviewView.verify => _verify(doc),
          _ReviewView.drawing => _drawing(doc),
          _ReviewView.export => _exportPanel(doc),
        },
      ],
    );
  }

  List<Widget> _understanding(LegacyDocument doc) {
    final page = doc.pages[pageIndex.clamp(0, doc.pages.length - 1)];
    final visible = showAllFields ? doc.fields : doc.fields.take(8).toList();
    final firstPending = doc.fields.where((f) => f.needsReview).firstOrNull;

    return [
      _pagePreview(doc, page).padded(),
      const SizedBox(height: 10),
      _previewControls(doc, page).padded(),
      const SizedBox(height: 26),
      PzSectionHeader('Extracted record',
              trailing: '${doc.fields.length} fields')
          .padded(),
      PzPanel(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PzDataRow(
              label: 'Document type',
              value: doc.documentType,
              valueStyle: Pz.cardTitle,
              trailing:
                  PzLabel('${_PaperazziHomeState._pad(doc.pages.length)} pg'),
            ),
            if (doc.fields.isEmpty) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                    'No structured fields were extracted. The OCR text is still available on the page.',
                    style: Pz.meta.copyWith(color: Pz.graphite)),
              ),
            ],
            for (final (i, field) in visible.indexed) ...[
              if (field.recordIndex > 0 &&
                  (i == 0 || visible[i - 1].recordIndex != field.recordIndex))
                _recordDivider(field.recordIndex)
              else
                const Divider(),
              _fieldRow(doc, field),
            ],
            if (doc.fields.length > 8) ...[
              const Divider(),
              TextButton(
                onPressed: () => _update(() => showAllFields = !showAllFields),
                child: Text(showAllFields
                    ? 'Show fewer'
                    : 'Show all ${doc.fields.length} fields'),
              ),
            ],
          ],
        ),
      ).padded(),
      const SizedBox(height: 14),
      _reviewCallout(doc, firstPending).padded(),
      const SizedBox(height: 28),
      const PzSectionHeader('Quality indicators').padded(),
      PzDataGrid([
        PzMetric('OCR lines', _fmtInt(doc.totalOcrLines)),
        PzMetric(
            'Mean OCR', '${(doc.meanOcrConfidence * 100).toStringAsFixed(1)}%'),
        PzMetric('Low conf.', _fmtInt(doc.lowConfidenceLines),
            color: doc.lowConfidenceLines > 0 ? Pz.review : null),
        PzMetric(
            'Linked', '${(doc.sourceLinkedRate * 100).toStringAsFixed(0)}%'),
        PzMetric('Enhanced',
            '${doc.pages.where((p) => p.enhancementApplied).length}'),
        PzMetric('Drawing', _fmtInt(doc.drawingObjectCount)),
      ], columns: 3)
          .padded(),
      const SizedBox(height: 8),
      Text(
        'Indicators route review. They are not an accuracy percentage.',
        style: Pz.meta.copyWith(fontSize: 11.5, color: Pz.muted),
      ).padded(),
      const SizedBox(height: 20),
      PzPanel(
        color: Pz.paper,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PzLabel('Abstract'),
            const SizedBox(height: 8),
            Text(doc.generateExecutiveAbstract(),
                style: Pz.body.copyWith(fontSize: 13.5)),
          ],
        ),
      ).padded(),
    ];
  }

  Widget _recordDivider(int record) => Container(
        color: Pz.surface2,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Row(
          children: [
            PzLabel('Record ${_PaperazziHomeState._pad(record)}',
                color: Pz.graphite, size: 10),
          ],
        ),
      );

  Widget _fieldRow(LegacyDocument doc, LegacyField field) {
    final page = doc.pages.where((p) => p.number == field.page).firstOrNull;
    final line = page != null &&
            field.lineIndex >= 0 &&
            field.lineIndex < page.lines.length
        ? page.lines[field.lineIndex]
        : null;
    final status = _PaperazziHomeState._statusOf(field);
    final flagged = status == PzStatus.review || status == PzStatus.unreadable;
    return PzDataRow(
      label: _PaperazziHomeState._fieldLabel(field.name),
      value: _PaperazziHomeState._displayValue(field) ?? 'Unreadable',
      indicator: flagged ? PzStatusBadge.describe(status).$2 : null,
      note: flagged
          ? PzStatusBadge.describe(status).$1
          : status == PzStatus.edited
              ? 'Revised'
              : null,
      selected: field.id == selectedId,
      trailing: PzConfidence(line?.confidence),
      onTap: () {
        HapticFeedback.selectionClick();
        _update(() {
          selectedId = field.id;
          if (field.resolved) reviewOnlyPending = false;
          reviewView = _ReviewView.verify;
        });
      },
    );
  }

  Widget _reviewCallout(LegacyDocument doc, LegacyField? firstPending) {
    final pending = doc.needsReview;
    return PzPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      borderColor: pending > 0 ? Pz.review.withValues(alpha: .45) : Pz.line,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PzLabel(
                  pending > 0
                      ? '$pending field${pending == 1 ? '' : 's'} require${pending == 1 ? 's' : ''} review'
                      : 'All fields resolved',
                  color: pending > 0 ? Pz.review : Pz.verified,
                ),
                const SizedBox(height: 4),
                Text(
                  pending > 0
                      ? 'Unresolved values export blank with requires_review.'
                      : 'Ready to export with provenance.',
                  style: Pz.meta,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PzPrimaryButton(
            expand: false,
            height: 40,
            label: pending > 0 ? 'Review Detail' : 'Export',
            onPressed: () {
              HapticFeedback.selectionClick();
              _update(() {
                if (firstPending != null) {
                  selectedId = firstPending.id;
                  reviewOnlyPending = true;
                  reviewView = _ReviewView.verify;
                } else {
                  reviewView = _ReviewView.export;
                }
              });
            },
          ),
        ],
      ),
    );
  }

  int? _selectedLineOnPage(LegacyDocument doc) {
    final field = doc.fields.where((f) => f.id == selectedId).firstOrNull;
    if (field != null && field.page == pageIndex + 1 && field.lineIndex >= 0) {
      return field.lineIndex;
    }
    return null;
  }

  /// Scan preview with stacked page edges, registration brackets, and
  /// optional OCR and drawing overlays.
  Widget _pagePreview(LegacyDocument doc, LegacyPage page) {
    const layer = 4.0;
    final image = showEnhanced && page.enhancedImage != null
        ? page.enhancedImage!
        : page.image;
    final aspect = page.pixelWidth > 1 && page.pixelHeight > 1
        ? page.pixelWidth / page.pixelHeight
        : .72;
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth - layer * 2;
      final height = (width / aspect).clamp(260.0, 520.0);
      return SizedBox(
        height: height + layer * 2,
        child: Stack(
          children: [
            for (var i = 2; i >= 1; i--)
              Positioned(
                left: layer * i,
                top: layer * (2 - i),
                width: width,
                height: height,
                child: Container(
                  decoration: BoxDecoration(
                    color: Pz.paper,
                    border: Border.all(color: Pz.lineStrong, width: .8),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              top: layer * 2,
              width: width,
              height: height,
              child: Container(
                clipBehavior: Clip.hardEdge,
                decoration: BoxDecoration(
                  color: Pz.paper,
                  border: Border.all(color: Pz.lineStrong),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      child: Center(
                        // The stack takes the rendered image size, so the
                        // normalized overlays line up on every platform.
                        child: Stack(
                          children: [
                            Image.memory(image,
                                fit: BoxFit.contain, gaplessPlayback: true),
                            if (showTextOverlay)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: OcrOverlayPainter(
                                    lines: page.lines,
                                    selectedLineIndex: _selectedLineOnPage(doc),
                                  ),
                                ),
                              ),
                            if (showDrawingOverlay &&
                                page.drawingObjects.isNotEmpty)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: DrawingOverlayPainter(
                                      objects: page.drawingObjects),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: PzCornerBrackets(
                        color: Pz.blue.withValues(alpha: .8),
                        inset: 8,
                        length: 14,
                        stroke: 1.2,
                        child: const SizedBox.expand(),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: _previewTag(
                          'Page ${_PaperazziHomeState._pad(page.number)} / ${_PaperazziHomeState._pad(doc.pages.length)}'),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: _previewTag(
                          showEnhanced && page.enhancedImage != null
                              ? 'Enhanced'
                              : 'Original'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _previewTag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        color: Pz.graphite.withValues(alpha: .86),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
                letterSpacing: .9,
                color: Colors.white,
                fontFeatures: Pz.tabular)),
      );

  Widget _previewControls(LegacyDocument doc, LegacyPage page) => Row(
        children: [
          if (doc.pages.length > 1) ...[
            _stepButton(Icons.chevron_left, 'Previous page',
                pageIndex > 0 ? () => _setPage(doc, pageIndex - 1) : null),
            _stepButton(
                Icons.chevron_right,
                'Next page',
                pageIndex < doc.pages.length - 1
                    ? () => _setPage(doc, pageIndex + 1)
                    : null),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: [
                  _layerToggle(
                      'Text',
                      page.lines.length,
                      Pz.overlayText,
                      showTextOverlay,
                      () => _update(() => showTextOverlay = !showTextOverlay)),
                  if (page.drawingObjects.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _layerToggle(
                        'Drawing',
                        page.drawingObjects.length,
                        Pz.overlayDrawing,
                        showDrawingOverlay,
                        () => _update(
                            () => showDrawingOverlay = !showDrawingOverlay)),
                  ],
                  if (page.enhancedImage != null) ...[
                    const SizedBox(width: 6),
                    _layerToggle('Enhanced', null, Pz.steel, showEnhanced,
                        () => _update(() => showEnhanced = !showEnhanced)),
                  ],
                ],
              ),
            ),
          ),
        ],
      );

  void _setPage(LegacyDocument doc, int index) {
    HapticFeedback.selectionClick();
    _update(() {
      pageIndex = index;
      showEnhanced = doc.pages[index].enhancementApplied;
    });
  }

  Widget _stepButton(IconData icon, String tooltip, VoidCallback? onTap) =>
      Padding(
        padding: const EdgeInsets.only(right: 4),
        child: SizedBox(
          width: 34,
          height: 32,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(34, 32),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Pz.rChip)),
            ),
            child: Icon(icon, size: 18),
          ),
        ),
      );

  Widget _layerToggle(
          String label, int? count, Color color, bool on, VoidCallback onTap) =>
      InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(Pz.rChip),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: on ? color.withValues(alpha: .07) : Pz.card,
            borderRadius: BorderRadius.circular(Pz.rChip),
            border: Border.all(
                color: on ? color.withValues(alpha: .5) : Pz.lineStrong),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: on ? color : Colors.transparent,
                  border: Border.all(color: on ? color : Pz.muted),
                ),
              ),
              const SizedBox(width: 7),
              Text(label.toUpperCase(),
                  style: Pz.label
                      .copyWith(fontSize: 10, color: on ? Pz.navy : Pz.steel)),
              if (count != null) ...[
                const SizedBox(width: 5),
                Text('$count',
                    style: Pz.label.copyWith(
                        fontSize: 10,
                        color: Pz.muted,
                        fontFeatures: Pz.tabular)),
              ],
            ],
          ),
        ),
      );
}
