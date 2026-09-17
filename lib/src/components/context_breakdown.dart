import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One slice of the context window.
@immutable
class ContextSegment {
  const ContextSegment({
    required this.label,
    required this.tokens,
    required this.tint,
  });

  final String label;
  final int tokens;

  /// Bar and dot color; the host picks it, as upstream takes a class.
  final Color tint;
}

/// How the context window is spent, with the headroom left — the
/// `context-breakdown` element.
class AssistantContextBreakdown extends StatelessWidget {
  const AssistantContextBreakdown({
    super.key,
    required this.segments,
    required this.limit,
  });

  final List<ContextSegment> segments;

  /// Window size in tokens; zero means unknown.
  final int limit;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final int used = segments.fold<int>(
      0,
      (int sum, ContextSegment segment) => sum + segment.tokens,
    );
    final double pressure = limit == 0 ? 0 : used / limit;
    final int headroom = math.max(0, limit - used);

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
                      'Context',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: theme.foreground,
                      ),
                    ),
                  ),
                  Text(
                    '${_fmt(used)} / ${_fmt(limit)}',
                    style: auiMono(
                      context,
                      color: pressure > 0.85
                          ? (dark
                              ? const Color(0xFFFBBF24)
                              : const Color(0xFFD97706))
                          : auiFg(theme, 0.35),
                    ).copyWith(
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 8,
                  color: auiFg(theme, 0.06),
                  child: LayoutBuilder(
                    builder: (
                      BuildContext context,
                      BoxConstraints constraints,
                    ) {
                      final double full = constraints.maxWidth;
                      double usedWidth = 0;
                      final List<Widget> bars = <Widget>[];
                      for (final ContextSegment segment in segments) {
                        final double width = limit == 0
                            ? 0
                            : full * segment.tokens / limit;
                        if (width.round() <= 0) continue;
                        final double clamped =
                            math.min(width, full - usedWidth);
                        if (clamped <= 0) continue;
                        usedWidth += clamped;
                        bars.add(
                          SizedBox(
                            width: clamped,
                            child: Semantics(
                              label: '${segment.label} context usage',
                              value: '${segment.tokens} of $limit',
                              child: ColoredBox(color: segment.tint),
                            ),
                          ),
                        );
                      }
                      return Row(children: bars);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final ContextSegment segment in segments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: segment.tint,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          segment.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.2,
                            color: auiFg(theme, 0.7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _fmt(segment.tokens),
                        style: auiMono(context, color: auiFg(theme, 0.35))
                            .copyWith(
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: <Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: auiFg(theme, 0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Headroom',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.2,
                        color: auiFg(theme, 0.35),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _fmt(headroom),
                    style: auiMono(context, color: auiFg(theme, 0.25)).copyWith(
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Upstream formats with `toLocaleString("en-US")`.
  static String _fmt(int value) {
    final String digits = value.abs().toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return value < 0 ? '-$out' : out.toString();
  }
}
