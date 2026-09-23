import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'pz_tokens.dart';

/// Uppercase technical label, e.g. SOURCE DOCUMENT or PAGE 12 OF 24.
class PzLabel extends StatelessWidget {
  const PzLabel(this.text, {super.key, this.color, this.size});
  final String text;
  final Color? color;
  final double? size;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Pz.label.copyWith(color: color, fontSize: size),
      );
}

/// Flat bordered surface. The default container for grouped content.
class PzPanel extends StatelessWidget {
  const PzPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Pz.card,
    this.borderColor = Pz.line,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(Pz.rCard),
          border: Border.all(color: borderColor),
        ),
        child: child,
      );
}

/// Screen header: overline label, title, optional back and trailing actions.
class PzTopBar extends StatelessWidget {
  const PzTopBar({
    super.key,
    required this.title,
    this.overline,
    this.onBack,
    this.actions = const [],
    this.dark = false,
  });
  final String title;
  final String? overline;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool dark;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Pz.gutter, 12, Pz.gutter, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (onBack != null) ...[
              PzIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Back',
                onPressed: onBack,
                color: dark ? Colors.white : Pz.navy,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (overline != null) ...[
                    PzLabel(overline!,
                        color: dark ? const Color(0xFF9FB0C4) : Pz.blue),
                    const SizedBox(height: 6),
                  ],
                  Text(title,
                      style: Pz.screenTitle
                          .copyWith(color: dark ? Colors.white : Pz.navy)),
                ],
              ),
            ),
            ...actions,
          ],
        ),
      );
}

class PzIconButton extends StatelessWidget {
  const PzIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color = Pz.navy,
    this.size = 20,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Pz.rButton)),
        ),
        icon: Icon(icon, size: size, color: color),
      );
}

/// Section header with a thin rule, e.g. RECENT ARCHIVES ─────── 6 SAVED.
class PzSectionHeader extends StatelessWidget {
  const PzSectionHeader(this.label, {super.key, this.trailing});
  final String label;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            PzLabel(label, color: Pz.graphite),
            const SizedBox(width: 10),
            const Expanded(child: Divider()),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              PzLabel(trailing!),
            ],
          ],
        ),
      );
}

