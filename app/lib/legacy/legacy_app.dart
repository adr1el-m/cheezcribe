import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_service.dart';
import 'legacy_models.dart';
import 'legacy_pipeline.dart';

const navy = Color(0xFF17243A);
const slate = Color(0xFF66758A);
const paper = Color(0xFFF7F5F0);
const border = Color(0xFFDFE4E7);
const teal = Color(0xFF087E82);
const amber = Color(0xFFAA661D);
const red = Color(0xFFB54343);

class LegacyLensApp extends StatefulWidget {
  const LegacyLensApp({super.key, required this.connection});
  final AiService connection;
  @override
  State<LegacyLensApp> createState() => _LegacyLensAppState();
}

class _LegacyLensAppState extends State<LegacyLensApp> {
  late final pipeline = LegacyPipeline(widget.connection);
  LegacyDocument? document;
  String? note;
  String? error;
  String stage = '';
  bool busy = false;
  bool allowCloudAi = false;
  int tab = 0;
  int pageIndex = 0;
  String? selectedId;
  bool get supportsImport =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    widget.connection.connect().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> import({bool sample = false}) async {
    if (busy || !supportsImport) return;
    setState(() {
      busy = true;
      error = null;
      note = null;
    });
    try {
      final result = await pipeline.importAndProcess(
          sample: sample,
          useAi: allowCloudAi,
          onStage: (value) {
            if (mounted) setState(() => stage = value);
          });
      if (!mounted || result == null) return;
      setState(() {
        document = result.document;
        note = sample ? 'Synthetic test document. ${result.note}' : result.note;
        pageIndex = 0;
        selectedId = result.document.fields
                .where((f) => f.needsReview)
                .firstOrNull
                ?.id ??
            result.document.fields.firstOrNull?.id;
        tab = 0;
      });
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => error = e.message ?? 'Could not read the document.');
      }
    } catch (e) {
      if (mounted) {
        setState(
            () => error = 'Processing failed. The source was not changed. $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          stage = '';
        });
      }
    }
  }

  Future<void> export(String format) async {
    final current = document;
    if (current == null || busy) return;
    try {
      await pipeline.export(current, format);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${format.toUpperCase()} export prepared. Save it in Files.')));
      }
    } on PlatformException catch (e) {
      if (mounted) setState(() => error = e.message ?? 'Export failed.');
    }
  }

  void decide(LegacyField field, FieldStatus status, String? value) {
    setState(() {
      document!.decide(field.id, status, value);
      final queue = document!.fields.where((f) => f.needsReview).toList();
      selectedId = queue.firstOrNull?.id ?? field.id;
    });
  }

  Future<void> edit(LegacyField field) async {
    final controller = TextEditingController(
        text: field.finalValue ?? field.aiValue ?? field.ocrValue ?? '');
    final value = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('Edit ${field.name}'),
              content: TextField(
                  controller: controller,
                  autofocus: true,
                  decoration:
                      const InputDecoration(labelText: 'Verified value')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () =>
                        Navigator.pop(context, controller.text.trim()),
                    child: const Text('Save correction'))
              ],
            ));
    controller.dispose();
    if (value != null && value.isNotEmpty && mounted) {
      decide(field, FieldStatus.edited, value);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'LegacyLens',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: paper,
          colorScheme: ColorScheme.fromSeed(seedColor: teal, surface: paper),
          textTheme: const TextTheme(bodyMedium: TextStyle(color: navy)),
          cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: border))),
          appBarTheme:
              const AppBarTheme(backgroundColor: paper, foregroundColor: navy),
          filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                  backgroundColor: teal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48))),
        ),
        home: LayoutBuilder(builder: (context, size) {
          final wide = size.maxWidth >= 850;
          final body = SafeArea(
              child: Row(children: [
            if (wide)
              NavigationRail(
                selectedIndex: tab,
                onDestinationSelected: (v) => setState(() => tab = v),
                labelType: NavigationRailLabelType.all,
                leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Icon(Icons.auto_stories_rounded,
                        color: teal, size: 32)),
                destinations: const [
                  NavigationRailDestination(
                      icon: Icon(Icons.folder_outlined),
                      selectedIcon: Icon(Icons.folder_rounded),
                      label: Text('Documents')),
                  NavigationRailDestination(
                      icon: Icon(Icons.fact_check_outlined),
                      selectedIcon: Icon(Icons.fact_check_rounded),
                      label: Text('Review')),
                  NavigationRailDestination(
                      icon: Icon(Icons.file_download_outlined),
                      selectedIcon: Icon(Icons.file_download_rounded),
                      label: Text('Export')),
                ],
              ),
            Expanded(
                child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: switch (tab) {
                          1 => _review(),
                          2 => _export(),
                          _ => _documents()
                        }))),
          ]));
          return Scaffold(
              body: body,
              bottomNavigationBar: wide
                  ? null
                  : NavigationBar(
                      selectedIndex: tab,
                      onDestinationSelected: (v) => setState(() => tab = v),
                      destinations: const [
                          NavigationDestination(
                              icon: Icon(Icons.folder_outlined),
                              label: 'Documents'),
                          NavigationDestination(
                              icon: Icon(Icons.fact_check_outlined),
                              label: 'Review'),
                          NavigationDestination(
                              icon: Icon(Icons.file_download_outlined),
                              label: 'Export'),
                        ]));
        }),
      );

  Widget _documents() => ListView(padding: const EdgeInsets.all(24), children: [
        _eyebrow('TEAM 08  /  LEGACY KNOWLEDGE'),
        const SizedBox(height: 10),
        const Text('Make history usable.',
            style: TextStyle(
                color: navy,
                fontSize: 38,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5)),
        const SizedBox(height: 8),
        const Text(
            'Turn fragile paper into traceable records, then review only what needs a human.',
            style: TextStyle(color: slate, fontSize: 15, height: 1.5)),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(
              onPressed: supportsImport && !busy ? () => import() : null,
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Import image or PDF')),
          OutlinedButton.icon(
              onPressed:
                  supportsImport && !busy ? () => import(sample: true) : null,
              icon: const Icon(Icons.science_outlined),
              label: const Text('Try synthetic sample')),
          Chip(
              avatar: Icon(
                  widget.connection.ready
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  size: 18,
                  color: widget.connection.ready ? teal : amber),
              label: Text(document?.fields.any((f) => f.aiValue != null) == true
                  ? 'Gemini responded'
                  : widget.connection.ready
                      ? 'AI setup loaded; request unverified'
                      : 'OCR only until Gemini connects')),
        ]),
        const SizedBox(height: 10),
        SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Interpret with Gemini',
                style: TextStyle(fontWeight: FontWeight.w700, color: navy)),
            subtitle: const Text(
                'When enabled, the page image and OCR text are sent to the hosted model.'),
            value: allowCloudAi,
            onChanged: widget.connection.ready && !busy
                ? (value) => setState(() => allowCloudAi = value)
                : null),
        if (!supportsImport)
          const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                  'Document import currently runs on iOS. This platform needs an OCR adapter.',
                  style: TextStyle(color: amber))),
        if (busy) _notice(Icons.hourglass_top_rounded, stage),
        if (note != null) _notice(Icons.info_outline, note!),
        if (error != null) _notice(Icons.error_outline, error!, color: red),
        const SizedBox(height: 22),
        if (document == null)
          _emptyState()
        else ...[
          _metrics(document!),
          const SizedBox(height: 24),
          _workspace(document!),
        ],
      ]);

  Widget _emptyState() => Card(
      child: Padding(
          padding: const EdgeInsets.all(28),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.description_outlined, color: teal, size: 38),
            const SizedBox(height: 20),
            const Text('Start with one legacy source',
                style: TextStyle(
                    fontSize: 23, fontWeight: FontWeight.w700, color: navy)),
            const SizedBox(height: 8),
            const Text(
                'Import a permitted image or a scanned PDF with up to five pages. '
                'OCR runs on this device. If Gemini is connected, it interprets the page and suggests structured fields.',
                style: TextStyle(color: slate, height: 1.5)),
            const SizedBox(height: 20),
            const Wrap(spacing: 8, runSpacing: 8, children: [
              Chip(label: Text('01  Read source')),
              Chip(label: Text('02  Link evidence')),
              Chip(label: Text('03  Review uncertainty')),
              Chip(label: Text('04  Export asset')),
            ]),
          ])));

  Widget _metrics(LegacyDocument doc) =>
      Wrap(spacing: 12, runSpacing: 12, children: [
        _metric('${doc.pages.length}', 'source pages',
            Icons.picture_as_pdf_outlined),
        _metric('${doc.fields.length}', 'extracted items',
            Icons.format_list_bulleted),
        _metric(
            '${doc.needsReview}', 'need review', Icons.rule_folder_outlined),
        _metric(
            '${doc.resolved}', 'resolved candidates', Icons.verified_outlined),
      ]);

  Widget _metric(String number, String label, IconData icon) => SizedBox(
      width: 190,
      child: Card(
          child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Icon(icon, color: teal),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(number,
                      style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                          color: navy)),
                  Text(label,
                      style: const TextStyle(fontSize: 11, color: slate)),
                ])
              ]))));

  Widget _workspace(LegacyDocument doc) =>
      LayoutBuilder(builder: (context, size) {
        final source = _sourcePanel(doc);
        final fields = _fieldsPanel(doc);
        return size.maxWidth > 730
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 5, child: source),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: fields),
              ])
            : Column(children: [source, const SizedBox(height: 16), fields]);
      });

  Widget _sourcePanel(LegacyDocument doc) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.image_search_rounded, color: teal),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(doc.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: navy))),
              if (doc.pages.length > 1)
                DropdownButton<int>(
                    value: pageIndex,
                    items: [
                      for (var i = 0; i < doc.pages.length; i++)
                        DropdownMenuItem(value: i, child: Text('Page ${i + 1}'))
                    ],
                    onChanged: (v) => setState(() => pageIndex = v ?? 0)),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                    color: const Color(0xFFE7E2D7),
                    alignment: Alignment.center,
                    constraints: const BoxConstraints(maxHeight: 560),
                    child: Image.memory(doc.pages[pageIndex].image,
                        fit: BoxFit.contain))),
            const SizedBox(height: 12),
            Text(
                '${doc.pages[pageIndex].lines.length} OCR lines on page ${pageIndex + 1} • original rendering preserved',
                style: const TextStyle(color: slate, fontSize: 12)),
          ])));

  Widget _fieldsPanel(LegacyDocument doc) => Card(
      child: Padding(
          padding: const EdgeInsets.all(18),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _eyebrow('STRUCTURED EXTRACTION'),
            const SizedBox(height: 8),
            Text(doc.documentType,
                style: const TextStyle(
                    fontSize: 21, fontWeight: FontWeight.w700, color: navy)),
            const SizedBox(height: 6),
            const Text(
                'Candidates link to OCR evidence. A review score is not a probability of correctness.',
                style: TextStyle(color: slate, fontSize: 12, height: 1.4)),
            const Divider(height: 28),
            if (doc.fields.isEmpty)
              const Text('No text was found. Try a clearer scan.',
                  style: TextStyle(color: slate)),
            for (final field in doc.fields.take(30))
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(field.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                subtitle: Text(
                    field.finalValue ??
                        field.aiValue ??
                        field.ocrValue ??
                        'Unreadable',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                trailing: _statusChip(field),
                onTap: () => setState(() {
                  selectedId = field.id;
                  tab = 1;
                }),
              ),
            if (doc.fields.length > 30)
              Text('+ ${doc.fields.length - 30} more items in Review',
                  style: const TextStyle(color: slate)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: () => setState(() => tab = 1),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Open review queue')),
          ])));

  Widget _review() {
    final doc = document;
    if (doc == null) {
      return _placeholder(
          'Review queue', 'Import a source to review extracted items.');
    }
    final selected = doc.fields.where((f) => f.id == selectedId).firstOrNull ??
        doc.fields.firstOrNull;
    return ListView(padding: const EdgeInsets.all(24), children: [
      _eyebrow('EVIDENCE BEFORE ACCEPTANCE'),
      const SizedBox(height: 8),
      const Text('Review queue',
          style: TextStyle(
              fontSize: 36, fontWeight: FontWeight.w800, color: navy)),
      const SizedBox(height: 6),
      Text(
          '${doc.needsReview} items need a decision • ${doc.resolved} resolved candidates',
          style: const TextStyle(color: slate)),
      const SizedBox(height: 20),
      if (selected == null)
        const Card(
            child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No OCR lines or extracted fields were found.')))
      else
        LayoutBuilder(builder: (context, size) {
          final list = _reviewList(doc);
          final detail = _reviewDetail(doc, selected);
          return size.maxWidth > 760
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 300, child: list),
                  const SizedBox(width: 16),
                  Expanded(child: detail),
                ])
              : Column(children: [list, const SizedBox(height: 16), detail]);
        }),
    ]);
  }

  Widget _reviewList(LegacyDocument doc) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Padding(
                padding: EdgeInsets.all(8),
                child: Text('Fields',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                        color: navy))),
            for (final field in doc.fields)
              ListTile(
                dense: true,
                selected: field.id == selectedId,
                selectedTileColor: const Color(0xFFE9F4F3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                title: Text(field.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                    field.needsReview ? 'Needs review' : field.status.name,
                    style: TextStyle(color: field.needsReview ? amber : teal)),
                trailing: Text('${(field.score * 100).round()}',
                    style: const TextStyle(color: slate, fontSize: 11)),
                onTap: () => setState(() => selectedId = field.id),
              ),
          ])));

  Widget _reviewDetail(LegacyDocument doc, LegacyField field) {
    final page = doc.pages.where((p) => p.number == field.page).firstOrNull;
    final line = page != null &&
            field.lineIndex >= 0 &&
            field.lineIndex < page.lines.length
        ? page.lines[field.lineIndex]
        : null;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(22),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                    child: Text(field.name,
                        style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: navy))),
                _statusChip(field)
              ]),
              const SizedBox(height: 8),
              Text(
                  'Page ${field.page} • OCR line ${field.lineIndex >= 0 ? field.lineIndex + 1 : 'unlinked'}',
                  style: const TextStyle(color: slate)),
              const SizedBox(height: 18),
              _eyebrow('SOURCE CROP'),
              const SizedBox(height: 8),
              Container(
                  height: 130,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF0EDE6),
                      borderRadius: BorderRadius.circular(12)),
                  child: line?.crop != null && line!.crop!.isNotEmpty
                      ? Image.memory(line.crop!, fit: BoxFit.contain)
                      : const Text('No source crop linked',
                          style: TextStyle(color: slate))),
              const SizedBox(height: 18),
              _evidence(
                  'OCR extraction', field.ocrValue ?? 'No linked OCR text'),
              _evidence(
                  'AI interpretation', field.aiValue ?? 'No AI suggestion'),
              _evidence('Current verified value',
                  field.finalValue ?? 'Awaiting review'),
              const SizedBox(height: 8),
              _notice(Icons.manage_search_rounded,
                  '${field.reason} • review score ${(field.score * 100).round()}/100'),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                    onPressed: field.aiValue == null
                        ? null
                        : () =>
                            decide(field, FieldStatus.accepted, field.aiValue),
                    icon: const Icon(Icons.check),
                    label: const Text('Accept suggestion')),
                OutlinedButton(
                    onPressed: field.ocrValue == null
                        ? null
                        : () =>
                            decide(field, FieldStatus.accepted, field.ocrValue),
                    child: const Text('Keep OCR')),
                OutlinedButton.icon(
                    onPressed: () => edit(field),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit value')),
                TextButton(
                    onPressed: () =>
                        decide(field, FieldStatus.unreadable, null),
                    child: const Text('Mark unreadable')),
              ]),
            ])));
  }

  Widget _export() {
    final doc = document;
    if (doc == null) {
      return _placeholder(
          'Export asset', 'Import and review a source before exporting.');
    }
    return ListView(padding: const EdgeInsets.all(24), children: [
      _eyebrow('REUSABLE DIGITAL ASSET'),
      const SizedBox(height: 8),
      const Text('Export with provenance.',
          style: TextStyle(
              fontSize: 36, fontWeight: FontWeight.w800, color: navy)),
      const SizedBox(height: 6),
      const Text(
          'The export keeps source references, OCR text, AI suggestions, review decisions, and unresolved values.',
          style: TextStyle(color: slate, height: 1.5)),
      const SizedBox(height: 20),
      _metrics(doc),
      if (doc.needsReview > 0)
        _notice(Icons.warning_amber_rounded,
            '${doc.needsReview} fields remain unresolved. Their exported values are blank and marked requires_review.',
            color: amber),
      const SizedBox(height: 20),
      Card(
          child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Choose a portable format',
                        style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            color: navy)),
                    const SizedBox(height: 8),
                    const Text(
                        'JSON and the field ledger retain provenance. For grouped entries, a records CSV is ready for spreadsheets.',
                        style: TextStyle(color: slate)),
                    const SizedBox(height: 18),
                    Wrap(spacing: 10, runSpacing: 10, children: [
                      FilledButton.icon(
                          onPressed: () => export('json'),
                          icon: const Icon(Icons.data_object),
                          label: const Text('Save JSON')),
                      OutlinedButton.icon(
                          onPressed: () => export('csv'),
                          icon: const Icon(Icons.table_rows_outlined),
                          label: const Text('Save field ledger CSV')),
                      if (doc.hasRecords)
                        OutlinedButton.icon(
                            onPressed: () => export('records'),
                            icon: const Icon(Icons.view_list_outlined),
                            label: const Text('Save records CSV')),
                    ]),
                  ]))),
      if (error != null) _notice(Icons.error_outline, error!, color: red),
      const SizedBox(height: 14),
      const Text(
          'Source pages are displayed for review in this session. Export does not embed the image files.',
          style: TextStyle(color: slate, fontSize: 12)),
    ]);
  }

  Widget _placeholder(String title, String message) =>
      ListView(padding: const EdgeInsets.all(24), children: [
        _eyebrow('LEGACYLENS'),
        const SizedBox(height: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 36, fontWeight: FontWeight.w800, color: navy)),
        const SizedBox(height: 16),
        Card(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(message, style: const TextStyle(color: slate)))),
        const SizedBox(height: 12),
        OutlinedButton(
            onPressed: () => setState(() => tab = 0),
            child: const Text('Go to Documents')),
      ]);

  Widget _eyebrow(String text) => Text(text,
      style: const TextStyle(
          color: teal,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
          fontSize: 11));

  Widget _notice(IconData icon, String text, {Color color = teal}) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 10),
            Expanded(
                child:
                    Text(text, style: TextStyle(color: color, height: 1.35))),
          ])));

  Widget _statusChip(LegacyField field) {
    final color = field.needsReview ? amber : teal;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Text(
            field.needsReview ? 'REVIEW' : field.status.name.toUpperCase(),
            style: TextStyle(
                color: color, fontSize: 9, fontWeight: FontWeight.w800)));
  }

  Widget _evidence(String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                color: slate,
                fontSize: 10,
                letterSpacing: 1,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        SelectableText(value,
            style: const TextStyle(
                color: navy, fontSize: 15, fontWeight: FontWeight.w600)),
      ]));
}
