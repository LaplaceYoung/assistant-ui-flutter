import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One model's share of a run's cost.
@immutable
class CostLine {
  const CostLine({
    required this.model,
    required this.inputTokens,
    required this.outputTokens,
    required this.cost,
    required this.share,
  });

  final String model;
  final int inputTokens;
  final int outputTokens;

  /// Pre-formatted, e.g. `$0.0042` — formatting is the host's call.
  final String cost;

  /// Fraction of the run, 0..1.
  final double share;
}

/// What this run cost, split by model — the `cost-meter` element.
class AssistantCostMeter extends StatelessWidget {
  const AssistantCostMeter({
    super.key,
    required this.runCost,
    required this.sessionCost,
    required this.lines,
  });

  final String runCost;
  final String sessionCost;
  final List<CostLine> lines;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    // Note: tailwind blue-500 / blue-400 and the 55% step between segments;
    // the theme carries no blue token.
    final Color blue =
        dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);

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
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: <Widget>[
                  // The run figure keeps its size; the two labels give way
                  // first when the bubble is narrow.
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Text(
                          runCost,
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
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'this run',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: auiMono(context, color: auiFg(theme, 0.3)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$sessionCost session',
                    style: auiMono(context, color: auiFg(theme, 0.35))
                        .copyWith(
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
                  height: 6,
                  color: auiFg(theme, 0.06),
                  child: LayoutBuilder(
                    builder: (
                      BuildContext context,
                      BoxConstraints constraints,
                    ) {
                      final double full = constraints.maxWidth;
                      double used = 0;
                      final List<Widget> segments = <Widget>[];
                      for (final (int index, CostLine line) in lines.indexed) {
                        if (line.share <= 0) continue;
                        // Upstream widths are absolute percentages of the
                        // track; clamping keeps a host that over-allocates
                        // from tripping a flex overflow.
                        final double width =
                            math.min(full * line.share, full - used);
                        if (width <= 0) continue;
                        used += width;
                        segments.add(
                          SizedBox(
                            width: width,
                            child: Semantics(
                              label: '${line.model} cost share',
                              value: '${(line.share * 100).round()}%',
                              child: ColoredBox(
                                color: switch (index) {
                                  0 => blue,
                                  1 => blue.withValues(alpha: 0.55),
                                  _ => auiFg(theme, 0.25),
                                },
                              ),
                            ),
                          ),
                        );
                      }
                      return Row(children: segments);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (final CostLine line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          line.model,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.2,
                            color: auiFg(theme, 0.75),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${_k(line.inputTokens)} in · '
                          '${_k(line.outputTokens)} out',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: auiMono(context, color: auiFg(theme, 0.25))
                              .copyWith(
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        line.cost,
                        style: auiMono(context, color: auiFg(theme, 0.55))
                            .copyWith(
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Upstream renders `(tokens / 1000).toFixed(1)`, so 1250 → `1.3`.
  static String _k(int tokens) => '${(tokens / 1000).toStringAsFixed(1)}k';
}
