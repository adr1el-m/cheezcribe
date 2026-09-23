import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/ai_service.dart';
import 'legacy_models.dart';
import 'legacy_pipeline.dart';
import 'session_checkpoint_store.dart';

// Paperazzi's detection palette. Each color has one consistent meaning across
// the source preview, understanding summary, review queue, and export views.
const brandBlue = Color(0xFF0878F9);
const brandNavy = Color(0xFF092A6A);
const brandIndigo = Color(0xFF7C3AED);
const emeraldGreen = Color(0xFF08AA9A);
const amberWarning = Color(0xFFF59E0B);
const roseDanger = Color(0xFFE95A67);

class PaperazziMark extends StatelessWidget {
  const PaperazziMark({super.key, this.size = 42});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * .22),
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            'assets/icons/paperazzi.png',
            alignment: Alignment.topCenter,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          ),
        ),
      );
}

class SolidSvgIcon extends StatelessWidget {
  const SolidSvgIcon(this.name, {super.key, this.size = 20, this.color});
  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/icons/$name.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(
          color ?? IconTheme.of(context).color ?? const Color(0xFF263238),
          BlendMode.srcIn,
        ),
      );
}

/// Solid, bordered surface used for primary workflow groups.
class LiquidGlassBox extends StatelessWidget {
  const LiquidGlassBox({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.isDark = false,
    this.borderWidth = 1.0,
    this.customBorderColor,
    this.customBgColor,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final bool isDark;
  final double borderWidth;
  final Color? customBorderColor;
  final Color? customBgColor;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        customBgColor ?? (isDark ? const Color(0xFF0D2245) : Colors.white);

    final borderColor = customBorderColor ??
        (isDark ? const Color(0xFF183968) : const Color(0xFFD7E8FC));

    return Container(
      margin: margin,
      decoration:
          BoxDecoration(borderRadius: BorderRadius.circular(borderRadius)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor, width: borderWidth),
          ),
          child: child,
        ),
      ),
    );
  }
}

class PaperazziApp extends StatefulWidget {
  const PaperazziApp({super.key, required this.connection});
  final AiService connection;
  @override
  State<PaperazziApp> createState() => _PaperazziAppState();
}

class _PaperazziAppState extends State<PaperazziApp> {
  final ThemeMode _themeMode = ThemeMode.light;

  bool get isDark =>
      _themeMode == ThemeMode.dark ||
      (_themeMode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark);

  Color get canvasBg =>
      isDark ? const Color(0xFF07162F) : const Color(0xFFF4F9FF);
  Color get cardBg => isDark ? const Color(0xFF0D2245) : Colors.white;
  Color get textPrimary => isDark ? const Color(0xFFF6FAFF) : brandNavy;
  Color get textSecondary =>
      isDark ? const Color(0xFFB7C9E8) : const Color(0xFF58749F);
  Color get textMuted =>
      isDark ? const Color(0xFF7E9BC6) : const Color(0xFF7F98BC);
  Color get borderLight =>
      isDark ? const Color(0xFF183968) : const Color(0xFFD7E8FC);
  Color get borderSubtle =>
      isDark ? const Color(0xFF14315A) : const Color(0xFFE8F2FD);
  Color get brandBlue =>
      isDark ? const Color(0xFF55A8FF) : const Color(0xFF0878F9);
  Color get brandIndigo =>
      isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
  Color get emeraldGreen =>
      isDark ? const Color(0xFF4CD9CC) : const Color(0xFF08AA9A);
  Color get amberWarning =>
      isDark ? const Color(0xFFFCC86A) : const Color(0xFFF59E0B);
  Color get roseDanger =>
      isDark ? const Color(0xFFFF8C96) : const Color(0xFFE95A67);
  late final pipeline = LegacyPipeline(widget.connection);
  final checkpointStore = SessionCheckpointStore();
  LegacyDocument? document;
  String? note;
  String? error;
  String stage = '';
  bool busy = false;
  bool allowCloudAi = false;
  int tab = 0;
  int pageIndex = 0;
  String? selectedId;
  bool showBoundingBoxes = true;
  bool showEnhanced = false;
  bool showDrawingGeometry = false;
  String previewFormat = 'json';
  String detectionFilter = 'All';
  bool reviewOnlyPending = true;
  String searchQuery = '';
  int persistedSessionCount = 0;
  List<SessionCheckpoint> history = const [];

  bool get supportsImport =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  bool get supportsCameraScan =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  String get ocrEngineName => defaultTargetPlatform == TargetPlatform.android
      ? 'ML Kit'
      : 'Apple Vision';

  @override
  void initState() {
    super.initState();
    checkpointStore.count().then((value) {
      if (mounted) setState(() => persistedSessionCount = value);
    });
    _reloadHistory();
  }

  Future<void> _reloadHistory() async {
    final entries = await checkpointStore.list();
    if (mounted) setState(() => history = entries);
  }

  Future<void> import({bool sample = false, bool camera = false}) async {
    if (busy || !supportsImport) return;
    HapticFeedback.lightImpact();
    setState(() {
      busy = true;
      error = null;
      note = null;
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
                'Cloud AI bypassed, falling back to on-device engine: $value');
          });
      if (!mounted || result == null) return;
      setState(() {
        document = result.document;
        note = sample
            ? 'Bundled 1915 evaluation sample. ${result.note}'
            : result.note;
        pageIndex = 0;
        showEnhanced = result.document.pages.first.enhancementApplied;
        selectedId = result.document.fields
                .where((f) => f.needsReview)
                .firstOrNull
                ?.id ??
            result.document.fields.firstOrNull?.id;
        tab = 0;
      });
      persistedSessionCount = await checkpointStore.save(result.document);
      await _reloadHistory();
      if (mounted) setState(() {});
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

