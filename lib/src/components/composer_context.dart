import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/runtime_api.dart';
import '../primitives/state.dart';
import 'theme.dart';

/// Composer rail token ring: fills as the conversation grows and warns near
/// the limit — the `composer-context` element.
class AssistantContextRing extends StatelessWidget {
  const AssistantContextRing({
    super.key,
    this.size = 22,
    this.strokeWidth = 2.5,
    this.showLabel = false,
    this.warningColor = const Color(0xFFF5A524),
    this.overColor = const Color(0xFFE5484D),
  });

  final double size;
  final double strokeWidth;
  final bool showLabel;
  final Color warningColor;
  final Color overColor;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return AuiStateBuilder<ContextUsage>(
      selector: (AuiState state) => state.thread.contextUsage,
      builder: (BuildContext context, ContextUsage usage) {
        if (usage.maxTokens <= 0) return const SizedBox.shrink();
        final Color color = usage.isOverLimit
            ? overColor
            : (usage.isNearLimit ? warningColor : theme.mutedForeground);
        return Tooltip(
          message: _describe(usage),
          waitDuration: const Duration(milliseconds: 200),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _RingPainter(
                    ratio: usage.ratio,
                    track: theme.border,
                    color: color,
                    strokeWidth: strokeWidth,
                  ),
                ),
              ),
              if (showLabel) ...<Widget>[
                const SizedBox(width: 6),
                Text(
                  '${(usage.ratio * 100).round()}%',
                  style: theme.small(context).copyWith(
                    fontSize: 11,
                    color: color,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _describe(ContextUsage usage) {
    final String used = _compact(usage.usedTokens);
    final String max = _compact(usage.maxTokens);
    final String percent = (usage.ratio * 100).round().toString();
    final String state = usage.isOverLimit
        ? 'over the window'
        : (usage.isNearLimit ? 'near the limit' : 'used');
    return '$used of $max tokens · $percent% $state';
  }

  static String _compact(int value) {
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return '$value';
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.ratio,
    required this.track,
    required this.color,
    required this.strokeWidth,
  });

  final double ratio;
  final Color track;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (size.shortestSide - strokeWidth) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = track,
    );

    if (ratio <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * ratio,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = strokeWidth
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.ratio != ratio ||
      oldDelegate.color != color ||
      oldDelegate.track != track ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Horizontal variant of the same reading, for a status bar.
class AssistantContextBar extends StatelessWidget {
  const AssistantContextBar({super.key, this.width = 120, this.height = 4});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return AuiStateBuilder<ContextUsage>(
      selector: (AuiState state) => state.thread.contextUsage,
      builder: (BuildContext context, ContextUsage usage) {
        if (usage.maxTokens <= 0) return const SizedBox.shrink();
        final Color color = usage.isOverLimit
            ? const Color(0xFFE5484D)
            : (usage.isNearLimit
                ? const Color(0xFFF5A524)
                : theme.mutedForeground);
        return Tooltip(
          message: AssistantContextRing._describe(usage),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: theme.border,
              borderRadius: BorderRadius.circular(height),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: usage.ratio,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The same usage written out — the live element's third presentation:
/// `112,900 / 128,000`, coloured by the band the ratio sits in.
class AssistantContextText extends StatelessWidget {
  const AssistantContextText({
    super.key,
    this.warningColor = const Color(0xFFF5A524),
    this.overColor = const Color(0xFFE5484D),
    this.showMax = true,
  });

  final Color warningColor;
  final Color overColor;
  final bool showMax;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return AuiStateBuilder<ContextUsage>(
      selector: (AuiState state) => state.thread.contextUsage,
      builder: (BuildContext context, ContextUsage usage) {
        if (usage.maxTokens <= 0) return const SizedBox.shrink();
        final Color color = usage.isOverLimit
            ? overColor
            : (usage.isNearLimit ? warningColor : theme.mutedForeground);
        final String used = _group(usage.usedTokens);
        final String label = showMax
            ? '$used / ${_group(usage.maxTokens)}'
            : used;
        return Text(
          label,
          style: theme.small(context).copyWith(
            fontSize: 11,
            color: color,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        );
      },
    );
  }

  /// `128000` reads as `128,000`.
  static String _group(int value) {
    final String digits = value.abs().toString();
    final StringBuffer out = StringBuffer(value < 0 ? '-' : '');
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }
}
