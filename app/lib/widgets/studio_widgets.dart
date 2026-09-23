import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';

class StudioLabel extends StatelessWidget {
  const StudioLabel(this.text, {super.key, this.color = muted});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: color,
      ));
}

class StudioCard extends StatelessWidget {
  const StudioCard(
      {super.key,
      required this.child,
      this.padding = 20,
      this.color = surface});
  final Widget child;
  final double padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Material(
        color: color,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: line.withValues(alpha: 0.5)),
        ),
        child: Padding(padding: EdgeInsets.all(padding), child: child),
      );
}

class OrbitArt extends StatelessWidget {
  const OrbitArt({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 150,
        width: 150,
        child: CustomPaint(
            painter: _OrbitPainter(),
            child: const Center(
                child:
                    Icon(Icons.auto_awesome_rounded, color: mint, size: 42))),
      );
}

class _OrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final glow = Paint()
      ..shader = const RadialGradient(
        colors: [Color(0x4434AC77), Color(0x0034AC77)],
      ).createShader(Rect.fromCircle(center: c, radius: 70));
    canvas.drawCircle(c, 70, glow);
    final ring = Paint()
      ..color = mint.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    for (final a in [0.0, math.pi / 3, -math.pi / 3]) {
      canvas.save();
      canvas.rotate(a);
      canvas.drawOval(const Rect.fromLTWH(-67, -28, 134, 56), ring);
      canvas.restore();
    }
    canvas.restore();
    for (final p in [
      Offset(c.dx + 65, c.dy),
      Offset(c.dx - 34, c.dy - 47),
      Offset(c.dx - 28, c.dy + 49)
    ]) {
      canvas.drawCircle(p, 4, Paint()..color = mint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void showStudioMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