class PzMetric {
  const PzMetric(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;
}

/// One unified data panel split by thin dividers.
class PzDataGrid extends StatelessWidget {
  const PzDataGrid(this.metrics, {super.key, this.columns = 2});
  final List<PzMetric> metrics;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final rows = <List<PzMetric>>[];
    for (var i = 0; i < metrics.length; i += columns) {
      rows.add(metrics.sublist(i, (i + columns).clamp(0, metrics.length)));
    }
    return PzPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) const Divider(),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) const VerticalDivider(width: 1),
                    Expanded(
                      child: c < rows[r].length
                          ? Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 12, 12, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  PzLabel(rows[r][c].label),
                                  const SizedBox(height: 8),
                                  Text(rows[r][c].value,
                                      style: Pz.figure
                                          .copyWith(color: rows[r][c].color)),
                                ],
                              ),
                            )
                          : const SizedBox(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Label/value row used in record tables and change logs. An optional left
/// indicator marks rows that need attention without using banners.
class PzDataRow extends StatelessWidget {
  const PzDataRow({
    super.key,
    required this.label,
    required this.value,
    this.trailing,
    this.note,
    this.indicator,
    this.onTap,
    this.selected = false,
    this.valueStyle,
  });
  final String label;
  final String value;
  final Widget? trailing;
  final String? note;
  final Color? indicator;
  final VoidCallback? onTap;
  final bool selected;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: selected ? Pz.blue.withValues(alpha: .05) : null,
            border: Border(
              left:
                  BorderSide(color: indicator ?? Colors.transparent, width: 3),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(13, 11, 14, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PzLabel(label),
                    const SizedBox(height: 4),
                    Text(value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: valueStyle ?? Pz.value),
                    if (note != null) ...[
                      const SizedBox(height: 3),
                      Text(note!,
                          style: Pz.meta.copyWith(
                              fontSize: 12,
                              color: indicator ?? Pz.steel,
                              fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      );
}

enum PzStatus { verified, ready, review, edited, unreadable, inactive }

class PzStatusBadge extends StatelessWidget {
  const PzStatusBadge(this.status, {super.key, this.dense = false});
  final PzStatus status;
  final bool dense;

  static (String, Color) describe(PzStatus status) => switch (status) {
        PzStatus.verified => ('Verified', Pz.verified),
        PzStatus.ready => ('Source linked', Pz.verified),
        PzStatus.review => ('Needs verification', Pz.review),
        PzStatus.edited => ('Revised', Pz.blue),
        PzStatus.unreadable => ('Unreadable', Pz.error),
        PzStatus.inactive => ('Inactive', Pz.inactive),
      };

  @override
  Widget build(BuildContext context) {
    var (label, color) = describe(status);
    if (dense) {
      label = switch (status) {
        PzStatus.review => 'Review',
        PzStatus.ready => 'Linked',
        _ => label,
      };
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(Pz.rChip),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label.toUpperCase(),
              style: Pz.label.copyWith(
                  color: color, fontSize: dense ? 9.5 : 10, letterSpacing: .8)),
        ],
      ),
    );
  }
}

/// Numeric confidence with a short meter. Null renders an em dash.
class PzConfidence extends StatelessWidget {
  const PzConfidence(this.value, {super.key, this.threshold = .85});
  final double? value;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final v = value;
    final color = v == null
        ? Pz.inactive
        : v >= threshold
            ? Pz.verified
            : Pz.review;
    return SizedBox(
      width: 44,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(v == null ? '—' : '${(v * 100).round()}%',
              style: Pz.value.copyWith(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          const SizedBox(height: 4),
          Container(
            height: 2,
            color: Pz.line,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: (v ?? 0).clamp(0.0, 1.0),
              child: Container(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Document thumbnail with stacked page-edge lines behind it.
class PzDocThumb extends StatelessWidget {
  const PzDocThumb({
    super.key,
    this.image,
    this.width = 44,
    this.height = 56,
    this.layers = 2,
    this.icon = Icons.description_outlined,
  });
  final Uint8List? image;
  final double width;
  final double height;
  final int layers;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const offset = 3.0;
    return SizedBox(
      width: width + offset * layers,
      height: height + offset * layers,
      child: Stack(
        children: [
          for (var i = layers; i >= 1; i--)
            Positioned(
              left: offset * i,
              top: offset * (layers - i),
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Pz.paper,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: Pz.lineStrong, width: .8),
                ),
              ),
            ),
          Positioned(
            left: 0,
            top: offset * layers,
            child: Container(
              width: width,
              height: height,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Pz.paper,
                borderRadius: BorderRadius.circular(2),
                border: Border.all(color: Pz.lineStrong),
              ),
              child: image != null && image!.isNotEmpty
                  ? Image.memory(image!,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      gaplessPlayback: true,
                      cacheWidth: (width * 3).round())
                  : Center(
                      child: Icon(icon, size: width * .42, color: Pz.muted)),
            ),
          ),
        ],
      ),
    );
  }
}

/// A document record row: layered thumbnail, title, type, meta, status.
class PzArchiveRow extends StatelessWidget {
  const PzArchiveRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.meta,
    this.thumb,
    this.trailing,
    this.onTap,
  });
  final String title;
  final String subtitle;
  final String meta;
  final Widget? thumb;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              thumb ?? const PzDocThumb(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Pz.cardTitle),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Pz.meta),
                    const SizedBox(height: 6),
                    Text(meta,
                        style: Pz.label.copyWith(
                            fontSize: 10.5,
                            letterSpacing: .8,
                            fontFeatures: Pz.tabular)),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          ),
        ),
      );
}