  Future<void> export(String format) async {
    final current = document;
    if (current == null || busy) return;
    HapticFeedback.lightImpact();
    try {
      await pipeline.export(current, format);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: textPrimary,
          content: Text(
              '${format.toUpperCase()} export prepared. Choose a save location.',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ));
      }
    } on PlatformException catch (e) {
      if (mounted) setState(() => error = e.message ?? 'Export failed.');
    }
  }

  Future<void> exportSummaryPdf() async {
    final current = document;
    if (current == null || busy) return;
    HapticFeedback.lightImpact();
    try {
      await pipeline.exportSummaryPdf(current);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: textPrimary,
          content: const Text(
              'Executive Summary PDF prepared. Choose a save location.',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ));
      }
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
    var selected = objects.first;
    var unit = doc.cadUnit == 'unit' ? 'mm' : doc.cadUnit;
    final widthController = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Calibrate CAD scale'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose one detected object and enter its known real-world width. All DXF coordinates will use this reviewed scale.',
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<DrawingObject>(
                initialValue: selected,
                decoration:
                    const InputDecoration(labelText: 'Reference object'),
                items: [
                  for (var i = 0; i < objects.length; i++)
                    DropdownMenuItem(
                      value: objects[i],
                      child: Text('${objects[i].kind} #${i + 1}'),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => selected = value);
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widthController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Known width'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: unit,
                    items: const [
                      DropdownMenuItem(value: 'mm', child: Text('mm')),
                      DropdownMenuItem(value: 'cm', child: Text('cm')),
                      DropdownMenuItem(value: 'm', child: Text('m')),
                      DropdownMenuItem(value: 'in', child: Text('in')),
                      DropdownMenuItem(value: 'ft', child: Text('ft')),
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
              child: const Text('Apply reviewed scale'),
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
    if (mounted) setState(() {});
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
        }
      }
    });
    unawaited(_saveCheckpoint(document!));
  }

  Future<void> _saveCheckpoint(LegacyDocument doc) async {
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
        pageIndex = 0;
        selectedId = result.document.fields.firstOrNull?.id;
        tab = 0;
      });
      await _saveCheckpoint(result.document);
    } catch (historyError) {
      if (mounted) setState(() => error = 'Could not reopen this document.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> edit(LegacyField field) async {
    HapticFeedback.lightImpact();
    final controller = TextEditingController(
        text: field.finalValue ??
            field.suggestedValue ??
            field.aiValue ??
            field.ocrValue ??
            '');
    final value = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20,
                  MediaQuery.viewInsetsOf(sheetContext).bottom + 20),
              child: Material(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.edit_note_rounded,
                            color: brandBlue, size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Edit ${field.name}',
                              style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18)),
                        ),
                      ]),
                      const SizedBox(height: 18),
                      Text('Enter verified value based on source evidence:',
                          style: TextStyle(color: textSecondary, fontSize: 13)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: controller,
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (value) =>
                              Navigator.pop(context, value.trim()),
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: textPrimary),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: canvasBg,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: borderLight)),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide:
                                    BorderSide(color: brandBlue, width: 2)),
                            labelText: 'Verified value',
                            labelStyle: TextStyle(color: textSecondary),
                          )),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              child: Text('Cancel',
                                  style: TextStyle(color: textSecondary))),
                          const SizedBox(width: 8),
                          FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: brandBlue,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.pop(
                                  sheetContext, controller.text.trim()),
                              child: const Text('Save Correction')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ));
    controller.dispose();
    if (value != null && value.isNotEmpty && mounted) {
      decide(field, FieldStatus.edited, value, autoAdvance: false);
      setState(() {
        reviewOnlyPending = false;
        selectedId = field.id;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Verified value saved.'),
      ));
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: textPrimary,
      content: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: emeraldGreen, size: 20),
          const SizedBox(width: 8),
          Text('$label copied to clipboard',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    ));
  }

  Future<void> openAiSettings() async {
    HapticFeedback.lightImpact();
    final keyController =
        TextEditingController(text: widget.connection.customApiKey);
    var selectedModel = widget.connection.activeModel;
    if (selectedModel != 'gemini-2.5-flash' &&
        selectedModel != 'gemini-2.5-pro') {
      selectedModel = 'gemini-2.5-flash';
    }
    var testing = false;
    String? pingResult;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: brandBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.psychology_rounded,
                        color: brandBlue, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Gemini AI Engine Settings',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: textPrimary)),
                        Text('Optional cloud AI for Android and other devices',
                            style:
                                TextStyle(fontSize: 12, color: textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Status Badge
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.connection.ready
                      ? emeraldGreen.withValues(alpha: 0.08)
                      : amberWarning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.connection.ready
                        ? emeraldGreen.withValues(alpha: 0.3)
                        : amberWarning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.connection.ready
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      color:
                          widget.connection.ready ? emeraldGreen : amberWarning,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        pingResult ?? widget.connection.status,
                        style: TextStyle(
                          color: widget.connection.ready
                              ? emeraldGreen
                              : amberWarning,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Google Gemini API Key (this session only)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textPrimary)),
              const SizedBox(height: 6),
              TextField(
                controller: keyController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Paste Gemini API Key (e.g. AIzaSy...)',
                  hintStyle: TextStyle(color: textMuted, fontSize: 13),
                  filled: true,
                  fillColor: canvasBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderLight),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.content_paste_rounded,
                        size: 20, color: brandBlue),
                    tooltip: 'Paste from clipboard',
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
              Text('Multimodal AI Model',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textPrimary)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: canvasBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderLight),
                ),
                child: DropdownButton<String>(
                  value: selectedModel,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(
                      value: 'gemini-2.5-flash',
                      child: Text('Gemini 2.5 Flash (Fast)'),
                    ),
                    DropdownMenuItem(
                      value: 'gemini-2.5-pro',
                      child: Text('Gemini 2.5 Pro (Higher quality)'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => selectedModel = val);
                    }
                  },
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: testing
                          ? null
                          : () async {
                              setModalState(() => testing = true);
                              try {
                                await widget.connection.connect();
                                await widget.connection
                                    .setCustomApiKey(keyController.text);
                                await widget.connection
                                    .setActiveModel(selectedModel);
                                final latency =
                                    await widget.connection.pingConnection();
                                setModalState(() {
                                  pingResult =
                                      'Connected! Latency: ${latency}ms • $selectedModel';
                                  testing = false;
                                });
                                HapticFeedback.mediumImpact();
                              } catch (e) {
                                setModalState(() {
                                  pingResult = 'Connection test failed: $e';
                                  testing = false;
                                });
                              }
                            },
                      icon: testing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_ping_rounded, size: 18),
                      label: const Text('Ping Connection'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: brandBlue),
                      onPressed: testing
                          ? null
                          : () async {
                              setModalState(() => testing = true);
                              try {
                                await widget.connection.connect();
                                await widget.connection
                                    .setCustomApiKey(keyController.text);
                                await widget.connection
                                    .setActiveModel(selectedModel);
                                final latency =
                                    await widget.connection.pingConnection();
                                if (!mounted) return;
                                setState(() => allowCloudAi = true);
                                HapticFeedback.mediumImpact();
                                if (sheetContext.mounted) {
                                  Navigator.of(sheetContext).pop();
                                }
                                debugPrint(
                                    'Gemini connection verified in ${latency}ms');
                              } catch (e) {
                                setModalState(() {
                                  testing = false;
                                  pingResult = 'Connection failed: $e';
                                });
                              }
                            },
                      child: const Text('Save & Connect'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    keyController.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Paperazzi',
        debugShowCheckedModeBanner: false,
        themeMode: _themeMode,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF4F9FF),
          colorScheme: ColorScheme.fromSeed(
            seedColor: brandBlue,
            surface: Colors.white,
            brightness: Brightness.light,
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: brandNavy, letterSpacing: -0.1),
            titleLarge:
                TextStyle(color: brandNavy, fontWeight: FontWeight.w700),
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFFD7E8FC), width: 1),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFFF4F9FF),
            elevation: 0,
            foregroundColor: brandNavy,
            centerTitle: false,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: brandBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: brandNavy,
              side: const BorderSide(color: Color(0xFFBFD9FB), width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF090E17),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF88A595),
            surface: const Color(0xFF090E17),
            brightness: Brightness.dark,
          ),
          textTheme: const TextTheme(
            bodyMedium:
                TextStyle(color: Color(0xFFF8FAFC), letterSpacing: -0.1),
            titleLarge: TextStyle(
                color: Color(0xFFF8FAFC), fontWeight: FontWeight.w700),
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF121B2A),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: Color(0xFF1E293B), width: 1),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF090E17),
            elevation: 0,
            foregroundColor: Color(0xFFF8FAFC),
            centerTitle: false,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6F8E7E),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFF8FAFC),
              side: const BorderSide(color: Color(0xFF1E293B), width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ),
        home: LayoutBuilder(builder: (context, size) {
          final wide = size.maxWidth >= 850;
          final pendingCount = document?.needsReview ?? 0;

          return Scaffold(
            backgroundColor: canvasBg,
            body: SafeArea(
              child: Row(
                children: [
                  if (wide)
                    NavigationRail(
                      backgroundColor: cardBg,
                      selectedIndex: tab,
                      onDestinationSelected: (v) {
                        HapticFeedback.selectionClick();
                        setState(() => tab = v);
                      },
                      labelType: NavigationRailLabelType.all,
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: const PaperazziMark(size: 44),
                      ),
                      destinations: [
                        NavigationRailDestination(
                          icon: const SolidSvgIcon('archive'),
                          selectedIcon:
                              SolidSvgIcon('archive', color: brandBlue),
                          label: const Text('Home'),
                        ),
                        NavigationRailDestination(
                          icon: Badge(
                            isLabelVisible: pendingCount > 0,
                            label: Text('$pendingCount'),
                            backgroundColor: amberWarning,
                            child: const SolidSvgIcon('review'),
                          ),
                          selectedIcon: Badge(
                            isLabelVisible: pendingCount > 0,
                            label: Text('$pendingCount'),
                            backgroundColor: amberWarning,
                            child: SolidSvgIcon('review', color: brandBlue),
                          ),
                          label: const Text('Review'),
                        ),
                        NavigationRailDestination(
                          icon: const SolidSvgIcon('export'),
                          selectedIcon:
                              SolidSvgIcon('export', color: brandBlue),
                          label: const Text('Library'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1280),
                        child: switch (tab) {
                          1 => _review(wide: wide),
                          2 => _export(),
                          _ => _documents(wide: wide)
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: wide
                ? null
                : Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      border: Border(top: BorderSide(color: borderLight)),
                    ),
                    child: NavigationBar(
                      backgroundColor: cardBg,
                      indicatorColor: const Color(0xFFDDEEFF),
                      selectedIndex: tab,
                      onDestinationSelected: (v) {
                        HapticFeedback.selectionClick();
                        setState(() => tab = v);
                      },
                      destinations: [
                        NavigationDestination(
                          icon: SolidSvgIcon('archive', color: textSecondary),
                          selectedIcon:
                              SolidSvgIcon('archive', color: brandBlue),
                          label: 'Home',
                        ),
                        NavigationDestination(
                          icon: Badge(
                            isLabelVisible: pendingCount > 0,
                            label: Text('$pendingCount'),
                            backgroundColor: amberWarning,
                            child: SolidSvgIcon('review', color: textSecondary),
                          ),
                          selectedIcon: Badge(
                            isLabelVisible: pendingCount > 0,
                            label: Text('$pendingCount'),
                            backgroundColor: amberWarning,
                            child: SolidSvgIcon('review', color: brandBlue),
                          ),
                          label: 'Review',
                        ),
                        NavigationDestination(
                          icon: SolidSvgIcon('export', color: textSecondary),
                          selectedIcon:
                              SolidSvgIcon('export', color: brandBlue),
                          label: 'Library',
                        ),
                      ],
                    ),
                  ),
          );
        }),
      );

  Widget _documents({required bool wide}) => ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          Row(
            children: [
              const PaperazziMark(size: 42),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Paperazzi',
                    style: TextStyle(
                        color: textPrimary,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8)),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: brandBlue.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.shield_outlined, color: textPrimary, size: 21),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text('Turn your paper\ninto lasting knowledge.',
              style: TextStyle(
                  color: textPrimary,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                  height: 1.15)),
          const SizedBox(height: 10),
          Text(
              defaultTargetPlatform == TargetPlatform.iOS
                  ? 'Scan, understand, verify, and export with on-device Apple Vision intelligence.'
                  : 'Scan, understand, verify, and export with on-device OCR and optional cloud assistance.',
              style:
                  TextStyle(color: textSecondary, fontSize: 14, height: 1.45)),
          const SizedBox(height: 20),

          // Primary Actions Card (Camera Paper Scan + File Import) in Liquid Glass
          LiquidGlassBox(
            isDark: isDark,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: brandBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: supportsImport && !busy
                      ? () => import(camera: supportsCameraScan)
                      : null,
                  icon: const SolidSvgIcon('scan', size: 22),
                  label: Text(
                      supportsCameraScan
                          ? 'Scan Paper with Camera'
                          : 'Import image or PDF',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: supportsImport && !busy ? () => import() : null,
                  icon: const SolidSvgIcon('import', size: 18),
                  label: const Text('Import Image or PDF File'),
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: borderSubtle),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: emeraldGreen.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: emeraldGreen.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      SolidSvgIcon('scan', size: 20, color: emeraldGreen),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('On-device OCR active',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: textPrimary)),
                            Text(
                              defaultTargetPlatform == TargetPlatform.iOS
                                  ? 'Apple Vision OCR and local structuring run on-device with Apple silicon acceleration.'
                                  : '$ocrEngineName OCR and deterministic structuring stay on-device.',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: textSecondary,
                                  height: 1.2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Row(
                      children: [
                        SolidSvgIcon('ai', size: 18, color: brandBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Cloud assist',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                  fontSize: 13),
                              overflow: TextOverflow.ellipsis),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: openAiSettings,
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: Text('Settings',
                                style: TextStyle(
                                    color: brandBlue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2, left: 26),
                      child: Text(
                        allowCloudAi
                            ? 'Gemini verified and enabled for selected pages.'
                            : defaultTargetPlatform == TargetPlatform.iOS
                                ? 'Optional cloud fallback for other platforms; not used in the iPhone demo.'
                                : widget.connection.status,
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ),
                    value: allowCloudAi,
                    onChanged: (value) {
                      if (value && !widget.connection.ready) {
                        openAiSettings();
                      } else {
                        setState(() => allowCloudAi = value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          if (!supportsImport)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _notice(
                Icons.info_outline_rounded,
                'Native OCR runs on iOS and Android. Connect a phone or run a simulator to import a document.',
                color: amberWarning,
              ),
            ),

          if (busy)
            _notice(
              Icons.hourglass_top_rounded,
              stage.isEmpty ? 'Processing document...' : stage,
              color: brandBlue,
              loading: true,
            ),
          if (note != null)
            _notice(Icons.check_circle_outline_rounded, note!,
                color: emeraldGreen),
          if (error != null)
            _notice(Icons.error_outline_rounded, error!, color: roseDanger),

          const SizedBox(height: 20),

          if (document == null)
            _emptyState()
          else ...[
            _metrics(document!),
            const SizedBox(height: 14),
            _executiveBriefingCard(document!),
            const SizedBox(height: 14),
            _provenanceIntegrityGauge(document!),
            const SizedBox(height: 20),
            _workspace(document!, wide: wide),
          ],
        ],
      );

  Widget _executiveBriefingCard(LegacyDocument doc) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: brandBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SolidSvgIcon('archive', color: brandBlue, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EXECUTIVE ARCHIVAL DOSSIER',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: brandBlue,
                              letterSpacing: 1.1)),
                      Text('Purpose & Archival Significance',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPrimary)),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: exportSummaryPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label:
                      const Text('Summary PDF', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: canvasBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderLight),
              ),
              child: Text(
                doc.generateExecutiveAbstract(),
                style: TextStyle(
                    fontSize: 12.5, color: textSecondary, height: 1.5),
              ),
            ),
          ],
        ),
      );

  Widget _provenanceIntegrityGauge(LegacyDocument doc) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: emeraldGreen.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: emeraldGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.verified_user_rounded,
                  color: emeraldGreen, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${(doc.sourceLinkedRate * 100).toStringAsFixed(1)}% source-linked fields',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPrimary)),
                  Text(
                      'Linked fields retain OCR coordinates; conflicts and unsupported values remain in human review.',
                      style: TextStyle(fontSize: 11, color: textSecondary)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _emptyState() => Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: brandBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.document_scanner_outlined,
                  color: brandBlue, size: 32),
            ),
            const SizedBox(height: 18),
            Text('Start with one legacy source',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textPrimary)),
            const SizedBox(height: 6),
            Text(
              'Import a scanned document${supportsCameraScan ? ', scan with camera,' : ''} or test with the bundled 1915 public-works sample. '
              '${defaultTargetPlatform == TargetPlatform.iOS ? 'Apple Vision reads the page on-device, then Paperazzi structures it locally for this iPhone demo.' : '$ocrEngineName OCR extracts raw text on-device; cloud assistance remains optional.'} '
              'Every extracted value stays linked to its visible source.',
              style:
                  TextStyle(color: textSecondary, height: 1.45, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _stepPill(
                    '01',
                    defaultTargetPlatform == TargetPlatform.iOS
                        ? 'Apple Vision OCR'
                        : 'On-Device OCR'),
                _stepPill('02', 'Local Structuring'),
                _stepPill('03', 'Human Verification'),
                _stepPill('04', 'Asset Export'),
              ],
            ),
          ],
        ),
      );

  Widget _stepPill(String step, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: canvasBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(step,
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: brandBlue)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: textSecondary)),
          ],
        ),
      );

  Widget _metrics(LegacyDocument doc) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 600;
      final metrics = [
        _metricItem('${doc.pages.length}', 'source pages',
            Icons.description_outlined, brandBlue),
        _metricItem('${doc.fields.length}', 'extracted items',
            Icons.format_list_bulleted_rounded, brandIndigo),
        _metricItem('${doc.needsReview}', 'need review',
            Icons.rule_folder_rounded, amberWarning,
            highlight: doc.needsReview > 0),
        _metricItem('${doc.resolved}', 'resolved', Icons.verified_rounded,
            emeraldGreen),
      ];

      if (isMobile) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: metrics[0]),
                const SizedBox(width: 10),
                Expanded(child: metrics[1]),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: metrics[2]),
                const SizedBox(width: 10),
                Expanded(child: metrics[3]),
              ],
            ),
          ],
        );
      }

      return Row(
        children: [
          for (var i = 0; i < metrics.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: metrics[i]),
          ]
        ],
      );
    });
  }

  Widget _metricItem(String number, String label, IconData icon, Color color,
          {bool highlight = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: highlight ? color.withValues(alpha: 0.5) : borderLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(number,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: highlight ? color : textPrimary)),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _workspace(LegacyDocument doc, {required bool wide}) {
    final source = _sourcePanel(doc);
    final fields = _fieldsPanel(doc);
    return wide
        ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 6, child: source),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: fields),
          ])
        : Column(children: [source, const SizedBox(height: 16), fields]);
  }

  Widget _sourcePanel(LegacyDocument doc) {
    final page = doc.pages[pageIndex];
    return LiquidGlassBox(
      isDark: isDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.photo_library_outlined, color: brandBlue, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(doc.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        fontSize: 14)),
              ),
              if (doc.pages.length > 1) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: canvasBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderLight),
                  ),
                  child: DropdownButton<int>(
                    value: pageIndex,
                    underline: const SizedBox(),
                    isDense: true,
                    items: [
                      for (var i = 0; i < doc.pages.length; i++)
                        DropdownMenuItem(
                          value: i,
                          child: Text('Page ${i + 1} of ${doc.pages.length}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        )
                    ],
                    onChanged: (v) => setState(() {
                      pageIndex = v ?? 0;
                      showEnhanced = doc.pages[pageIndex].enhancementApplied;
                    }),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              IconButton(
                icon: Icon(Icons.close_rounded, size: 20, color: textSecondary),
                tooltip: 'Close and start new scan',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    document = null;
                    pageIndex = 0;
                    selectedId = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _detectionFilterChip('All'),
                _detectionFilterChip('Text'),
                _detectionFilterChip('Tables'),
                _detectionFilterChip('Handwriting'),
                _detectionFilterChip('Drawings'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Interactive zoomable document viewer with OCR overlay
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 480,
              width: double.infinity,
              color: isDark ? const Color(0xFF0C1322) : const Color(0xFF1E293B),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.memory(
                              showEnhanced && page.enhancedImage != null
                                  ? page.enhancedImage!
                                  : page.image,
                              fit: BoxFit.contain),
                          if (showBoundingBoxes &&
                              (detectionFilter == 'All' ||
                                  detectionFilter == 'Text' ||
                                  detectionFilter == 'Handwriting'))
                            Positioned.fill(
                              child: LayoutBuilder(
                                  builder: (context, constraints) {
                                return CustomPaint(
                                  painter: _BoundingBoxPainter(
                                    lines: page.lines,
                                    selectedLineIndex: _selectedLineIndex(doc),
                                  ),
                                );
                              }),
                            ),
                          if (showDrawingGeometry &&
                              (detectionFilter == 'All' ||
                                  detectionFilter == 'Drawings') &&
                              page.drawingObjects.isNotEmpty)
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _DrawingObjectPainter(
                                    objects: page.drawingObjects),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.pinch_rounded,
                              color: Colors.white70, size: 14),
                          const SizedBox(width: 6),
                          const Text('Pinch to zoom',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => setState(
                                () => showBoundingBoxes = !showBoundingBoxes),
                            child: Icon(
                              showBoundingBoxes
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              color: showBoundingBoxes
                                  ? emeraldGreen
                                  : Colors.white60,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Responsive control bar preventing overflow on mobile screens
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text('${page.lines.length} OCR lines on page ${pageIndex + 1}',
                  style: TextStyle(
                      color: textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (page.enhancedImage != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      onPressed: () =>
                          setState(() => showEnhanced = !showEnhanced),
                      icon: Icon(
                          showEnhanced
                              ? Icons.auto_fix_high_rounded
                              : Icons.photo_outlined,
                          size: 15),
                      label: Text(showEnhanced ? 'Enhanced' : 'Original',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  if (page.drawingObjects.isNotEmpty)
                    IconButton(
                      tooltip: 'Toggle detected drawing geometry',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(
                          () => showDrawingGeometry = !showDrawingGeometry),
                      icon: Icon(Icons.architecture_rounded,
                          color: showDrawingGeometry ? brandIndigo : textMuted,
                          size: 18),
                    ),
                ],
              ),
            ],
          ),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _statusChip(
              label: page.enhancementApplied
                  ? 'ENHANCED OCR SELECTED'
                  : 'ORIGINAL OCR SELECTED',
              color: page.enhancementApplied ? brandIndigo : textSecondary,
              icon: Icons.auto_fix_high_rounded,
            ),
            if (page.drawingObjects.isNotEmpty) ...[
              _statusChip(
                label: '${page.drawingObjects.length} CAD GEOMETRY OBJECTS',
                color: brandBlue,
                icon: Icons.architecture_rounded,
              ),
              InkWell(
                onTap: () => export('dxf'),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: brandBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: brandBlue.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.download_rounded, size: 14, color: brandBlue),
                      const SizedBox(width: 4),
                      Text('Export .DXF',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: brandBlue)),
                    ],
                  ),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 22),
          _aiUnderstanding(doc, page),
        ],
      ),
    );
  }

  Widget _detectionFilterChip(String label) {
    final selected = detectionFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        showCheckmark: false,
        label: Text(label),
        labelStyle: TextStyle(
          color: selected ? Colors.white : textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        selectedColor: brandBlue,
        backgroundColor: canvasBg,
        side: BorderSide(color: selected ? brandBlue : borderLight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        onSelected: (_) {
          HapticFeedback.selectionClick();
          setState(() => detectionFilter = label);
        },
      ),
    );
  }

  Widget _aiUnderstanding(LegacyDocument doc, LegacyPage page) {
    final recordGroups = doc.fields
        .where((field) => field.recordIndex > 0)
        .map((field) => field.recordIndex)
        .toSet()
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            defaultTargetPlatform == TargetPlatform.iOS
                ? 'On-Device Understanding'
                : 'Document Understanding',
            style: TextStyle(
                color: textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: canvasBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderSubtle),
          ),
          child: Column(
            children: [
              _understandingRow(
                  Icons.title_rounded,
                  'Text',
                  'Labels, paragraphs, and annotations',
                  page.lines.length,
                  brandBlue),
              _understandingRow(
                  Icons.table_chart_rounded,
                  'Tables',
                  'Structured rows and grouped records',
                  recordGroups,
                  emeraldGreen),
              _understandingRow(Icons.draw_rounded, 'Handwriting',
                  'Manual notes and signatures', 0, brandIndigo),
              _understandingRow(
                  Icons.architecture_rounded,
                  'Drawing objects',
                  'Diagrams, plans, and traced geometry',
                  page.drawingObjects.length,
                  brandIndigo,
                  last: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _understandingRow(IconData icon, String title, String description,
          int count, Color color,
          {bool last = false}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: borderSubtle)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(description,
                      style: TextStyle(color: textSecondary, fontSize: 11)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$count detected',
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );

  int? _selectedLineIndex(LegacyDocument doc) {
    if (selectedId == null) return null;
    final field = doc.fields.where((f) => f.id == selectedId).firstOrNull;
    if (field != null && field.page == pageIndex + 1 && field.lineIndex >= 0) {
      return field.lineIndex;
    }
    return null;
  }

  Widget _fieldsPanel(LegacyDocument doc) {
    final filtered = doc.fields.where((f) {
      if (searchQuery.isEmpty) return true;
      final query = searchQuery.toLowerCase();
      return f.name.toLowerCase().contains(query) ||
          (f.finalValue ?? f.suggestedValue ?? f.aiValue ?? f.ocrValue ?? '')
              .toLowerCase()
              .contains(query);
    }).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STRUCTURED EXTRACTION',
                        style: TextStyle(
                            color: brandBlue,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            fontSize: 10)),
                    const SizedBox(height: 4),
                    Text(doc.documentType,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textPrimary)),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: brandBlue.withValues(alpha: 0.1),
                  foregroundColor: brandBlue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () => setState(() => tab = 1),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Review', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Search input
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: canvasBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderLight),
            ),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val.trim()),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search fields, names, or values...',
                hintStyle: TextStyle(fontSize: 12, color: textMuted),
                prefixIcon:
                    Icon(Icons.search_rounded, size: 16, color: textSecondary),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 14),
                        onPressed: () => setState(() => searchQuery = ''),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 9),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: borderSubtle),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                    searchQuery.isEmpty
                        ? 'No text recognized. Try a clearer document.'
                        : 'No matching fields found for "$searchQuery"',
                    style: TextStyle(color: textSecondary)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length > 20 ? 20 : filtered.length,
              separatorBuilder: (context, _) =>
                  Divider(height: 1, color: borderSubtle),
              itemBuilder: (context, index) {
                final field = filtered[index];
                final isSelected = field.id == selectedId;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      selectedId = field.id;
                      pageIndex =
                          (field.page - 1).clamp(0, doc.pages.length - 1);
                      tab = 1;
                    });
                  },
                  child: Container(
                    color: isSelected
                        ? brandBlue.withValues(alpha: 0.05)
                        : Colors.transparent,
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(field.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary)),
                              const SizedBox(height: 2),
                              Text(
                                field.finalValue ??
                                    field.suggestedValue ??
                                    field.aiValue ??
                                    field.ocrValue ??
                                    'Unreadable',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: field.finalValue != null
                                      ? textPrimary
                                      : textSecondary,
                                  fontWeight: field.finalValue != null
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _fieldStatusBadge(field),
                      ],
                    ),
                  ),
                );
              },
            ),
          if (filtered.length > 20)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Text(
                    '+ ${filtered.length - 20} more items in Review queue',
                    style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _review({required bool wide}) {
    final doc = document;
    if (doc == null) {
      return _placeholder(
          'Review queue', 'Import a source to review extracted items.');
    }

    final fieldsToDisplay = reviewOnlyPending
        ? doc.fields.where((f) => f.needsReview).toList()
        : doc.fields;

    final selected = doc.fields.where((f) => f.id == selectedId).firstOrNull ??
        fieldsToDisplay.firstOrNull ??
        doc.fields.firstOrNull;

    final pendingCount = doc.needsReview;
    final totalCount = doc.fields.length;
    final resolvedCount = doc.resolved;
    final progress = totalCount > 0 ? (resolvedCount / totalCount) : 0.0;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        // Review Progress Header
        Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EVIDENCE BEFORE ACCEPTANCE',
                    style: TextStyle(
                        color: brandBlue,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        fontSize: 10)),
                const SizedBox(height: 4),
                Text('Review queue',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.8)),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: pendingCount > 0
                    ? amberWarning.withValues(alpha: 0.1)
                    : emeraldGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: pendingCount > 0
                        ? amberWarning.withValues(alpha: 0.3)
                        : emeraldGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    pendingCount > 0
                        ? Icons.pending_actions_rounded
                        : Icons.check_circle_rounded,
                    size: 16,
                    color: pendingCount > 0 ? amberWarning : emeraldGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    pendingCount > 0 ? '$pendingCount pending' : 'All resolved',
                    style: TextStyle(
                      color: pendingCount > 0 ? amberWarning : emeraldGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: borderLight,
            valueColor: AlwaysStoppedAnimation<Color>(
                progress == 1.0 ? emeraldGreen : brandBlue),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('$resolvedCount of $totalCount items verified',
                style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Text('${(progress * 100).round()}% ready for export',
                style: TextStyle(
                    fontSize: 12,
                    color: brandBlue,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 16),

        // Filter Strip (Pending vs All)
        Row(
          children: [
            FilterChip(
              selected: reviewOnlyPending,
              label: Text('Needs Review ($pendingCount)'),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: reviewOnlyPending ? brandBlue : textSecondary,
              ),
              selectedColor: brandBlue.withValues(alpha: 0.12),
              backgroundColor: cardBg,
              side: BorderSide(
                  color: reviewOnlyPending ? brandBlue : borderLight),
              onSelected: (val) {
                HapticFeedback.selectionClick();
                setState(() {
                  reviewOnlyPending = val;
                  if (reviewOnlyPending && (selected?.resolved ?? false)) {
                    selectedId =
                        doc.fields.where((f) => f.needsReview).firstOrNull?.id;
                  }
                });
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              selected: !reviewOnlyPending,
              label: Text('All Fields ($totalCount)'),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: !reviewOnlyPending ? brandBlue : textSecondary,
              ),
              selectedColor: brandBlue.withValues(alpha: 0.12),
              backgroundColor: cardBg,
              side: BorderSide(
                  color: !reviewOnlyPending ? brandBlue : borderLight),
              onSelected: (val) {
                HapticFeedback.selectionClick();
                setState(() => reviewOnlyPending = !val);
              },
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (selected == null)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderLight),
            ),
            child: Center(
              child: Text('No fields available in this queue.',
                  style: TextStyle(
                      color: textSecondary, fontWeight: FontWeight.w500)),
            ),
          )
        else
          wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                        width: 320, child: _reviewList(doc, fieldsToDisplay)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _reviewDetail(doc, selected, fieldsToDisplay)),
                  ],
                )
              : Column(
                  children: [
                    _reviewDetail(doc, selected, fieldsToDisplay),
                    const SizedBox(height: 18),
                    _reviewList(doc, fieldsToDisplay),
                  ],
                ),
      ],
    );
  }

  Widget _reviewList(LegacyDocument doc, List<LegacyField> fields) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Text('Field Roster',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: textPrimary)),
                  const Spacer(),
                  Text('${fields.length} items',
                      style: TextStyle(
                          fontSize: 12,
                          color: textSecondary,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: fields.length,
                separatorBuilder: (context, _) =>
                    Divider(height: 1, color: borderSubtle),
                itemBuilder: (context, index) {
                  final field = fields[index];
                  final isSelected = field.id == selectedId;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => selectedId = field.id);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? brandBlue.withValues(alpha: 0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 9),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(field.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      fontSize: 13,
                                      color:
                                          isSelected ? brandBlue : textPrimary,
                                    )),
                                Text(
                                  field.finalValue ??
                                      field.suggestedValue ??
                                      field.aiValue ??
                                      field.ocrValue ??
                                      '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11, color: textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _fieldStatusBadge(field, compact: true),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );

  Widget _reviewDetail(
      LegacyDocument doc, LegacyField field, List<LegacyField> currentQueue) {
    final page = doc.pages.where((p) => p.number == field.page).firstOrNull;
    var line = page != null &&
            field.lineIndex >= 0 &&
            field.lineIndex < page.lines.length
        ? page.lines[field.lineIndex]
        : null;

    // Smart fallback crop resolution: if unlinked or crop empty, search page lines for match
    if ((line == null || line.crop == null || line.crop!.isEmpty) &&
        page != null) {
      final query = (field.finalValue ??
              field.suggestedValue ??
              field.aiValue ??
              field.ocrValue ??
              field.name)
          .trim()
          .toLowerCase();
      if (query.isNotEmpty) {
        final normQ = query.replaceAll(RegExp(r'[^a-z0-9]'), '');
        for (final candidate in page.lines) {
          final normL =
              candidate.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          if (candidate.crop != null &&
              candidate.crop!.isNotEmpty &&
              (normL.contains(normQ) ||
                  (normQ.length > 4 && normQ.contains(normL)))) {
            line = candidate;
            break;
          }
        }
      }
    }

    final currentIndex = currentQueue.indexWhere((f) => f.id == field.id);
    final hasPrev = currentIndex > 0;
    final hasNext = currentIndex >= 0 && currentIndex < currentQueue.length - 1;

    return LiquidGlassBox(
      isDark: isDark,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Stepper Navigation & Field Title
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(field.name,
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 2),
                    Text(
                        'Page ${field.page} • OCR Line ${line != null ? (page!.lines.indexOf(line) + 1) : (field.lineIndex >= 0 ? field.lineIndex + 1 : 'unlinked')}',
                        style: TextStyle(
                            color: textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              _fieldStatusBadge(field),
            ],
          ),
          const SizedBox(height: 12),

          // Stepper Buttons (< Previous | Next >)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: canvasBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderLight),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: hasPrev
                      ? () {
                          HapticFeedback.selectionClick();
                          setState(() =>
                              selectedId = currentQueue[currentIndex - 1].id);
                        }
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Center(
                    child: Text(
                      currentIndex >= 0
                          ? 'Item ${currentIndex + 1} of ${currentQueue.length}'
                          : 'Field selected',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: hasNext
                      ? () {
                          HapticFeedback.selectionClick();
                          setState(() =>
                              selectedId = currentQueue[currentIndex + 1].id);
                        }
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // SOURCE CROP
          Row(
            children: [
              Text('SOURCE CROP',
                  style: TextStyle(
                      color: brandBlue,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      fontSize: 11)),
              const Spacer(),
              if (line != null)
                Text('Confidence: ${(line.confidence * 100).round()}%',
                    style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            constraints: const BoxConstraints(minHeight: 58, maxHeight: 92),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFDF8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: brandBlue.withValues(alpha: 0.25)),
            ),
            child: line?.crop != null && line!.crop!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(line.crop!, fit: BoxFit.contain),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(page!.image, fit: BoxFit.contain),
                  ),
          ),
          const SizedBox(height: 12),

          // Interactive Focus on Page Scan button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: const Size(0, 36),
            ),
            onPressed: () {
              setState(() {
                pageIndex = (field.page - 1).clamp(0, doc.pages.length - 1);
                showBoundingBoxes = true;
                showEnhanced = doc.pages[pageIndex].enhancementApplied;
                tab = 0;
              });
            },
            icon: Icon(Icons.crop_free_rounded, size: 16, color: brandBlue),
            label: Text('Focus on Page Scan',
                style: TextStyle(fontSize: 12, color: brandBlue)),
          ),

          const SizedBox(height: 16),

          // Evidence comparison cards
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: canvasBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderLight),
            ),
            child: Column(
              children: [
                _comparisonRow(
                  'OCR EXTRACTION',
                  field.ocrValue ?? 'No linked OCR text',
                  Icons.text_fields_rounded,
                  brandIndigo,
                ),
                Divider(height: 16, color: borderLight),
                _comparisonRow(
                  field.aiValue != null
                      ? 'OPTIONAL CLOUD SUGGESTION'
                      : 'APPLE ON-DEVICE INTERPRETATION',
                  field.aiValue ??
                      field.suggestedValue ??
                      'No supported interpretation found',
                  Icons.psychology_alt_rounded,
                  brandBlue,
                ),
                Divider(height: 16, color: borderLight),
                _comparisonRow(
                  'CURRENT VERIFIED VALUE',
                  field.finalValue ?? 'Awaiting human decision',
                  Icons.verified_rounded,
                  field.finalValue != null ? emeraldGreen : amberWarning,
                  isBold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Reasoning & Score Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: brandBlue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: brandBlue.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: brandBlue, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${field.reason} • Priority score ${(field.score * 100).round()}/100',
                    style: TextStyle(
                        fontSize: 12,
                        color: textPrimary,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: brandBlue,
                foregroundColor: Colors.white,
              ),
              onPressed: () async => edit(field),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit verified value'),
            ),
          ),
          const SizedBox(height: 8),

          // Tactile Action Dock (Accept, Keep OCR, Mark Unreadable)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: emeraldGreen,
                  foregroundColor: Colors.white,
                ),
                onPressed: (field.aiValue ?? field.suggestedValue) == null
                    ? null
                    : () => decide(field, FieldStatus.accepted,
                        field.aiValue ?? field.suggestedValue),
                icon: const Icon(Icons.check_rounded, size: 18),
                label: const Text('Accept suggestion'),
              ),
              OutlinedButton.icon(
                onPressed: field.ocrValue == null
                    ? null
                    : () => decide(field, FieldStatus.accepted, field.ocrValue),
                icon: const Icon(Icons.text_format_rounded, size: 18),
                label: const Text('Keep OCR'),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: roseDanger,
                ),
                onPressed: () => decide(field, FieldStatus.unreadable, null),
                child: const Text('Mark unreadable'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _comparisonRow(String label, String value, IconData icon, Color color,
          {bool isBold = false}) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: textSecondary,
                        letterSpacing: 0.8)),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: isBold ? textPrimary : textSecondary,
                    fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _export() {
    final doc = document;
    if (doc == null) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          _historyPanel(),
          const SizedBox(height: 18),
          _notice(Icons.upload_file_rounded,
              'Import and review a source before exporting.'),
        ],
      );
    }

    final jsonContent = doc.exportJson();
    final csvContent = doc.exportCsv();
    final recordsContent = doc.hasRecords ? doc.exportRecordsCsv() : null;

    final previewText = switch (previewFormat) {
      'csv' => csvContent,
      'records' => recordsContent ?? csvContent,
      _ => jsonContent,
    };

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      children: [
        _historyPanel(),
        const SizedBox(height: 18),
        Text('REUSABLE DIGITAL ASSET',
            style: TextStyle(
                color: brandBlue,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                fontSize: 10)),
        const SizedBox(height: 4),
        Text('Export with provenance.',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: textPrimary,
                letterSpacing: -0.8)),
        const SizedBox(height: 6),
        Text(
            'Exports include source references, original OCR text, on-device interpretations, optional cloud suggestions, human verification decisions, and line coordinate mappings.',
            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.45)),
        const SizedBox(height: 16),

        _metrics(doc),
        const SizedBox(height: 14),

        _notice(
          Icons.fact_check_outlined,
          '${(doc.meanOcrConfidence * 100).toStringAsFixed(1)}% mean OCR confidence • '
          '${doc.lowConfidenceLines} low-confidence lines • '
          '${(doc.sourceLinkedRate * 100).toStringAsFixed(1)}% fields linked to source. '
          'These are review indicators, not a claimed accuracy percentage.',
          color: brandIndigo,
        ),
        _notice(
          Icons.save_outlined,
          'Structured checkpoint saved on this device • '
          '$persistedSessionCount of ${SessionCheckpointStore.maxEntries} slots used. '
          'Imported source files are retained locally for reopening.',
          color: emeraldGreen,
        ),

        if (doc.needsReview > 0)
          _notice(
            Icons.warning_amber_rounded,
            '${doc.needsReview} fields remain unresolved. Their exported values are blank and marked requires_review.',
            color: amberWarning,
          ),

        const SizedBox(height: 16),

        // Executive Summary Dossier PDF Card in Liquid Glass
        LiquidGlassBox(
          isDark: isDark,
          borderRadius: 20,
          padding: const EdgeInsets.all(20),
          customBgColor:
              isDark ? const Color(0xFF222725) : const Color(0xFFF0EDE5),
          customBorderColor: borderLight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: brandBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SolidSvgIcon('archive', color: brandBlue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('EXECUTIVE ARCHIVAL DOSSIER (PDF)',
                            style: TextStyle(
                                color: brandBlue,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2)),
                        Text('Archival Briefing & Purpose',
                            style: TextStyle(
                                color: textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2B312E)
                      : const Color(0xFFFFFEFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : borderLight),
                ),
                child: Text(
                  doc.generateExecutiveAbstract(),
                  style: TextStyle(
                      color: textSecondary, fontSize: 12.5, height: 1.5),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: brandBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
                onPressed: exportSummaryPdf,
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export Executive Summary PDF'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Action Buttons Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Export Destination',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textPrimary)),
              const SizedBox(height: 4),
              Text(
                  'Select a structured format to save to your device or share.',
                  style: TextStyle(color: textSecondary, fontSize: 13)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => export('json'),
                    icon: const Icon(Icons.data_object_rounded, size: 18),
                    label: const Text('Save JSON'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => export('csv'),
                    icon: const Icon(Icons.table_chart_rounded, size: 18),
                    label: const Text('Save field ledger CSV'),
                  ),
                  if (doc.hasRecords)
                    OutlinedButton.icon(
                      onPressed: () => export('records'),
                      icon: const Icon(Icons.table_view_rounded, size: 18),
                      label: const Text('Save records CSV'),
                    ),
                  if (doc.drawingObjectCount > 0) ...[
                    OutlinedButton.icon(
                      onPressed: calibrateCad,
                      icon: const SolidSvgIcon('cad', size: 18),
                      label: Text(doc.cadIsCalibrated
                          ? 'Recalibrate CAD scale'
                          : 'Calibrate CAD scale'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => export('svg'),
                      icon: const SolidSvgIcon('cad', size: 18),
                      label: const Text('Save drawing SVG'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => export('dxf'),
                      icon: const SolidSvgIcon('cad', size: 18),
                      label: const Text('Save CAD DXF'),
                    ),
                  ],
                ],
              ),
              if (doc.drawingObjectCount > 0) ...[
                const SizedBox(height: 10),
                Text(
                  doc.cadIsCalibrated
                      ? 'DXF scale calibrated from ${doc.cadCalibrationObjectId} in ${doc.cadUnit}. Traced geometry and inferred labels still require engineering review.'
                      : 'Quadrilaterals and contours are editable vector traces. Calibrate one known width before DXF export; geometry, labels, units, and semantics remain review-required.',
                  style: TextStyle(color: textMuted, fontSize: 11, height: 1.4),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Live Export Preview Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Live Export Preview',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: textPrimary)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Copy preview to clipboard',
                    icon: Icon(Icons.copy_rounded, size: 18, color: brandBlue),
                    onPressed: () => _copyToClipboard(
                        previewText, previewFormat.toUpperCase()),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Format toggle tabs
              Row(
                children: [
                  _formatPill('JSON', 'json'),
                  const SizedBox(width: 8),
                  _formatPill('Field CSV', 'csv'),
                  if (doc.hasRecords) ...[
                    const SizedBox(width: 8),
                    _formatPill('Records CSV', 'records'),
                  ]
                ],
              ),
              const SizedBox(height: 12),
              // Code preview box
              Container(
                height: 260,
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    previewText,
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 11,
                      fontFamily: 'Courier',
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        Center(
          child: Text(
              'Source images remain on-device and are not uploaded to export files.',
              style: TextStyle(color: textMuted, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _historyPanel() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_rounded, color: brandBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Document history',
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                ),
                Text('${history.length} saved',
                    style: TextStyle(color: textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            if (history.isEmpty)
              Text('Imported documents will appear here for quick reopening.',
                  style: TextStyle(color: textSecondary, fontSize: 13))
            else
              for (final entry in history.take(6))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: brandBlue.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.description_outlined,
                        color: brandBlue, size: 20),
                  ),
                  title: Text(entry.source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '${entry.pageCount} pages • ${entry.fieldCount} fields • ${entry.needsReview} to review',
                      style: TextStyle(color: textSecondary, fontSize: 11)),
                  trailing: entry.canReopen
                      ? IconButton(
                          tooltip: 'Reopen document',
                          onPressed: busy ? null : () => _openHistory(entry),
                          icon: const Icon(Icons.arrow_forward_rounded),
                          color: brandBlue,
                        )
                      : Tooltip(
                          message:
                              'Summary from an older build; import again to enable reopening.',
                          child: Icon(Icons.history_toggle_off_rounded,
                              color: textMuted, size: 20),
                        ),
                ),
          ],
        ),
      );

  Widget _formatPill(String title, String key) {
    final active = previewFormat == key;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => previewFormat = key);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: active ? brandBlue.withValues(alpha: 0.12) : canvasBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? brandBlue : borderLight),
        ),
        child: Text(title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? brandBlue : textSecondary,
            )),
      ),
    );
  }

  Widget _placeholder(String title, String message) => ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('PAPERAZZI',
              style: TextStyle(
                  color: brandBlue,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  fontSize: 11)),
          const SizedBox(height: 4),
          Text(title,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: textPrimary)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderLight),
            ),
            child: Text(message,
                style: TextStyle(color: textSecondary, height: 1.4)),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => setState(() => tab = 0),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Go to Home'),
          ),
        ],
      );

  Widget _notice(IconData icon, String text,
      {Color? color, bool loading = false}) {
    final effectiveColor = color ?? brandBlue;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: canvasBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderLight),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: effectiveColor),
              )
            else
              Icon(icon, color: effectiveColor, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.35)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(
          {required String label, required Color color, IconData? icon}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
            ],
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3)),
          ],
        ),
      );

  Widget _fieldStatusBadge(LegacyField field, {bool compact = false}) {
    final (label, color) = field.needsReview
        ? ('REVIEW', amberWarning)
        : switch (field.status) {
            FieldStatus.accepted => ('ACCEPTED', emeraldGreen),
            FieldStatus.edited => ('EDITED', brandBlue),
            FieldStatus.unreadable => ('UNREADABLE', roseDanger),
            _ => ('READY', emeraldGreen),
          };

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8, vertical: compact ? 3 : 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: compact ? 8 : 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _BoundingBoxPainter extends CustomPainter {
  const _BoundingBoxPainter({required this.lines, this.selectedLineIndex});
  final List<OcrLine> lines;
  final int? selectedLineIndex;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.box.length < 4) continue;
      final isSelected = i == selectedLineIndex;

      // box: [left, top, width, height] normalized (0.0 to 1.0)
      final rect = Rect.fromLTWH(
        line.box[0] * size.width,
        line.box[1] * size.height,
        line.box[2] * size.width,
        line.box[3] * size.height,
      );

      final fillPaint = Paint()
        ..color =
            isSelected ? const Color(0x55F59E0B) : const Color(0x220878F9);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)), fillPaint);

      final borderPaint = Paint()
        ..color = isSelected ? amberWarning : const Color(0xAA0878F9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.0 : 0.8;
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)), borderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter oldDelegate) =>
      oldDelegate.selectedLineIndex != selectedLineIndex ||
      oldDelegate.lines != lines;
}

