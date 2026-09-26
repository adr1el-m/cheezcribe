part of '../legacy_app.dart';

String _fmtInt(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

String _fmtPercent(double? ratio) => ratio == null
    ? '—'
    : '${(ratio * 100).toStringAsFixed(ratio == 1 ? 0 : 1)}%';

extension _HomeView on _PaperazziHomeState {
  Widget _homeView() {
    final points = history.fold<int>(0, (sum, e) => sum + e.fieldCount);
    final pending = history.fold<int>(0, (sum, e) => sum + e.needsReview);
    final verified = points == 0 ? null : (points - pending) / points;
    final doc = document;

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Pz.gutter, 10, 8, 0),
          child: Row(
            children: [
              const PaperazziMark(size: 26),
              const SizedBox(width: 10),
              const Text('Paperazzi',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.3,
                      color: Pz.navy)),
              const Spacer(),
              PzIconButton(
                icon: Icons.tune,
                tooltip: 'Cloud extraction settings',
                color: Pz.steel,
                onPressed: openCloudSettings,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Pz.gutter, 24, Pz.gutter, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting(), style: Pz.meta),
              const SizedBox(height: 2),
              const Text('Archivist', style: Pz.screenTitle),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Pz.gutter, 20, Pz.gutter, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PzDataGrid([
                PzMetric('Documents', _fmtInt(history.length)),
                PzMetric('Data points', _fmtInt(points)),
                PzMetric('Verified', _fmtPercent(verified),
                    color: verified == 1 ? Pz.verified : null),
                PzMetric('Review', _fmtInt(pending),
                    color: pending > 0 ? Pz.review : null),
              ]),
              const SizedBox(height: 8),
              Text(
                  'Totals across ${history.length} checkpoint${history.length == 1 ? '' : 's'} on this device. '
                  'Verified counts accepted, revised, and source-linked fields.',
                  style: Pz.meta.copyWith(fontSize: 11.5, color: Pz.muted)),
              const SizedBox(height: 20),
              PzPrimaryButton(
                label: 'Scan Document',
                icon: Icons.document_scanner_outlined,
                onPressed: supportsImport && !busy
                    ? () => import(camera: supportsCameraScan)
                    : null,
              ),
              const SizedBox(height: 10),
              PzSecondaryButton(
                label: kIsWeb ? 'Import image' : 'Import image or PDF',
                icon: Icons.upload_file_outlined,
                onPressed: supportsImport && !busy ? () => import() : null,
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed:
                    supportsImport && !busy ? () => import(sample: true) : null,
                icon: const Icon(Icons.bolt_outlined, size: 18),
                label: const Text('Load Tagbilaran waterworks sample'),
              ),
              if (kIsWeb)
                const PzNotice(
                  'Use Scan Document to capture a real page with this device camera. Demo file is optional.',
                  color: Pz.blue,
                ),
              if (!supportsImport)
                const PzNotice(
                    'Native OCR runs on iOS and Android. Run on a phone or simulator to import a document.',
                    color: Pz.review),
              _messages(),
            ],
          ),
        ),
        if (doc != null) ...[
          const SizedBox(height: 28),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Pz.gutter),
            child: PzSectionHeader('Open document'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Pz.gutter),
            child: PzPanel(
              padding: EdgeInsets.zero,
              child: PzArchiveRow(
                title: _PaperazziHomeState._title(doc.name),
                subtitle: doc.documentType,
                meta:
                    '${_PaperazziHomeState._pad(doc.pages.length)} pages · ${doc.fields.length} fields · ${doc.needsReview} to verify',
                thumb: PzDocThumb(image: doc.pages.first.image),
                trailing: const Icon(Icons.chevron_right, color: Pz.steel),
                onTap: () => _go(_Tab.review, view: _ReviewView.document),
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Pz.gutter),
          child: PzSectionHeader('Recent archives',
              trailing: '${history.length} saved'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Pz.gutter),
          child: history.isEmpty
              ? PzPanel(
                  child: Text(
                      'Scanned and imported documents are listed here with their verification status.',
                      style: Pz.meta.copyWith(color: Pz.graphite)),
                )
              : PzPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (i, entry) in history.take(5).indexed) ...[
                        if (i > 0) const Divider(indent: 14),
                        _checkpointRow(entry),
                      ],
                    ],
                  ),
                ),
        ),
        if (history.length > 5)
          Padding(
            padding: const EdgeInsets.fromLTRB(Pz.gutter, 6, Pz.gutter, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => _go(_Tab.archive),
                child: Text('View all ${history.length} in Archive'),
              ),
            ),
          ),
      ],
    );
  }

  /// Archive record row for a saved checkpoint. Shared with the Archive tab.
  Widget _checkpointRow(SessionCheckpoint entry) {
    final ratio = entry.fieldCount == 0
        ? null
        : (entry.fieldCount - entry.needsReview) / entry.fieldCount;
    final isOpen = document?.name == entry.source;
    return PzArchiveRow(
      title: _PaperazziHomeState._title(entry.source),
      subtitle: entry.documentType,
      meta: '${_PaperazziHomeState._pad(entry.pageCount)} pages · '
          '${_fmtPercent(ratio)} verified · '
          '${_PaperazziHomeState._date(entry.savedAt)}',
      thumb: PzDocThumb(
          image: isOpen ? document!.pages.first.image : null,
          layers: entry.pageCount > 1 ? 2 : 1),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entry.needsReview > 0)
            const PzStatusBadge(PzStatus.review, dense: true)
          else if (entry.fieldCount > 0)
            const PzStatusBadge(PzStatus.verified, dense: true),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Delete archive',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.delete_outline, size: 19, color: Pz.error),
            onPressed: busy ? null : () => _deleteHistory(entry),
          ),
        ],
      ),
      onTap: isOpen
          ? () => _go(_Tab.review, view: _ReviewView.document)
          : entry.canReopen && !busy
              ? () => _openHistory(entry)
              : null,
    );
  }
}