/// Rectangular engineering tabs with a 2 px active indicator.
class PzEngTabs extends StatelessWidget {
  const PzEngTabs({
    super.key,
    required this.tabs,
    required this.index,
    required this.onChanged,
    this.dark = false,
  });
  final List<String> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border:
              Border(bottom: BorderSide(color: dark ? Pz.lineDark : Pz.line)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: i == index ? Pz.blue : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      tabs[i].toUpperCase(),
                      style: Pz.label.copyWith(
                        fontSize: 11,
                        color: i == index
                            ? Pz.blue
                            : dark
                                ? const Color(0xFF8595A8)
                                : Pz.steel,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class PzPrimaryButton extends StatelessWidget {
  const PzPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expand = true,
    this.height = 48,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(minimumSize: Size(0, height)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 19),
            const SizedBox(width: 10)
          ],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class PzSecondaryButton extends StatelessWidget {
  const PzSecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.expand = true,
    this.color,
    this.height = 44,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: Size(0, height),
        foregroundColor: color ?? Pz.navy,
        side: BorderSide(color: color?.withValues(alpha: .45) ?? Pz.lineStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 17), const SizedBox(width: 8)],
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

enum PzStepState { done, active, pending, skipped }

/// Compact checklist row for the scan surface.
class PzScannerStatusRow extends StatelessWidget {
  const PzScannerStatusRow({
    super.key,
    required this.label,
    required this.value,
    required this.state,
  });
  final String label;
  final String value;
  final PzStepState state;

  @override
  Widget build(BuildContext context) {
    final Widget indicator = switch (state) {
      PzStepState.done => const Icon(Icons.check, size: 14, color: Pz.verified),
      PzStepState.active => const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: Pz.blue)),
      PzStepState.pending => Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
              border: Border.all(color: Pz.inactive), shape: BoxShape.circle)),
      PzStepState.skipped =>
        const Icon(Icons.remove, size: 14, color: Pz.inactive),
    };
    final dim = state == PzStepState.pending || state == PzStepState.skipped;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(width: 18, child: Center(child: indicator)),
          const SizedBox(width: 10),
          SizedBox(
            width: 108,
            child:
                PzLabel(label, color: dim ? Pz.inactive : Pz.steel, size: 10.5),
          ),
          Expanded(
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontFeatures: Pz.tabular,
                    fontWeight: FontWeight.w500,
                    color: dim ? Pz.inactive : Pz.navy)),
          ),
        ],
      ),
    );
  }
}

/// Wraps a child with thin registration corner brackets.
class PzCornerBrackets extends StatelessWidget {
  const PzCornerBrackets({
    super.key,
    required this.child,
    this.color = Pz.blue,
    this.length = 14,
    this.stroke = 1.5,
    this.inset = 0,
  });
  final Widget child;
  final Color color;
  final double length;
  final double stroke;
  final double inset;

  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: _BracketPainter(color, length, stroke, inset),
        child: child,
      );
}

class _BracketPainter extends CustomPainter {
  _BracketPainter(this.color, this.length, this.stroke, this.inset);
  final Color color;
  final double length;
  final double stroke;
  final double inset;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    final r = Rect.fromLTWH(
        inset, inset, size.width - inset * 2, size.height - inset * 2);
    void corner(Offset o, double dx, double dy) {
      canvas.drawLine(o, o + Offset(length * dx, 0), p);
      canvas.drawLine(o, o + Offset(0, length * dy), p);
    }

    corner(r.topLeft, 1, 1);
    corner(r.topRight, -1, 1);
    corner(r.bottomLeft, 1, -1);
    corner(r.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(covariant _BracketPainter old) =>
      old.color != color || old.length != length || old.inset != inset;
}

/// Very faint engineering grid for drawing surfaces.
class PzBlueprintGrid extends StatelessWidget {
  const PzBlueprintGrid({super.key, this.child, this.opacity = .05});
  final Widget? child;
  final double opacity;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _GridPainter(opacity), child: child);
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.opacity);
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = Pz.deepBlue.withValues(alpha: opacity)
      ..strokeWidth = .5;
    final major = Paint()
      ..color = Pz.deepBlue.withValues(alpha: opacity * 2)
      ..strokeWidth = .7;
    const step = 12.0;
    var i = 0;
    for (var x = 0.0; x <= size.width; x += step, i++) {
      canvas.drawLine(
          Offset(x, 0), Offset(x, size.height), i % 5 == 0 ? major : minor);
    }
    i = 0;
    for (var y = 0.0; y <= size.height; y += step, i++) {
      canvas.drawLine(
          Offset(0, y), Offset(size.width, y), i % 5 == 0 ? major : minor);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.opacity != opacity;
}

