import 'package:flutter/material.dart';

import '../legacy_models.dart';
import 'pz_tokens.dart';

/// Thin OCR line boxes. The selected source line is drawn in amber with
/// registration ticks so it can be traced from the review panel.
class OcrOverlayPainter extends CustomPainter {
  const OcrOverlayPainter({required this.lines, this.selectedLineIndex});
  final List<OcrLine> lines;
  final int? selectedLineIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = Pz.overlayText.withValues(alpha: .55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7;
    final fill = Paint()..color = Pz.overlayText.withValues(alpha: .06);
    Rect? selected;
    for (var i = 0; i < lines.length; i++) {
      final box = lines[i].box;
      if (box.length < 4) continue;
      final rect = Rect.fromLTWH(box[0] * size.width, box[1] * size.height,
          box[2] * size.width, box[3] * size.height);
      if (i == selectedLineIndex) {
        selected = rect;
        continue;
      }
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, stroke);
    }
    if (selected != null) {
      final r = selected.inflate(2);
      canvas.drawRect(r, Paint()..color = Pz.review.withValues(alpha: .14));
      canvas.drawRect(
          r,
          Paint()
            ..color = Pz.review
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4);
      _ticks(canvas, r, Pz.review);
    }
  }

  void _ticks(Canvas canvas, Rect r, Color color) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    const t = 5.0;
    canvas
      ..drawLine(r.centerLeft - const Offset(t, 0), r.centerLeft, p)
      ..drawLine(r.centerRight, r.centerRight + const Offset(t, 0), p)
      ..drawLine(r.topCenter - const Offset(0, t), r.topCenter, p)
      ..drawLine(r.bottomCenter, r.bottomCenter + const Offset(0, t), p);
  }

  @override
  bool shouldRepaint(covariant OcrOverlayPainter old) =>
      old.selectedLineIndex != selectedLineIndex || old.lines != lines;
}

/// Engineering callout label for a detected drawing object.
String drawingObjectTag(DrawingObject object, int index) {
  final code = switch (object.kind) {
    'tank section' => 'TANK-SEC',
    'foundation slab' => 'SLAB',
    'central riser' => 'RISER',
    'roof outer ring' => 'ROOF-OUT',
    'roof inner ring' => 'ROOF-IN',
    'roof center hub' => 'HUB',
    'radial roof support' =>
      'RAD-${(index - 5).clamp(1, 99).toString().padLeft(2, '0')}',
    'supply pipe run' => 'SUPPLY',
    'waste pipe run' => 'WASTE',
    'valve assembly' => 'VALVE',
    'segmental section' => 'SEG-SEC',
    _ => 'OBJ-${(index + 1).toString().padLeft(2, '0')}',
  };
  return code;
}

/// Detected drawing geometry over the scan: thin boxes, traced outline, and
/// callout tags joined by leader lines.
class DrawingOverlayPainter extends CustomPainter {
  const DrawingOverlayPainter({required this.objects, this.selected});
  final List<DrawingObject> objects;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < objects.length; i++) {
      final o = objects[i];
      if (o.box.length < 4) continue;
      final active = selected == null || selected == i;
      final color =
          active ? Pz.overlayDrawing : Pz.overlayDrawing.withValues(alpha: .35);
      final rect = Rect.fromLTWH(o.box[0] * size.width, o.box[1] * size.height,
          o.box[2] * size.width, o.box[3] * size.height);

      canvas.drawRect(
          rect,
          Paint()
            ..color = color.withValues(alpha: .6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .6);
      final path = _outline(o, size);
      if (path != null) {
        canvas.drawPath(
            path,
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = selected == i ? 1.8 : 1.2);
      }

      // Callout: leader from the top-left corner up and out to a tag.
      final tag = drawingObjectTag(o, i);
      final kind = o.kind.toUpperCase();
      // Only the selected object carries its full callout; the rest show a
      // compact tag so dense sheets stay legible.
      final expanded = selected == i;
      final tp = TextPainter(
        text: TextSpan(children: [
          TextSpan(
              text: tag,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .6,
                  color: Colors.white,
                  fontFeatures: Pz.tabular)),
          if (expanded)
            TextSpan(
                text: o.sourceLabels.isEmpty
                    ? '\n$kind'
                    : '\n$kind · ${o.sourceLabels.first}',
                style: const TextStyle(
                    fontSize: 8.5,
                    letterSpacing: .5,
                    color: Color(0xFFD9DEE5))),
        ]),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 150);
      final anchor = rect.topLeft;
      final elbow =
          Offset(anchor.dx + 10, (anchor.dy - 14).clamp(4, size.height));
      final tagTopLeft = Offset(
          (elbow.dx + 6).clamp(0, size.width - tp.width - 10),
          (elbow.dy - tp.height / 2 - 3).clamp(0, size.height - tp.height - 6));
      final lead = Paint()
        ..color = color
        ..strokeWidth = .8;
      canvas
        ..drawLine(anchor, elbow, lead)
        ..drawLine(elbow, Offset(tagTopLeft.dx, elbow.dy), lead)
        ..drawCircle(anchor, 2, Paint()..color = color);
      final tagRect = Rect.fromLTWH(
          tagTopLeft.dx, tagTopLeft.dy, tp.width + 10, tp.height + 4);
      canvas.drawRect(tagRect,
          Paint()..color = Pz.graphite.withValues(alpha: active ? .92 : .5));
      canvas.drawRect(
          Rect.fromLTWH(tagRect.left, tagRect.top, 2, tagRect.height),
          Paint()..color = color);
      tp.paint(canvas, tagTopLeft + const Offset(6, 2));
    }
  }

  @override
  bool shouldRepaint(covariant DrawingOverlayPainter old) =>
      old.objects != objects || old.selected != selected;
}

/// Clean line geometry only, for the VECTOR view.
class VectorPainter extends CustomPainter {
  const VectorPainter({required this.objects, this.selected});
  final List<DrawingObject> objects;
  final int? selected;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < objects.length; i++) {
      final path = _outline(objects[i], size);
      if (path == null) continue;
      final isSelected = selected == i;
      canvas.drawPath(
          path,
          Paint()
            ..color = isSelected ? Pz.blue : Pz.navy
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? 1.6 : 1.1
            ..strokeJoin = StrokeJoin.miter);
      final vertices = objects[i].vertices;
      final node = Paint()..color = isSelected ? Pz.blue : Pz.navy;
      for (final v in vertices) {
        canvas.drawRect(
            Rect.fromCenter(
                center: Offset(v[0] * size.width, v[1] * size.height),
                width: 3,
                height: 3),
            node);
      }
      final box = objects[i].box;
      if (box.length >= 4) {
        final tp = TextPainter(
          text: TextSpan(
              text: drawingObjectTag(objects[i], i),
              style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .6,
                  color: isSelected ? Pz.blue : Pz.steel,
                  fontFeatures: Pz.tabular)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
            canvas,
            Offset(box[0] * size.width + 3,
                (box[1] * size.height - tp.height - 2).clamp(0, size.height)));
      }
    }
  }

  @override
  bool shouldRepaint(covariant VectorPainter old) =>
      old.objects != objects || old.selected != selected;
}

Path? _outline(DrawingObject o, Size size) {
  final v = o.vertices;
  if (v.length < 2) return null;
  final path = Path()
    ..moveTo(v.first[0] * size.width, v.first[1] * size.height);
  for (final p in v.skip(1)) {
    path.lineTo(p[0] * size.width, p[1] * size.height);
  }
  if (o.closed) path.close();
  return path;
}
