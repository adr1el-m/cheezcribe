part of '../legacy_app.dart';

extension _DrawingView on _PaperazziHomeState {
  List<Widget> _drawing(LegacyDocument doc) {
    final drawingPages =
        doc.pages.where((p) => p.drawingObjects.isNotEmpty).toList();
    if (drawingPages.isEmpty) {
      return [
        PzPanel(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 120,
                child: PzBlueprintGrid(
                  child: Center(
                    child: Icon(Icons.architecture_outlined,
                        size: 30, color: Pz.steel.withValues(alpha: .7)),
                  ),
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('No drawing geometry detected',
                        style: Pz.cardTitle),
                    const SizedBox(height: 6),
                    Text(
                      supportsCameraScan
                          ? 'Drawing Intelligence traces rectangles and contours on plan pages and links nearby dimension labels. This document produced no drawing objects, so SVG and DXF exports are not available.'
                          : 'Geometry tracing runs on iPhone. Text records from this document are available in Document and Export.',
                      style: Pz.meta.copyWith(color: Pz.graphite),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).padded(),
      ];
    }

    final current = doc.pages[pageIndex.clamp(0, doc.pages.length - 1)];
    final page =
        current.drawingObjects.isNotEmpty ? current : drawingPages.first;
    final objects = page.drawingObjects;
    final selected =
        selectedDrawing != null && selectedDrawing! < objects.length
            ? selectedDrawing
            : null;
    final calibratedIndex = doc.cadCalibrationObjectId == null
        ? -1
        : objects.indexWhere((o) => o.id == doc.cadCalibrationObjectId);

    return [
      PzEngTabs(
        tabs: const ['Original', 'Detected', 'Vector'],
        index: drawingMode,
        onChanged: (i) {
          HapticFeedback.selectionClick();
          _update(() => drawingMode = i);
        },
      ).padded(),
      const SizedBox(height: 12),
      _drawingCanvas(doc, page, objects, selected).padded(),
      if (drawingPages.length > 1) ...[
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Pz.gutter),
          child: Row(
            children: [
              for (final p in drawingPages) ...[
                _layerToggle(
                    'Pg ${_PaperazziHomeState._pad(p.number)}',
                    p.drawingObjects.length,
                    Pz.blue,
                    p.number == page.number, () {
                  _update(() {
                    pageIndex = p.number - 1;
                    selectedDrawing = null;
                  });
                }),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: 26),
      PzSectionHeader('Drawing elements', trailing: '${objects.length}')
          .padded(),
      PzPanel(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final (i, o) in objects.indexed) ...[
              if (i > 0) const Divider(),
              _drawingElementRow(doc, o, i,
                  selected: selected == i, reference: calibratedIndex == i),
            ],
          ],
        ),
      ).padded(),
      const SizedBox(height: 14),
      PzPanel(
        padding: EdgeInsets.zero,
        child: PzDataRow(
          label: 'Drawing scale',
          value: doc.cadIsCalibrated
              ? 'Calibrated · ${calibratedIndex >= 0 ? drawingObjectTag(objects[calibratedIndex], calibratedIndex) : 'reference object'} · ${doc.cadUnit}'
              : 'Uncalibrated · unitless coordinates',
          indicator: doc.cadIsCalibrated ? Pz.verified : Pz.review,
          trailing: PzSecondaryButton(
            label: doc.cadIsCalibrated ? 'Recalibrate' : 'Calibrate',
            icon: Icons.straighten,
            expand: false,
            height: 36,
            onPressed: calibrateCad,
          ),
        ),
      ).padded(),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: PzPrimaryButton(
              label: 'Export DXF',
              icon: Icons.file_download_outlined,
              height: 44,
              onPressed: () => export('dxf'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: PzSecondaryButton(
              label: 'Export SVG',
              icon: Icons.file_download_outlined,
              onPressed: () => export('svg'),
            ),
          ),
        ],
      ).padded(),
      const SizedBox(height: 10),
      Text(
        doc.cadIsCalibrated
            ? 'Traced geometry and inferred labels remain review-required in both exports.'
            : 'Calibrate one known width before relying on DXF coordinates. Geometry, labels, and units remain review-required.',
        style: Pz.meta.copyWith(fontSize: 11.5, color: Pz.muted),
      ).padded(),
    ];
  }

  Widget _drawingCanvas(LegacyDocument doc, LegacyPage page,
      List<DrawingObject> objects, int? selected) {
    final vector = drawingMode == 2;
    final image = showEnhanced && page.enhancedImage != null
        ? page.enhancedImage!
        : page.image;
    return Container(
      height: 400,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: vector ? Pz.paper : Pz.surface2,
        borderRadius: BorderRadius.circular(Pz.rCard),
        border: Border.all(color: Pz.lineStrong),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (vector) const PzBlueprintGrid(opacity: .045),
          InteractiveViewer(
            minScale: 1,
            maxScale: 6,
            child: Center(
              child: Stack(
                children: [
                  // The image sizes the stack in every mode so geometry stays
                  // registered; vector mode hides it.
                  Opacity(
                    opacity: vector ? 0 : 1,
                    child: Image.memory(image,
                        fit: BoxFit.contain, gaplessPlayback: true),
                  ),
                  if (drawingMode == 1)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: DrawingOverlayPainter(
                            objects: objects, selected: selected),
                      ),
                    ),
                  if (vector)
                    Positioned.fill(
                      child: CustomPaint(
                        painter:
                            VectorPainter(objects: objects, selected: selected),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: _previewTag(
                'Page ${_PaperazziHomeState._pad(page.number)} · ${objects.length} objects'),
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: _previewTag(
                doc.cadIsCalibrated ? 'Scale · ${doc.cadUnit}' : 'Unitless'),
          ),
        ],
      ),
    );
  }

  Widget _drawingElementRow(LegacyDocument doc, DrawingObject o, int index,
      {required bool selected, required bool reference}) {
    final width = o.box.length >= 4 ? o.box[2] : 0.0;
    final height = o.box.length >= 4 ? o.box[3] : 0.0;
    final size = doc.cadIsCalibrated
        ? '${(width * doc.cadPageWidth!).toStringAsFixed(1)} × '
            '${(height * doc.cadPageWidth!).toStringAsFixed(1)} ${doc.cadUnit}'
        : '${width.toStringAsFixed(3)} × ${height.toStringAsFixed(3)} page';
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        _update(() => selectedDrawing = selected ? null : index);
      },
      child: Container(
        decoration: BoxDecoration(
          color: selected ? Pz.blue.withValues(alpha: .05) : null,
          border: Border(
              left: BorderSide(
                  color: selected ? Pz.blue : Colors.transparent, width: 3)),
        ),
        padding: const EdgeInsets.fromLTRB(13, 11, 14, 11),
        child: Row(
          children: [
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: selected ? Pz.blue : Pz.lineStrong),
                borderRadius: BorderRadius.circular(3),
              ),
              alignment: Alignment.center,
              child: Text(drawingObjectTag(o, index),
                  style: Pz.label.copyWith(
                      fontSize: 10,
                      color: selected ? Pz.blue : Pz.graphite,
                      fontFeatures: Pz.tabular)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${o.kind[0].toUpperCase()}${o.kind.substring(1)}'
                    '${o.closed ? '' : ' · open path'}'
                    '${reference ? ' · scale reference' : ''}',
                    style: Pz.cardTitle.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    o.sourceLabels.isEmpty
                        ? '$size · no linked label'
                        : '$size · ${o.sourceLabels.join(', ')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Pz.meta.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            PzConfidence(o.confidence, threshold: .8),
          ],
        ),
      ),
    );
  }
}
