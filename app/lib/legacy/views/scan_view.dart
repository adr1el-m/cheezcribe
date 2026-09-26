part of '../legacy_app.dart';

const _scanMuted = Pz.steel;

extension _ScanView on _PaperazziHomeState {
  Widget _scanView() {
    final doc = document;
    final showResult = justImported && doc != null && !busy;

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
          child: Row(
            children: [
              PzIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                color: Pz.navy,
                onPressed: () => _go(_Tab.home),
              ),
              const Expanded(
                child: Center(
                  child: PzLabel('Document scan', color: Pz.navy, size: 12),
                ),
              ),
              PzIconButton(
                icon: Icons.tune,
                tooltip: 'Cloud extraction settings',
                color: Pz.navy,
                onPressed: openCloudSettings,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Pz.gutter),
          child: _viewfinder(showResult ? doc : null),
        ),
        const SizedBox(height: 18),
        _captureControls(),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Pz.gutter),
          child: _checklist(showResult ? doc : null),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Pz.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cloudRow(),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!,
                    style: const TextStyle(
                        fontSize: 13, color: Pz.error, height: 1.4)),
              ],
              if (showResult) ...[
                const SizedBox(height: 18),
                PzPrimaryButton(
                  label: 'Open Document Understanding',
                  icon: Icons.arrow_forward,
                  onPressed: () => _go(_Tab.review, view: _ReviewView.document),
                ),
                if (note != null) ...[
                  const SizedBox(height: 10),
                  Text(note!,
                      style: const TextStyle(
                          fontSize: 12, color: _scanMuted, height: 1.4)),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _viewfinder(LegacyDocument? result) {
    final page = result?.pages.first;
    final tags = [
      supportsCameraScan ? 'Live camera' : 'File import',
      supportsCameraScan ? 'Captured source' : 'Image',
      kIsWeb ? 'Secure vision' : 'On-device OCR',
    ];
    return AspectRatio(
      aspectRatio: 1.12,
      child: Container(
        decoration: BoxDecoration(
          color: Pz.surface2,
          borderRadius: BorderRadius.circular(Pz.rCard),
          border: Border.all(color: Pz.line),
        ),
        child: CustomPaint(
          painter: _RulerPainter(),
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: PzCornerBrackets(
              color: busy ? Pz.blue : Pz.deepBlue,
              length: 20,
              stroke: 1.5,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: page != null
                    ? Center(
                        child: Image.memory(page.image,
                            fit: BoxFit.contain, gaplessPlayback: true),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                              supportsCameraScan
                                  ? Icons.crop_free
                                  : Icons.upload_file_outlined,
                              size: 34,
                              color: _scanMuted),
                          const SizedBox(height: 12),
                          Text(
                            busy
                                ? (stage.isEmpty ? 'Processing' : stage)
                                : supportsCameraScan
                                    ? 'Place the page on a flat, even surface.\nCapture uses this device camera and keeps the original photo.'
                                    : 'Import a scanned image or PDF.\nUp to 100 pages per batch.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13, color: _scanMuted, height: 1.45),
                          ),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final t in tags)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 4),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Pz.line),
                                    borderRadius:
                                        BorderRadius.circular(Pz.rChip - 2),
                                  ),
                                  child:
                                      PzLabel(t, color: _scanMuted, size: 9.5),
                                ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _checklist(LegacyDocument? result) {
    final phase = stage.contains('Interpret') || stage.contains('Structur')
        ? 2
        : stage.contains('Scanning')
            ? 0
            : 1;

    PzStepState state(int rowPhase, {bool present = true}) {
      if (result != null) {
        return present ? PzStepState.done : PzStepState.skipped;
      }
      if (!busy) return PzStepState.pending;
      if (rowPhase < phase) return PzStepState.done;
      return rowPhase == phase ? PzStepState.active : PzStepState.pending;
    }

    final r = result;
    final enhanced = r?.pages.where((p) => p.enhancementApplied).length ?? 0;
    final records = r == null
        ? 0
        : r.fields
            .where((f) => f.recordIndex > 0)
            .map((f) => f.recordIndex)
            .toSet()
            .length;
    final drawings = r?.drawingObjectCount ?? 0;
    final cloud = allowCloudAi && widget.connection.ready;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: Pz.card,
        borderRadius: BorderRadius.circular(Pz.rCard),
        border: Border.all(color: Pz.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const PzLabel('Processing', color: Pz.navy),
              const Spacer(),
              PzLabel(cloud ? 'Cloud extraction on' : 'On-device model',
                  color: cloud ? Pz.blue : _scanMuted, size: 10),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(color: Pz.line),
          const SizedBox(height: 4),
          PzScannerStatusRow(
            label: 'Source',
            state: state(0),
            value: r != null
                ? '${r.pages.length} page${r.pages.length == 1 ? '' : 's'} received'
                : busy && phase == 0
                    ? 'Capturing pages'
                    : 'Camera or file',
          ),
          PzScannerStatusRow(
            label: 'Text',
            state: state(1),
            value: r != null
                ? r.totalOcrLines == 0
                    ? 'Prepared source profile · OCR not run'
                    : '${_fmtInt(r.totalOcrLines)} lines · ${(r.meanOcrConfidence * 100).toStringAsFixed(1)}% mean'
                : 'Recognition · $ocrEngineName',
          ),
          PzScannerStatusRow(
            label: 'Contrast',
            state: state(1, present: enhanced > 0),
            value: r != null
                ? enhanced > 0
                    ? 'Enhanced on $enhanced of ${r.pages.length} page${r.pages.length == 1 ? '' : 's'}'
                    : 'Original retained'
                : supportsCameraScan
                    ? kIsWeb
                        ? 'Original capture retained'
                        : 'Enhanced pass compared'
                    : 'Not used on this platform',
          ),
          PzScannerStatusRow(
            label: 'Extraction',
            state: state(2, present: r?.fields.isNotEmpty ?? false),
            value: r != null
                ? '${r.fields.length} fields · ${r.documentType}'
                : cloud
                    ? kIsWeb
                        ? 'Secure vision analysis'
                        : 'Gemini, pages 1–8'
                    : 'On-device structuring',
          ),
          PzScannerStatusRow(
            label: 'Table',
            state: state(2, present: records > 0),
            value: r != null
                ? records > 0
                    ? '$records record rows grouped'
                    : 'None detected'
                : 'Grouped records',
          ),
          PzScannerStatusRow(
            label: 'Drawing',
            state: state(2, present: drawings > 0),
            value: r != null
                ? drawings > 0
                    ? '$drawings objects traced'
                    : 'None detected'
                : 'Geometry tracing',
          ),
          PzScannerStatusRow(
            label: 'Review',
            state: r != null
                ? PzStepState.done
                : busy && phase == 2
                    ? PzStepState.active
                    : PzStepState.pending,
            value: r != null
                ? r.needsReview > 0
                    ? '${r.needsReview} fields need verification'
                    : 'All fields source linked'
                : 'Routing',
          ),
        ],
      ),
    );
  }

  Widget _captureControls() {
    final canImport = supportsImport && !busy;
    Widget side(IconData icon, String label, VoidCallback? onTap) => SizedBox(
          width: 88,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(Pz.rButton),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Icon(icon,
                      size: 22,
                      color: onTap == null ? Pz.inactive : Pz.graphite),
                  const SizedBox(height: 6),
                  PzLabel(label, color: _scanMuted, size: 9.5),
                ],
              ),
            ),
          ),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        side(Icons.upload_file_outlined, kIsWeb ? 'Import image' : 'Import',
            canImport ? () => import() : null),
        const SizedBox(width: 24),
        Semantics(
          button: true,
          label: supportsCameraScan ? 'Capture document' : 'Import document',
          child: GestureDetector(
            onTap: canImport ? () => import(camera: supportsCameraScan) : null,
            child: Container(
              width: 74,
              height: 74,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: canImport ? Pz.navy : Pz.inactive, width: 2),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: canImport ? Pz.blue : Pz.surface2,
                ),
                child: busy
                    ? const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        supportsCameraScan
                            ? Icons.document_scanner_outlined
                            : Icons.upload_file_outlined,
                        color: canImport ? Colors.white : Pz.inactive,
                        size: 26),
              ),
            ),
          ),
        ),
        const SizedBox(width: 24),
        side(Icons.description_outlined, 'Demo file',
            canImport ? () => import(sample: true) : null),
      ],
    );
  }

  Widget _cloudRow() => Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(
          border: Border.all(color: Pz.line),
          borderRadius: BorderRadius.circular(Pz.rCard),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PzLabel('Cloud extraction',
                      color: Pz.graphite, size: 10.5),
                  const SizedBox(height: 3),
                  Text(
                    allowCloudAi
                        ? 'Gemini verified · sends page image and OCR lines'
                        : 'Off · all processing stays on this device',
                    style: const TextStyle(fontSize: 12, color: _scanMuted),
                  ),
                ],
              ),
            ),
            Switch(
              value: allowCloudAi,
              onChanged: busy
                  ? null
                  : (value) {
                      if (value && !widget.connection.ready) {
                        openCloudSettings();
                      } else {
                        _update(() => allowCloudAi = value);
                      }
                    },
            ),
          ],
        ),
      );
}

/// Measurement ticks along the viewfinder edges.
class _RulerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = Pz.lineStrong
      ..strokeWidth = 1;
    final major = Paint()
      ..color = Pz.muted
      ..strokeWidth = 1;
    const step = 10.0;
    var i = 0;
    for (var x = 26.0; x <= size.width - 26; x += step, i++) {
      final len = i % 5 == 0 ? 7.0 : 3.5;
      final p = i % 5 == 0 ? major : minor;
      canvas.drawLine(Offset(x, 8), Offset(x, 8 + len), p);
      canvas.drawLine(
          Offset(x, size.height - 8), Offset(x, size.height - 8 - len), p);
    }
    i = 0;
    for (var y = 26.0; y <= size.height - 26; y += step, i++) {
      final len = i % 5 == 0 ? 7.0 : 3.5;
      final p = i % 5 == 0 ? major : minor;
      canvas.drawLine(Offset(8, y), Offset(8 + len, y), p);
      canvas.drawLine(
          Offset(size.width - 8, y), Offset(size.width - 8 - len, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _RulerPainter oldDelegate) => false;
}
