import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../fusion/fusion_models.dart';
import '../fusion/fusion_pipeline.dart';
import '../fusion/knowledge_index.dart';
import '../fusion/llm_client.dart';
import '../services/ai_service.dart';
import 'legacy_models.dart';
import 'legacy_pipeline.dart';
import 'session_checkpoint_store.dart';
import 'ui/pz_components.dart';
import 'ui/pz_painters.dart';
import 'ui/pz_tokens.dart';

part 'views/home_view.dart';
part 'views/scan_view.dart';
part 'views/archive_view.dart';
part 'views/review_view.dart';
part 'views/verify_view.dart';
part 'views/drawing_view.dart';
part 'views/export_view.dart';
part 'views/fusion_view.dart';

/// Brand mark from the app icon, used small and flat in headers.
class PaperazziMark extends StatelessWidget {
  const PaperazziMark({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * .22),
        child: Image.asset(
          'assets/icons/paperazzi.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
        ),
      );
}

class PaperazziApp extends StatelessWidget {
  const PaperazziApp({super.key, required this.connection});
  final AiService connection;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Paperazzi',
        debugShowCheckedModeBanner: false,
        theme: Pz.theme(),
        home: PaperazziHome(connection: connection),
      );
}

class PaperazziHome extends StatefulWidget {
  const PaperazziHome({super.key, required this.connection});
  final AiService connection;

  @override
  State<PaperazziHome> createState() => _PaperazziHomeState();
}

enum _Tab { home, scan, archive, review }

enum _ReviewView { document, verify, drawing, export }

class _PaperazziHomeState extends State<PaperazziHome> {
  late final pipeline = LegacyPipeline(widget.connection);
  final checkpointStore = SessionCheckpointStore();

  LegacyDocument? document;
  String? note;
  String? error;
  String stage = '';
  bool busy = false;
  bool justImported = false;
  bool allowCloudAi = false;
  _Tab tab = _Tab.home;
  _ReviewView reviewView = _ReviewView.document;
  int pageIndex = 0;
  String? selectedId;
  bool showTextOverlay = true;
  bool showDrawingOverlay = false;
  bool showEnhanced = false;
  bool showAllFields = false;
  bool reviewOnlyPending = true;
  int drawingMode = 1;
  int? selectedDrawing;
  String previewFormat = 'json';
  String archiveQuery = '';
  final archiveSearch = TextEditingController();
  int archiveMode = 0;

  // Knowledge Fusion. The OpenRouter key is session-only unless supplied at
  // build time with --dart-define=OPENROUTER_API_KEY.
  final knowledgeStore = FileKnowledgeStore();
  final fusionLlm = OpenRouterClient(
    apiKey: const String.fromEnvironment('OPENROUTER_API_KEY'),
    model: const String.fromEnvironment('OPENROUTER_MODEL'),
  );
  late final fusionPipeline =
      KnowledgeFusionPipeline(store: knowledgeStore, llm: fusionLlm);
  final fusionInput = TextEditingController();
  final fusionResults = <FusionOutcome>[];
  FusionStage? fusionStage;
  bool fusionBusy = false;
  int indexedCount = 0;
  int persistedSessionCount = 0;
  List<SessionCheckpoint> history = const [];

  bool get supportsImport =>
      kIsWeb ||
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  bool get supportsCameraScan =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  String get ocrEngineName => kIsWeb
      ? 'Browser demo'
      : defaultTargetPlatform == TargetPlatform.android
          ? 'ML Kit'
          : 'Apple Vision';

  /// Part files call this instead of the protected [setState].
  void _update(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    checkpointStore.count().then((value) {
      if (mounted) setState(() => persistedSessionCount = value);
    });
    _reloadHistory();
    _refreshIndexCount();
  }

  Future<void> _refreshIndexCount() async {
    try {
      final docs = await knowledgeStore.list();
      if (mounted) setState(() => indexedCount = docs.length);
    } catch (_) {}
  }

  /// Keeps the searchable text copy current. Source images are not stored.
  Future<void> _indexDocument(LegacyDocument doc) async {
    try {
      await knowledgeStore.save(IndexedDocument.fromDocument(doc));
      await _refreshIndexCount();
    } catch (indexError) {
      debugPrint('Paperazzi knowledge index skipped: $indexError');
    }
  }

  @override
  void dispose() {
    archiveSearch.dispose();
    fusionInput.dispose();
    super.dispose();
  }

  Future<void> _reloadHistory() async {
    final entries = await checkpointStore.list();
    if (mounted) setState(() => history = entries);
  }