/// Source reference line, e.g. PAGE 12 · ZONE B4 · LINE 031.
class PzSourceReference extends StatelessWidget {
  const PzSourceReference({super.key, required this.parts, this.color});
  final List<String> parts;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 1, color: color ?? Pz.blue),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              parts.map((p) => p.toUpperCase()).join('  ·  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Pz.label.copyWith(
                  color: color ?? Pz.blue,
                  fontSize: 10.5,
                  fontFeatures: Pz.tabular),
            ),
          ),
        ],
      );
}

/// Inline message with a left rule instead of a banner.
class PzNotice extends StatelessWidget {
  const PzNotice(this.text,
      {super.key, this.color = Pz.steel, this.loading = false, this.icon});
  final String text;
  final Color color;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Pz.card,
          border: Border(
            left: BorderSide(color: color, width: 2),
            top: const BorderSide(color: Pz.line),
            right: const BorderSide(color: Pz.line),
            bottom: const BorderSide(color: Pz.line),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loading)
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 10),
                child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: color)),
              )
            else if (icon != null)
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 10),
                child: Icon(icon, size: 16, color: color),
              ),
            Expanded(
                child: Text(text,
                    style: Pz.meta.copyWith(color: Pz.graphite, height: 1.4))),
          ],
        ),
      );
}

/// Revision summary: how far the current value has moved from source.
class PzRevisionIndicator extends StatelessWidget {
  const PzRevisionIndicator({super.key, required this.changes});

  /// Null means there is no source text to compare against.
  final int? changes;

  @override
  Widget build(BuildContext context) {
    final c = changes;
    final (text, color) = c == null
        ? ('No source text to compare', Pz.steel)
        : c == 0
            ? ('Matches source', Pz.verified)
            : ('$c character${c == 1 ? '' : 's'} changed', Pz.blue);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
            c == null || c == 0
                ? Icons.horizontal_rule
                : Icons.change_history_outlined,
            size: 14,
            color: color),
        const SizedBox(width: 6),
        Text(text,
            style: Pz.value.copyWith(
                fontSize: 13, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class PzNavItem {
  const PzNavItem(this.label, this.icon, {this.badge = 0});
  final String label;
  final IconData icon;
  final int badge;
}

/// Flat bottom navigation: thin icons, a 2 px active rule, no bubbles.
class PzBottomNav extends StatelessWidget {
  const PzBottomNav({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
    this.dark = false,
  });
  final List<PzNavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  final bool dark;

  Color _color(bool active) => active
      ? (dark ? const Color(0xFF7FA8F0) : Pz.blue)
      : (dark ? const Color(0xFF8595A8) : Pz.steel);

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: dark ? Pz.dark : Pz.card,
          border: Border(top: BorderSide(color: dark ? Pz.lineDark : Pz.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: Semantics(
                      selected: i == index,
                      button: true,
                      label: items[i].label,
                      child: InkWell(
                        onTap: () => onTap(i),
                        child: Stack(
                          children: [
                            Align(
                              alignment: Alignment.topCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: i == index ? 28 : 0,
                                height: 2,
                                color: Pz.blue,
                              ),
                            ),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Badge(
                                    isLabelVisible: items[i].badge > 0,
                                    backgroundColor: Pz.review,
                                    textStyle: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: Pz.tabular),
                                    label: Text('${items[i].badge}'),
                                    child: Icon(items[i].icon,
                                        size: 22, color: _color(i == index)),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(items[i].label,
                                      style: TextStyle(
                                        fontSize: 11,
                                        letterSpacing: .2,
                                        fontWeight: i == index
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: _color(i == index),
                                      )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}
