import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// How a chart draws its points.
enum ChartVariant { area, line, bars }

/// A sparkline with a headline figure: area, line or bars — the `chart`
/// element.
class AssistantChart extends StatelessWidget {
  const AssistantChart({
    super.key,
    required this.label,
    required this.value,
    required this.points,
    required this.visibleCount,
    this.delta,
    this.variant = ChartVariant.area,
    this.height = 88,
  });

  final String label;

  /// Headline figure, pre-formatted.
  final String value;

  final List<double> points;

  /// How many points have been revealed, in order.
  final int visibleCount;

  /// Trend label; a leading `-`, `−` or `–` renders it as a drop.
  final String? delta;

  final ChartVariant variant;
  final double height;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color blue =
        dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
    final Color red =
        dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    final Color green =
        dark ? const Color(0xFF34D399) : const Color(0xFF059669);
    final String? trend = delta;
    final bool falling =
        trend != null && RegExp(r'^\s*[-−–]').hasMatch(trend);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      label,
                      style: auiMono(context, color: auiFg(theme, 0.35)),
                    ),
                  ),
                  if (trend != null)
                    Text(
                      trend,
                      style: auiMono(
                        context,
                        color: falling ? red : green,
                      ).copyWith(
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  height: 1.1,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.4,
                  color: theme.foreground,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: '$label: $value',
                child: SizedBox(
                  height: height,
                  child: CustomPaint(
                    painter: AuiChartPainter(
                      points: points,
                      visibleCount: visibleCount,
                      variant: variant,
                      line: blue,
                      area: blue.withValues(alpha: dark ? 0.15 : 0.12),
                      muted: auiFg(theme, 0.25),
                      baseline: auiFg(theme, 0.08),
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
}

/// Paints the chart; the geometry mirrors upstream's SVG viewBox (300 × 88,
/// 6px padding) stretched to the box width.
class AuiChartPainter extends CustomPainter {
  AuiChartPainter({
    required this.points,
    required this.visibleCount,
    required this.variant,
    required this.line,
    required this.area,
    required this.muted,
    required this.baseline,
  });

  final List<double> points;
  final int visibleCount;
  final ChartVariant variant;
  final Color line;
  final Color area;
  final Color muted;
  final Color baseline;

  static const double _viewWidth = 300;
  static const double _viewHeight = 88;
  static const double _pad = 6;

  double _y(double value, double min, double span) =>
      _viewHeight -
      _pad -
      ((value - min) / span) * (_viewHeight - _pad * 2);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0) return;
    final double scaleX = size.width / _viewWidth;
    final double scaleY = size.height / _viewHeight;

    double max = 1;
    double min = 0;
    for (final double point in points) {
      max = math.max(max, point);
      min = math.min(min, point);
    }
    final double span = max - min == 0 ? 1 : max - min;
    final double step = points.length > 1
        ? (_viewWidth - _pad * 2) / (points.length - 1)
        : 0;
    final int shown = visibleCount.clamp(1, points.length);

    canvas.drawLine(
      Offset(0, (_viewHeight - _pad) * scaleY),
      Offset(size.width, (_viewHeight - _pad) * scaleY),
      Paint()
        ..color = baseline
        ..strokeWidth = 1,
    );

    Offset at(int index) => Offset(
          (_pad + index * step) * scaleX,
          _y(points[index], min, span) * scaleY,
        );

    if (variant == ChartVariant.bars) {
      final double barWidth = math.max(2, step * 0.55) * scaleX;
      final Paint fill = Paint();
      for (int i = 0; i < shown; i++) {
        final Offset point = at(i);
        final double top = point.dy;
        final double bottom = (_viewHeight - _pad) * scaleY;
        fill.color = i == shown - 1 ? line : muted;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(
              point.dx - barWidth / 2,
              top,
              point.dx + barWidth / 2,
              math.max(top + 1, bottom),
            ),
            const Radius.circular(1.5),
          ),
          fill,
        );
      }
      return;
    }

    final Path path = Path()..moveTo(at(0).dx, at(0).dy);
    for (int i = 1; i < shown; i++) {
      path.lineTo(at(i).dx, at(i).dy);
    }
    if (variant == ChartVariant.area && shown > 1) {
      final Path filled = Path.from(path)
        ..lineTo(at(shown - 1).dx, (_viewHeight - _pad) * scaleY)
        ..lineTo(at(0).dx, (_viewHeight - _pad) * scaleY)
        ..close();
      canvas.drawPath(filled, Paint()..color = area);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.75
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(at(shown - 1), 3, Paint()..color = line);
  }

  @override
  bool shouldRepaint(AuiChartPainter oldDelegate) =>
      oldDelegate.visibleCount != visibleCount ||
      oldDelegate.variant != variant ||
      oldDelegate.points != points ||
      oldDelegate.line != line;
}