  void _go(_Tab next, {_ReviewView? view}) {
    HapticFeedback.selectionClick();
    setState(() {
      tab = next;
      if (view != null) reviewView = view;
    });
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          duration: const Duration(seconds: 2), content: Text(message)));
  }

  Future<void> import({bool sample = false, bool camera = false}) async {
    if (busy || !supportsImport) return;
    HapticFeedback.lightImpact();
    setState(() {
      busy = true;
      justImported = false;
      error = null;
      note = null;
      tab = _Tab.scan;
    });
    try {
      final result = await pipeline.importAndProcess(
          sample: sample,
          camera: camera,
          useAi: allowCloudAi,
          onStage: (value) {
            if (mounted) setState(() => stage = value);
          },
          onAiError: (value) {
            debugPrint(
                'Cloud extraction bypassed, using on-device structuring: $value');
          });
      if (!mounted || result == null) return;
      setState(() {
        document = result.document;
        note =
            sample ? 'Bundled evaluation sample. ${result.note}' : result.note;
        justImported = true;
        _resetDocumentView(result.document);
      });
      persistedSessionCount = await checkpointStore.save(result.document);
      await _reloadHistory();
      unawaited(_indexDocument(result.document));
      HapticFeedback.mediumImpact();
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

  void _resetDocumentView(LegacyDocument doc) {
    pageIndex = 0;
    showEnhanced = doc.pages.first.enhancementApplied;
    selectedId = doc.fields.where((f) => f.needsReview).firstOrNull?.id ??
        doc.fields.firstOrNull?.id;
    reviewOnlyPending = doc.needsReview > 0;
    showAllFields = false;
    selectedDrawing = null;
    drawingMode = 1;
    reviewView = _ReviewView.document;
  }

  void _closeDocument() {
    HapticFeedback.lightImpact();
    setState(() {
      document = null;
      justImported = false;
      note = null;
      pageIndex = 0;
      selectedId = null;
      tab = _Tab.home;
    });
  }

  Future<void> export(String format) async {
    final current = document;
    if (current == null || busy) return;
    HapticFeedback.lightImpact();
    if (kIsWeb) {
      _toast('${format.toUpperCase()} preview is ready below. Copy it for the browser demo.');
      return;
    }
    try {
      await pipeline.export(current, format);
      if (mounted) {
        _toast('${format.toUpperCase()} prepared. Choose a save location.');
      }
    } on PlatformException catch (e) {
      if (mounted) setState(() => error = e.message ?? 'Export failed.');
    }
  }

  Future<void> exportSummaryPdf() async {
    final current = document;
    if (current == null || busy) return;
    HapticFeedback.lightImpact();
    if (kIsWeb) {
      _toast('Summary PDF export is available in the native iPhone app.');
      return;
    }
    try {
      await pipeline.exportSummaryPdf(current);
      if (mounted) _toast('Summary PDF prepared. Choose a save location.');
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => error = e.message ?? 'Summary PDF export failed.');
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Could not generate summary PDF: $e');
    }
  }

  Future<void> calibrateCad() async {
    final doc = document;
    if (doc == null) return;
    final objects = doc.pages.expand((page) => page.drawingObjects).toList();
    if (objects.isEmpty) return;
    var selected = selectedDrawing != null &&
            selectedDrawing! < doc.pages[pageIndex].drawingObjects.length
        ? doc.pages[pageIndex].drawingObjects[selectedDrawing!]
        : objects.first;
    var unit = doc.cadUnit == 'unit' ? 'mm' : doc.cadUnit;
    final widthController = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Calibrate drawing scale'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select one reference object and enter its known width. '
                'All DXF coordinates use this reviewed scale.',
                style: Pz.meta.copyWith(color: Pz.graphite),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<DrawingObject>(
                initialValue: selected,
                decoration:
                    const InputDecoration(labelText: 'Reference object'),
                items: [
                  for (var i = 0; i < objects.length; i++)
                    DropdownMenuItem(
                      value: objects[i],
                      child: Text(
                          '${drawingObjectTag(objects[i], i)} · ${objects[i].kind}',
                          style: Pz.value),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => selected = value);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widthController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: Pz.value,
                      decoration:
                          const InputDecoration(labelText: 'Known width'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: unit,
                    underline: const SizedBox(),
                    items: [
                      for (final u in const ['mm', 'cm', 'm', 'in', 'ft'])
                        DropdownMenuItem(value: u, child: Text(u)),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => unit = value);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Apply scale'),
            ),
          ],
        ),
      ),
    );
    final knownWidth = double.tryParse(widthController.text.trim());
    widthController.dispose();
    if (!mounted || accepted != true || knownWidth == null || knownWidth <= 0) {
      return;
    }
    setState(() {
      doc.calibrateCad(object: selected, knownWidth: knownWidth, unit: unit);
    });
    persistedSessionCount = await checkpointStore.save(doc);
    if (mounted) _toast('Scale calibrated in $unit.');
  }

  void decide(LegacyField field, FieldStatus status, String? value,
      {bool autoAdvance = true}) {
    HapticFeedback.selectionClick();
    setState(() {
      document!.decide(field.id, status, value);
      if (autoAdvance) {
        final pending = document!.fields.where((f) => f.needsReview).toList();
        if (pending.isNotEmpty) {
          final nextIndex = pending.indexWhere((f) => f.id != field.id);
          selectedId =
              nextIndex >= 0 ? pending[nextIndex].id : pending.first.id;
        } else {
          selectedId = field.id;
          reviewOnlyPending = false;
        }
      }
    });
    unawaited(_saveCheckpoint(document!));
  }

  Future<void> _saveCheckpoint(LegacyDocument doc) async {
    unawaited(_indexDocument(doc));
    try {
      final value = await checkpointStore.save(doc);
      final entries = await checkpointStore.list();
      if (mounted) {
        setState(() {
          persistedSessionCount = value;
          history = entries;
        });
      }
    } catch (saveError) {
      debugPrint('Paperazzi checkpoint skipped: $saveError');
    }
  }

  Future<void> _clearArchive() async {
    await checkpointStore.clear();
    if (mounted) {
      setState(() {
        history = const [];
        persistedSessionCount = 0;
      });
    }
  }

  Future<void> _openHistory(SessionCheckpoint checkpoint) async {
    if (!checkpoint.canReopen || busy) return;
    setState(() {
      busy = true;
      error = null;
      stage = 'Reopening ${checkpoint.source}';
    });
    try {
      final result = await pipeline.importAndProcess(
        savedPath: checkpoint.sourcePath,
        useAi: false,
        onStage: (value) {
          if (mounted) setState(() => stage = value);
        },
      );
      if (!mounted || result == null) return;
      setState(() {
        document = result.document;
        note = result.note;
        justImported = false;
        _resetDocumentView(result.document);
        tab = _Tab.review;
      });
      await _saveCheckpoint(result.document);
    } catch (historyError) {
      if (mounted) setState(() => error = 'Could not reopen this document.');
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          stage = '';
        });
      }
    }
  }

  Future<void> _deleteHistory(SessionCheckpoint checkpoint) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete saved archive?'),
        content: Text(
          '${_title(checkpoint.source)} will be removed from Archive. '
          'Its retained local source copy will also be deleted from this device.',
          style: Pz.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Pz.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await pipeline.deleteSavedSource(checkpoint.sourcePath);
    } catch (_) {
      // Best-effort cleanup of retained local source file
    }

    try {
      final count = await checkpointStore.delete(checkpoint);
      final entries = await checkpointStore.list();
      if (!mounted) return;
      final deletingOpenDocument =
          document?.sourcePath == checkpoint.sourcePath ||
              (document?.name == checkpoint.source &&
                  checkpoint.sourcePath == null);
      setState(() {
        persistedSessionCount = count;
        history = entries;
        error = null;
        if (deletingOpenDocument) {
          document = null;
          selectedId = null;
          justImported = false;
          note = null;
        }
      });
      _toast('Archive deleted from this device.');
    } catch (deleteError) {
      if (mounted) {
        setState(() => error = 'Could not delete the saved archive.');
      }
    }
  }

  Future<void> edit(LegacyField field) async {
    HapticFeedback.lightImpact();
    final value = await showDialog<String>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => _ControllerScope(
        initialText: _displayValue(field) ?? '',
        builder: (controller) {
          String? validationError;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              void save() {
                final edited = controller.text.trim();
                if (edited.isEmpty) {
                  setDialogState(
                      () => validationError = 'Enter a verified value.');
                  return;
                }
                Navigator.of(dialogContext).pop(edited);
              }

              return AlertDialog(
                title: const Text('Edit verified value'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PzLabel(_fieldLabel(field.name), color: Pz.blue),
                      if (field.ocrValue != null) ...[
                        const SizedBox(height: 12),
                        Text('Source OCR', style: Pz.meta),
                        const SizedBox(height: 3),
                        Text(field.ocrValue!, style: Pz.value),
                      ],
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => save(),
                        onChanged: (_) {
                          if (validationError != null) {
                            setDialogState(() => validationError = null);
                          }
                        },
                        style: Pz.value.copyWith(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Verified value',
                          errorText: validationError,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton.icon(
                    onPressed: save,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: const Text('Save revision'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
    final doc = document;
    if (value != null && value.isNotEmpty && mounted && doc != null) {
      setState(() {
        doc.decide(field.id, FieldStatus.edited, value);
        reviewOnlyPending = false;
        selectedId = field.id;
      });
      await _saveCheckpoint(doc);
      if (!mounted) return;
      _toast('Revision saved and added to the audit trail.');
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    _toast('$label copied.');
  }

  Future<void> openCloudSettings() async {
    HapticFeedback.lightImpact();
    var selectedModel = widget.connection.activeModel;
    if (selectedModel != 'gemini-2.5-flash' &&
        selectedModel != 'gemini-2.5-pro') {
      selectedModel = 'gemini-2.5-flash';
    }
    var testing = false;
    String? pingResult;
    var pingOk = widget.connection.ready;

    Future<int> connect(TextEditingController keyController) async {
      await widget.connection.connect();
      await widget.connection.setCustomApiKey(keyController.text);
      await widget.connection.setActiveModel(selectedModel);
      return widget.connection.pingConnection();
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ControllerScope(
        initialText: widget.connection.customApiKey,
        builder: (keyController) => StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.fromLTRB(Pz.gutter, 20, Pz.gutter,
                MediaQuery.viewInsetsOf(sheetContext).bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PzLabel('Optional · Gemini', color: Pz.blue),
                const SizedBox(height: 6),
                const Text('Cloud extraction', style: Pz.sectionTitle),
                const SizedBox(height: 4),
                Text(
                    'Sends the page image and OCR lines to the configured Gemini '
                    'model. Use only for sources you are permitted to share.',
                    style: Pz.meta),
                const SizedBox(height: 14),
                PzPanel(
                  padding: EdgeInsets.zero,
                  child: PzDataRow(
                    label: 'Connection',
                    value: pingResult ?? widget.connection.status,
                    indicator: pingOk ? Pz.verified : Pz.review,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: keyController,
                  obscureText: true,
                  style: Pz.value,
                  decoration: InputDecoration(
                    labelText: 'Gemini API key (this session only)',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste_outlined,
                          size: 18, color: Pz.blue),
                      tooltip: 'Paste',
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null) {
                          keyController.text = data!.text!.trim();
                          setModalState(() {});
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedModel,
                  decoration: const InputDecoration(labelText: 'Model'),
                  style: Pz.value,
                  items: const [
                    DropdownMenuItem(
                        value: 'gemini-2.5-flash',
                        child: Text('Gemini 2.5 Flash · faster')),
                    DropdownMenuItem(
                        value: 'gemini-2.5-pro',
                        child: Text('Gemini 2.5 Pro · higher quality')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedModel = val);
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: PzSecondaryButton(
                        label: testing ? 'Testing…' : 'Test connection',
                        icon: Icons.sync_alt,
                        onPressed: testing
                            ? null
                            : () async {
                                setModalState(() => testing = true);
                                try {
                                  final latency = await connect(keyController);
                                  setModalState(() {
                                    pingOk = true;
                                    pingResult =
                                        'Connected · ${latency}ms · $selectedModel';
                                  });
                                } catch (e) {
                                  setModalState(() {
                                    pingOk = false;
                                    pingResult = 'Test failed: $e';
                                  });
                                } finally {
                                  setModalState(() => testing = false);
                                }
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PzPrimaryButton(
                        label: 'Save & enable',
                        height: 44,
                        onPressed: testing
                            ? null
                            : () async {
                                setModalState(() => testing = true);
                                try {
                                  final latency = await connect(keyController);
                                  if (!mounted) return;
                                  setState(() => allowCloudAi = true);
                                  debugPrint(
                                      'Gemini connection verified in ${latency}ms');
                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                } catch (e) {
                                  setModalState(() {
                                    testing = false;
                                    pingOk = false;
                                    pingResult = 'Connection failed: $e';
                                  });
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = document?.needsReview ?? 0;
    final body = switch (tab) {
      _Tab.home => _homeView(),
      _Tab.scan => _scanView(),
      _Tab.archive => _archiveView(),
      _Tab.review => _reviewView(),
    };
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: Pz.bg,
        body: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position:
                        Tween(begin: const Offset(0, .01), end: Offset.zero)
                            .animate(animation),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey('${tab.name}-${reviewView.name}'),
                  child: body,
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: PzBottomNav(
          index: tab.index,
          onTap: (i) => _go(_Tab.values[i]),
          items: [
            const PzNavItem('Home', Icons.space_dashboard_outlined),
            const PzNavItem('Scan', Icons.document_scanner_outlined),
            const PzNavItem('Archive', Icons.inventory_2_outlined),
            PzNavItem('Review', Icons.fact_check_outlined, badge: pending),
          ],
        ),
      ),
    );
  }

  // ---- Shared helpers ------------------------------------------------------

  static String _fieldLabel(String name) =>
      name.replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

  static String? _displayValue(LegacyField field) =>
      field.finalValue ??
      field.suggestedValue ??
      field.aiValue ??
      field.ocrValue;

  static PzStatus _statusOf(LegacyField field) => field.needsReview
      ? PzStatus.review
      : switch (field.status) {
          FieldStatus.accepted => PzStatus.verified,
          FieldStatus.edited => PzStatus.edited,
          FieldStatus.unreadable => PzStatus.unreadable,
          _ => PzStatus.ready,
        };

  static String _pad(int value, [int width = 2]) =>
      value.toString().padLeft(width, '0');

  /// Drawing-sheet style zone for a normalized box: rows A–F top to bottom,
  /// columns 1–4 left to right.
  static String? _zoneOf(List<double> box) {
    if (box.length < 4) return null;
    final cx = (box[0] + box[2] / 2).clamp(0.0, .999);
    final cy = (box[1] + box[3] / 2).clamp(0.0, .999);
    return '${'ABCDEF'[(cy * 6).floor()]}${(cx * 4).floor() + 1}';
  }

  /// The OCR line that backs a field, with the same match fallback the
  /// verification view has always used for unlinked fields.
  static (LegacyPage?, OcrLine?, int) _sourceFor(
      LegacyDocument doc, LegacyField field) {
    final page = doc.pages.where((p) => p.number == field.page).firstOrNull;
    if (page == null) return (null, null, -1);
    if (field.lineIndex >= 0 && field.lineIndex < page.lines.length) {
      final line = page.lines[field.lineIndex];
      if (line.crop != null && line.crop!.isNotEmpty) {
        return (page, line, field.lineIndex);
      }
    }
    final query = (_displayValue(field) ?? field.name)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (query.isNotEmpty) {
      for (var i = 0; i < page.lines.length; i++) {
        final candidate = page.lines[i];
        final normalized =
            candidate.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        if (candidate.crop != null &&
            candidate.crop!.isNotEmpty &&
            (normalized.contains(query) ||
                (query.length > 4 && query.contains(normalized)))) {
          return (page, candidate, i);
        }
      }
    }
    if (field.lineIndex >= 0 && field.lineIndex < page.lines.length) {
      return (page, page.lines[field.lineIndex], field.lineIndex);
    }
    return (page, null, -1);
  }

  static int _editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var previous = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final current = List<int>.filled(b.length + 1, 0)..[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        current[j] = [
          previous[j] + 1,
          current[j - 1] + 1,
          previous[j - 1] + cost,
        ].reduce((x, y) => x < y ? x : y);
      }
      previous = current;
    }
    return previous[b.length];
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    return hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';
  }

  static String _date(DateTime value) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${_pad(value.day)} ${months[value.month - 1]} ${value.year}';
  }

  static String _title(String filename) => filename
      .replaceAll(RegExp(r'\.[^.]+$'), '')
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .trim();

  Widget _messages() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (busy && tab != _Tab.scan)
            PzNotice(stage.isEmpty ? 'Processing document' : stage,
                color: Pz.blue, loading: true),
          if (error != null)
            PzNotice(error!, color: Pz.error, icon: Icons.error_outline),
        ],
      );

  Widget _emptyReview(String title, String message) => ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          PzTopBar(overline: 'Review', title: title),
          Padding(
            padding: const EdgeInsets.fromLTRB(Pz.gutter, 24, Pz.gutter, 0),
            child: PzPanel(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PzDocThumb(
                      width: 40, height: 50, icon: Icons.fact_check_outlined),
                  const SizedBox(height: 16),
                  Text(message, style: Pz.body),
                  const SizedBox(height: 16),
                  PzPrimaryButton(
                    label: 'Scan document',
                    icon: Icons.document_scanner_outlined,
                    onPressed: () => _go(_Tab.scan),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
}

/// Owns a text controller for a modal route and disposes it only after the
/// route has finished closing.
class _ControllerScope extends StatefulWidget {
  const _ControllerScope({required this.initialText, required this.builder});
  final String initialText;
  final Widget Function(TextEditingController controller) builder;

  @override
  State<_ControllerScope> createState() => _ControllerScopeState();
}

class _ControllerScopeState extends State<_ControllerScope> {
  late final controller = TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(controller);
}
