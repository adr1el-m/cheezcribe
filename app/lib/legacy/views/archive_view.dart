part of '../legacy_app.dart';

String _norm(String value) =>
    value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

extension _ArchiveView on _PaperazziHomeState {
  Widget _archiveTabs() => PzEngTabs(
        tabs: const ['Search', 'Knowledge Fusion'],
        index: archiveMode,
        onChanged: (i) {
          HapticFeedback.selectionClick();
          _update(() => archiveMode = i);
        },
      );

  Widget _archiveView() {
    if (archiveMode == 1) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 40),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const PzTopBar(overline: 'Asset records', title: 'Archive'),
          const SizedBox(height: 12),
          _archiveTabs().padded(),
          ..._fusionPanel(),
        ],
      );
    }
    final q = archiveQuery.trim().toLowerCase();
    final doc = document;
    final fieldMatches = doc == null || q.isEmpty
        ? const <LegacyField>[]
        : doc.fields.where((f) {
            final value = _PaperazziHomeState._displayValue(f) ?? '';
            return value.toLowerCase().contains(q) ||
                _PaperazziHomeState._fieldLabel(f.name)
                    .toLowerCase()
                    .contains(q);
          }).toList();
    final archives = q.isEmpty
        ? history
        : history
            .where((e) =>
                e.source.toLowerCase().contains(q) ||
                e.documentType.toLowerCase().contains(q))
            .toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        const PzTopBar(overline: 'Asset records', title: 'Archive'),
        const SizedBox(height: 12),
        _archiveTabs().padded(),
        Padding(
          padding: const EdgeInsets.fromLTRB(Pz.gutter, 18, Pz.gutter, 0),
          child: TextField(
            controller: archiveSearch,
            onChanged: (v) => _update(() => archiveQuery = v),
            textInputAction: TextInputAction.search,
            style: Pz.value.copyWith(fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search asset, drawing, record…',
              prefixIcon: const Icon(Icons.search, size: 20, color: Pz.steel),
              suffixIcon: archiveQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.close, size: 18, color: Pz.steel),
                      onPressed: () {
                        archiveSearch.clear();
                        _update(() => archiveQuery = '');
                      },
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Pz.gutter, 8, Pz.gutter, 0),
          child: Text(
            doc == null
                ? 'Field search covers the open document. Saved archives match by title and type.'
                : 'Searching fields in ${_PaperazziHomeState._title(doc.name)} and saved archive titles.',
            style: Pz.meta.copyWith(fontSize: 11.5, color: Pz.muted),
          ),
        ),
        _messages().padded(),
        if (fieldMatches.isNotEmpty) ...[
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Pz.gutter),
            child: _entityResult(doc!, fieldMatches, q),
          ),
        ] else if (q.isNotEmpty && doc != null) ...[
          const SizedBox(height: 4),
          PzNotice('No field in the open document matches "$archiveQuery".')
              .padded(),
        ],
        const SizedBox(height: 26),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Pz.gutter),
          child: Row(
            children: [
              Expanded(
                child: PzSectionHeader(
                    q.isEmpty ? 'Saved archives' : 'Archive matches',
                    trailing: '${archives.length}'),
              ),
              if (q.isEmpty && history.isNotEmpty)
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear all archives?'),
                        content: const Text(
                            'This will remove all saved checkpoints from this device. '
                            'Exported files are not affected.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Clear',
                                style: TextStyle(color: Pz.review)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) await _clearArchive();
                  },
                  child: Text('Clear all',
                      style: Pz.meta.copyWith(
                          fontSize: 12, color: Pz.review)),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Pz.gutter),
          child: archives.isEmpty
              ? PzPanel(
                  child: Text(
                      q.isEmpty
                          ? 'No saved archives yet. Each scan or import saves a checkpoint here.'
                          : 'No saved archive title or type matches.',
                      style: Pz.meta.copyWith(color: Pz.graphite)),
                )
              : PzPanel(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (final (i, entry) in archives.indexed) ...[
                        if (i > 0) const Divider(indent: 14),
                        _checkpointRow(entry),
                      ],
                    ],
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Pz.gutter, 10, Pz.gutter, 0),
          child: Text(
            '${history.length} of ${SessionCheckpointStore.maxEntries} checkpoints · '
            '$indexedCount documents in the knowledge index. Extracted text '
            'stays on this device; source images are not stored.',
            style: Pz.meta.copyWith(fontSize: 11.5, color: Pz.muted),
          ),
        ),
      ],
    );
  }

  Widget _entityResult(
      LegacyDocument doc, List<LegacyField> matches, String query) {
    // The primary entity is the most repeated matching value.
    final groups = <String, List<LegacyField>>{};
    for (final f in matches) {
      final value = _PaperazziHomeState._displayValue(f);
      if (value == null || value.trim().isEmpty) continue;
      groups.putIfAbsent(_norm(value), () => []).add(f);
    }
    final primaryGroup = groups.values.isEmpty
        ? matches
        : (groups.values.toList()..sort((a, b) => b.length.compareTo(a.length)))
            .first;
    final primary = primaryGroup.first;
    final pages = matches.map((f) => f.page).toSet().toList()..sort();
    final records = matches
        .where((f) => f.recordIndex > 0)
        .map((f) => f.recordIndex)
        .toSet();
    final pendingCount = matches.where((f) => f.needsReview).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PzPanel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PzLabel('Primary match', color: Pz.blue),
                    const SizedBox(height: 8),
                    Text(_PaperazziHomeState._displayValue(primary) ?? '—',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Pz.figure.copyWith(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(
                        '${_PaperazziHomeState._fieldLabel(primary.name)} · ${doc.documentType}',
                        style: Pz.meta),
                    const SizedBox(height: 10),
                    Text(
                      '${matches.length} source line${matches.length == 1 ? '' : 's'} · '
                      '${records.isEmpty ? 'document metadata' : '${records.length} linked record${records.length == 1 ? '' : 's'}'}',
                      style: Pz.value
                          .copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Divider(),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _metaCell(
                        'Type', _PaperazziHomeState._fieldLabel(primary.name)),
                    const VerticalDivider(width: 1),
                    _metaCell(
                        'Pages',
                        pages
                            .map((p) => _PaperazziHomeState._pad(p))
                            .join(', ')),
                    const VerticalDivider(width: 1),
                    _metaCell(
                        'Status',
                        pendingCount == 0
                            ? 'Verified'
                            : '$pendingCount to verify',
                        color: pendingCount == 0 ? Pz.verified : Pz.review),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        PzSectionHeader('Source records', trailing: '${matches.length}'),
        PzPanel(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final (i, f) in matches.take(24).indexed)
                _sourceRecordRow(doc, f,
                    first: i == 0, last: i == matches.take(24).length - 1),
            ],
          ),
        ),
        if (matches.length > 24)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('${matches.length - 24} more in the Review queue',
                style: Pz.meta),
          ),
      ],
    );
  }

  Widget _metaCell(String label, String value, {Color? color}) => Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PzLabel(label, size: 10),
              const SizedBox(height: 5),
              Text(value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Pz.value.copyWith(
                      fontSize: 13, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );

  /// Row with a relationship rail: records that share a match are joined by a
  /// continuous line so the chain reads top to bottom.
  Widget _sourceRecordRow(LegacyDocument doc, LegacyField field,
      {required bool first, required bool last}) {
    final (page, line, lineIndex) = _PaperazziHomeState._sourceFor(doc, field);
    final zone = line == null ? null : _PaperazziHomeState._zoneOf(line.box);
    final status = _PaperazziHomeState._statusOf(field);
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        _update(() {
          selectedId = field.id;
          reviewOnlyPending = false;
          pageIndex = (field.page - 1).clamp(0, doc.pages.length - 1);
          tab = _Tab.review;
          reviewView = _ReviewView.verify;
        });
      },
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 30,
              child: Column(
                children: [
                  Expanded(
                      child: Container(
                          width: 1,
                          color: first ? Colors.transparent : Pz.lineStrong)),
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: Pz.card,
                      border: Border.all(
                          color: PzStatusBadge.describe(status).$2, width: 1.5),
                    ),
                  ),
                  Expanded(
                      child: Container(
                          width: 1,
                          color: last ? Colors.transparent : Pz.lineStrong)),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 34,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Pz.paper,
                        border: Border.all(color: Pz.line),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: line?.crop != null && line!.crop!.isNotEmpty
                          ? Image.memory(line.crop!,
                              fit: BoxFit.cover, gaplessPlayback: true)
                          : page != null && line != null && _canZoom(page, line)
                              ? Center(child: _zoomedRegion(page, line))
                              : const Icon(Icons.short_text,
                                  size: 16, color: Pz.muted),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_PaperazziHomeState._fieldLabel(field.name),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Pz.cardTitle.copyWith(fontSize: 14)),
                          Text(_PaperazziHomeState._displayValue(field) ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Pz.meta.copyWith(color: Pz.graphite)),
                          const SizedBox(height: 4),
                          PzSourceReference(parts: [
                            'Page ${_PaperazziHomeState._pad(field.page)}',
                            if (zone != null) 'Zone $zone',
                            if (lineIndex >= 0)
                              'Line ${_PaperazziHomeState._pad(lineIndex + 1, 3)}',
                            if (field.recordIndex > 0)
                              'Rec ${_PaperazziHomeState._pad(field.recordIndex)}',
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right, size: 18, color: Pz.muted),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on Widget {
  Widget padded() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Pz.gutter),
        child: this,
      );
}
