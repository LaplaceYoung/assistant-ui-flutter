import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One weighted criterion in an [AssistantScoreBreakdown].
@immutable
class ScoreCriterion {
  const ScoreCriterion({
    required this.label,
    required this.score,
    required this.weight,
    this.note,
  });

  final String label;
  final double score;

  /// Rendered as `×{weight}`.
  final double weight;

  /// Optional explanation under the meter.
  final String? note;
}

/// A weighted score, its verdict and the criteria behind it — the
/// `score-breakdown` element.
class AssistantScoreBreakdown extends StatelessWidget {
  const AssistantScoreBreakdown({
    super.key,
    required this.verdict,
    required this.total,
    required this.outOf,
    required this.criteria,
    required this.visibleCount,
  });

  final String verdict;
  final double total;
  final double outOf;

  /// How many criteria have been revealed so far, in order.
  final int visibleCount;

  final List<ScoreCriterion> criteria;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final double ratio = outOf == 0 ? 0 : total / outOf;
    // Note: tailwind emerald / amber / red at 12% fill with the 700 / 300
    // text steps; the theme's success and destructive tokens are for solid
    // surfaces.
    final (Color fill, Color text) = ratio >= 0.75
        ? (
            (dark ? const Color(0xFF34D399) : const Color(0xFF10B981))
                .withValues(alpha: 0.12),
            dark ? const Color(0xFF6EE7B7) : const Color(0xFF047857),
          )
        : ratio >= 0.5
            ? (
                const Color(0xFFF59E0B).withValues(alpha: 0.12),
                dark ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
              )
            : (
                (dark ? const Color(0xFFF87171) : const Color(0xFFEF4444))
                    .withValues(alpha: 0.12),
                dark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
              );
    final Color blue =
        dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
    final List<ScoreCriterion> shown = criteria.take(visibleCount).toList();

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
                  Text(
                    total.toStringAsFixed(1),
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
                  Text(
                    '/ ${_trim(outOf)}',
                    style: auiMono(context, color: auiFg(theme, 0.3)).copyWith(
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: fill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    child: Text(
                      verdict,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final ScoreCriterion criterion in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              criterion.label,
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
                          Text(
                            '×${_trim(criterion.weight)}',
                            style:
                                auiMono(context, color: auiFg(theme, 0.25)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            criterion.score.toStringAsFixed(1),
                            style: auiMono(
                              context,
                              color: auiFg(theme, 0.55),
                            ).copyWith(
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Semantics(
                        label: '${criterion.label} score',
                        value:
                            '${criterion.score.toStringAsFixed(1)} of ${_trim(outOf)}',
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            height: 3,
                            color: auiFg(theme, 0.06),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: math.max(
                                  0,
                                  math.min(
                                    1,
                                    outOf == 0 ? 0 : criterion.score / outOf,
                                  ),
                                ),
                                child: ColoredBox(color: blue),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (criterion.note != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          criterion.note!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: auiFg(theme, 0.4),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Upstream prints weights and the ceiling with plain `Number` formatting,
  /// so 30.0 reads as `30`.
  static String _trim(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
}
