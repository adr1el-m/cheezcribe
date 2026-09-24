part of '../legacy_app.dart';

extension _ExportView on _PaperazziHomeState {
  List<Widget> _exportPanel(LegacyDocument doc) {
    final preview = switch (previewFormat) {
      'csv' => doc.exportCsv(),
      'records' when doc.hasRecords => doc.exportRecordsCsv(),
      _ => doc.exportJson(),
    };
    final formats = <(String, String, String, IconData, VoidCallback)>[
      (
        'JSON',
        'Fields, provenance, quality report, drawing objects',
        'json',
        Icons.data_object,
        () => export('json')
      ),
      (
        'Field ledger CSV',
        'One row per field with source line and decision',
        'csv',
        Icons.table_rows_outlined,
        () => export('csv')
      ),
      if (doc.hasRecords)
        (
          'Records CSV',
          'One row per grouped record',
          'records',
          Icons.table_chart_outlined,
          () => export('records')
        ),
      if (doc.drawingObjectCount > 0) ...[
        (
          'Drawing SVG',
          'Traced geometry, review-required',
          'svg',
          Icons.polyline_outlined,
          () => export('svg')
        ),
        (
          'CAD DXF',
          doc.cadIsCalibrated
              ? 'Scaled in ${doc.cadUnit}'
              : 'Unitless until calibrated',
          'dxf',
          Icons.architecture_outlined,
          () => export('dxf')
        ),
      ],
      (
        'Summary PDF',
        'Abstract, quality indicators, key entities',
        'pdf',
        Icons.picture_as_pdf_outlined,
        exportSummaryPdf
      ),
    ];

    return [
      if (doc.needsReview > 0) ...[
        PzNotice(
          '${doc.needsReview} unresolved field${doc.needsReview == 1 ? '' : 's'} export blank and marked requires_review.',
          color: Pz.review,
          icon: Icons.warning_amber_outlined,
        ).padded(),
        const SizedBox(height: 18),
      ],
      const PzSectionHeader('Formats').padded(),
      PzPanel(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (i, f) in formats.indexed) ...[
              if (i > 0) const Divider(indent: 56),
              InkWell(
                onTap: busy ? null : f.$5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          border: Border.all(color: Pz.lineStrong),
                          borderRadius: BorderRadius.circular(Pz.rChip),
                        ),
                        child: Icon(f.$4, size: 16, color: Pz.graphite),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.$1,
                                style: Pz.cardTitle.copyWith(fontSize: 14)),
                            Text(f.$2, style: Pz.meta.copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.file_download_outlined,
                          size: 20, color: Pz.blue),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ).padded(),
      const SizedBox(height: 10),
      Text(
        'Exports carry source references, OCR text, suggestions, and each verification decision. Source images are not embedded.',
        style: Pz.meta.copyWith(fontSize: 11.5, color: Pz.muted),
      ).padded(),
      const SizedBox(height: 26),
      Row(
        children: [
          const Expanded(child: PzSectionHeader('Live preview')),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PzIconButton(
              icon: Icons.copy_outlined,
              tooltip: 'Copy preview',
              color: Pz.blue,
              size: 18,
              onPressed: () =>
                  _copyToClipboard(preview, previewFormat.toUpperCase()),
            ),
          ),
        ],
      ).padded(),
      PzEngTabs(
        tabs: ['JSON', 'Field CSV', if (doc.hasRecords) 'Records'],
        index: switch (previewFormat) {
          'csv' => 1,
          'records' when doc.hasRecords => 2,
          _ => 0,
        },
        onChanged: (i) =>
            _update(() => previewFormat = const ['json', 'csv', 'records'][i]),
      ).padded(),
      Container(
        height: 260,
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: Pz.dark,
          borderRadius:
              BorderRadius.vertical(bottom: Radius.circular(Pz.rCard)),
        ),
        child: SingleChildScrollView(
          child: SelectableText(
            preview,
            style: const TextStyle(
              color: Color(0xFFD5DCE4),
              fontSize: 11,
              fontFamily: 'Menlo',
              fontFamilyFallback: ['Courier', 'monospace'],
              height: 1.45,
            ),
          ),
        ),
      ).padded(),
      const SizedBox(height: 18),
      PzPanel(
        padding: EdgeInsets.zero,
        child: PzDataRow(
          label: 'Device checkpoint',
          value:
              'Saved · $persistedSessionCount of ${SessionCheckpointStore.maxEntries} slots used',
          note:
              'Structured summary only; the source file stays on this device.',
          indicator: Pz.verified,
        ),
      ).padded(),
    ];
  }
}
