import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/energy_report.dart';

/// Rounded bar chart; tap or drag to select a bar.
class EnergyBarChart extends StatefulWidget {
  const EnergyBarChart({required this.report, super.key});

  final EnergyReport report;

  @override
  State<EnergyBarChart> createState() => _EnergyBarChartState();
}

class _EnergyBarChartState extends State<EnergyBarChart> {
  int? _selected;

  @override
  void didUpdateWidget(EnergyBarChart old) {
    super.didUpdateWidget(old);
    if (old.report.range != widget.report.range) _selected = null;
  }

  int get _defaultIndex {
    // Latest bucket that has started.
    final now = DateTime.now();
    final points = widget.report.points;
    for (var i = points.length - 1; i >= 0; i--) {
      if (!points[i].start.isAfter(now)) return i;
    }
    return max(0, points.length - 1);
  }

  void _select(Offset position, double width) {
    final count = widget.report.points.length;
    if (count == 0) return;
    final index = (position.dx / width * count).floor().clamp(0, count - 1).toInt();
    if (index != _selected) {
      HapticFeedback.selectionClick();
      setState(() => _selected = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = widget.report.points;
    if (points.isEmpty) return const SizedBox(height: 220);

    final index = min(_selected ?? _defaultIndex, points.length - 1);
    final point = points[index];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: '${point.kwh.toStringAsFixed(2)} kWh',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            children: [
              TextSpan(
                text: '  ·  ${bucketLabel(widget.report.range, point.start)}',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _select(d.localPosition, constraints.maxWidth),
            onHorizontalDragUpdate: (d) => _select(d.localPosition, constraints.maxWidth),
            child: Semantics(
              label: 'Energy chart, ${points.length} bars',
              child: CustomPaint(
                size: Size(constraints.maxWidth, 200),
                painter: _BarsPainter(
                  points: points,
                  range: widget.report.range,
                  selected: index,
                  labelStyle: theme.textTheme.labelSmall!.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  trackColor: theme.colorScheme.surfaceContainer,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// "14:00", "Wed 5 Nov".
String bucketLabel(EnergyRange range, DateTime start) => range == EnergyRange.day
    ? '${Formatters.time(start)}–${Formatters.two((start.hour + 1) % 24)}:00'
    : Formatters.day(start);

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.points,
    required this.range,
    required this.selected,
    required this.labelStyle,
    required this.trackColor,
  });

  final List<EnergyPoint> points;
  final EnergyRange range;
  final int selected;
  final TextStyle labelStyle;
  final Color trackColor;

  static const _labelHeight = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    final peak = points.fold<double>(0, (m, p) => max(m, p.kwh));
    final chartHeight = size.height - _labelHeight;
    final slot = size.width / points.length;
    final barWidth = min(slot * 0.6, 28.0);

    for (var i = 0; i < points.length; i++) {
      final x = slot * i + (slot - barWidth) / 2;
      final radius = Radius.circular(barWidth / 2);

      // Faint full-height track behind every bar.
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, 0, barWidth, chartHeight), radius),
        Paint()..color = trackColor,
      );

      final ratio = peak == 0 ? 0.0 : points[i].kwh / peak;
      final height = max(ratio * chartHeight, points[i].kwh > 0 ? barWidth : 0.0);
      if (height > 0) {
        final rect = Rect.fromLTWH(x, chartHeight - height, barWidth, height);
        final paint = Paint()
          ..shader = (i == selected
                  ? AppColors.activeGradient
                  : LinearGradient(
                      colors: [
                        AppColors.cyan400.withValues(alpha: 0.45),
                        AppColors.brand.withValues(alpha: 0.30),
                      ],
                    ))
              .createShader(rect);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
      }

      final label = _label(i);
      if (label != null) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        painter.paint(
          canvas,
          Offset(slot * i + (slot - painter.width) / 2, chartHeight + 6),
        );
      }
    }
  }

  /// Sparse x-axis labels so they never overlap.
  String? _label(int i) {
    final start = points[i].start;
    return switch (range) {
      EnergyRange.day => start.hour % 6 == 0 ? Formatters.two(start.hour) : null,
      EnergyRange.week => Formatters.weekdayLetters[start.weekday - 1],
      EnergyRange.month => i % 5 == 0 || i == points.length - 1 ? '${start.day}' : null,
    };
  }

  @override
  bool shouldRepaint(_BarsPainter old) =>
      old.points != points || old.selected != selected || old.labelStyle != labelStyle;
}
