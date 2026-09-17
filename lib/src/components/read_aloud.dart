import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// Text being read out loud: the spoken word is highlighted, with transport
/// controls — the `read-aloud` element.
class AssistantReadAloud extends StatelessWidget {
  const AssistantReadAloud({
    super.key,
    required this.words,
    required this.spokenIndex,
    required this.elapsed,
    required this.duration,
    this.playing = false,
    this.rate = 1.0,
    this.onToggle,
    this.onRateChange,
  });

  final List<String> words;

  /// Index of the word being spoken; words before it read as done.
  final int spokenIndex;

  /// Pre-formatted times.
  final String elapsed;
  final String duration;

  final bool playing;

  /// Playback speed, rendered as `1.5×`.
  final double rate;

  final VoidCallback? onToggle;

  /// Cycles the rate; without it the control is inert.
  final VoidCallback? onRateChange;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color blue =
        dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
    final double progress = words.isEmpty ? 0 : spokenIndex / words.length;
    final int safeIndex = spokenIndex.clamp(0, math.max(0, words.length - 1));

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  for (final (int index, String word) in words.indexed)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Container(
                        decoration: index == safeIndex
                            ? BoxDecoration(
                                color: blue.withValues(
                                  alpha: dark ? 0.15 : 0.12,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              )
                            : null,
                        child: Text(
                          word,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.5,
                            color: index < spokenIndex
                                ? auiFg(theme, 0.4)
                                : index == safeIndex
                                    ? auiFg(theme, 0.95)
                                    : auiFg(theme, 0.7),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Semantics(
                    button: true,
                    label: playing ? 'Pause' : 'Play',
                    child: GestureDetector(
                      onTap: onToggle,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: auiFg(theme, 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          playing ? Icons.pause : Icons.play_arrow,
                          size: 14,
                          color: auiFg(theme, 0.6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(
                      label: 'Read aloud progress',
                      value: '$elapsed of $duration',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          height: 3,
                          color: auiFg(theme, 0.08),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progress.clamp(0, 1),
                              child: ColoredBox(color: blue),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$elapsed / $duration',
                    style: auiMono(context, color: auiFg(theme, 0.35))
                        .copyWith(
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RateControl(rate: rate, onTap: onRateChange),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.volume_up,
                    size: 14,
                    color: auiFg(theme, 0.25),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RateControl extends StatelessWidget {
  const _RateControl({required this.rate, required this.onTap});

  final double rate;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final String label =
        rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : '$rate';
    return Semantics(
      button: true,
      label: 'Playback speed, currently $label times',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: auiField(theme, radius: 999),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            '$label×',
            style: auiMono(context, color: auiFg(theme, 0.55)),
          ),
        ),
      ),
    );
  }
}