class _DrawingObjectPainter extends CustomPainter {
  const _DrawingObjectPainter({required this.objects});
  final List<DrawingObject> objects;

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = const Color(0xFF7C3AED)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final fillPaint = Paint()
      ..color = const Color(0xFF7C3AED).withValues(alpha: 0.10);
    final cornerPaint = Paint()
      ..color = const Color(0xFF6D28D9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    for (var i = 0; i < objects.length; i++) {
      final object = objects[i];
      if (object.box.length < 4) continue;
      final rect = Rect.fromLTWH(
        object.box[0] * size.width,
        object.box[1] * size.height,
        object.box[2] * size.width,
        object.box[3] * size.height,
      );
      final vertices = object.vertices
          .map((point) => Offset(point[0] * size.width, point[1] * size.height))
          .toList();
      if (vertices.length >= 2) {
        final path = Path()..moveTo(vertices.first.dx, vertices.first.dy);
        for (final point in vertices.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        if (object.closed) path.close();
        if (object.closed) canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
      }

      // Precision CAD corner ticks
      const tick = 10.0;
      // Top-Left
      canvas.drawLine(
          rect.topLeft, rect.topLeft + const Offset(tick, 0), cornerPaint);
      canvas.drawLine(
          rect.topLeft, rect.topLeft + const Offset(0, tick), cornerPaint);
      // Top-Right
      canvas.drawLine(
          rect.topRight, rect.topRight - const Offset(tick, 0), cornerPaint);
      canvas.drawLine(
          rect.topRight, rect.topRight + const Offset(0, tick), cornerPaint);
      // Bottom-Left
      canvas.drawLine(rect.bottomLeft, rect.bottomLeft + const Offset(tick, 0),
          cornerPaint);
      canvas.drawLine(rect.bottomLeft, rect.bottomLeft - const Offset(0, tick),
          cornerPaint);
      // Bottom-Right
      canvas.drawLine(rect.bottomRight,
          rect.bottomRight - const Offset(tick, 0), cornerPaint);
      canvas.drawLine(rect.bottomRight,
          rect.bottomRight - const Offset(0, tick), cornerPaint);

      // Engineering badge chip
      final evidence =
          object.sourceLabels.isEmpty ? '' : ' • ${object.sourceLabels.first}';
      final label =
          '${object.kind.toUpperCase()} #${i + 1} • ${(object.confidence * 100).toInt()}%$evidence';
      final span = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      );
      final textPainter = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      )..layout();

      final badgeRect = Rect.fromLTWH(
        rect.left + 4,
        rect.top + 4,
        textPainter.width + 10,
        textPainter.height + 4,
      );
      final badgePaint = Paint()
        ..color = const Color(0xFF263238).withValues(alpha: 0.92);
      canvas.drawRRect(
        RRect.fromRectAndRadius(badgeRect, const Radius.circular(4)),
        badgePaint,
      );
      textPainter.paint(canvas, Offset(rect.left + 9, rect.top + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingObjectPainter oldDelegate) =>
      oldDelegate.objects != objects;
}
