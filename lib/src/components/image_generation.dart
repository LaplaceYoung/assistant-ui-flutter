import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// An image being generated, then the result — the `image-generation` element.
///
/// Note: upstream paints its sample with CSS radial gradients written in
/// OKLCH. Those values are converted to the sRGB constants below once, since
/// Flutter has no OKLCH color space.
class AssistantImageGeneration extends StatelessWidget {
  const AssistantImageGeneration({
    super.key,
    required this.prompt,
    this.generating = true,
    this.onRegenerate,
    this.image,
  });

  final String prompt;

  /// While true the dot field pulses and the gradient is still blurred away.
  final bool generating;

  /// Regenerate control; hidden while generating, as upstream does.
  final VoidCallback? onRegenerate;

  /// The finished image; without it the gradient stands in.
  final Widget? image;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return SizedBox(
      width: 208,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              decoration: auiPaper(theme, radius: 16),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: generating ? 0 : 1,
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOut,
                      child: image ?? const _Gradient(),
                    ),
                  ),
                  if (generating)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _DotField(theme: theme),
                      ),
                    ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Text(
                      '1024 × 1024',
                      style: auiMono(
                        context,
                        color: generating
                            ? auiFg(theme, 0.35)
                            : Colors.white.withValues(alpha: 0.7),
                      ).copyWith(
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: generating
                    ? AuiShimmerLabel(
                        text: 'Generating',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: auiFg(theme, 0.45),
                        ),
                      )
                    : Text(
                        prompt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.3,
                          color: auiFg(theme, 0.45),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              if (!generating)
                AuiIconAction(
                  icon: Icons.refresh,
                  label: 'Regenerate image',
                  size: 24,
                  onPressed: onRegenerate,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The stand-in artwork: four radial washes over a vertical gradient.
class _Gradient extends StatelessWidget {
  const _Gradient();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[
            Color(0xFF323A63),
            Color(0xFFE8C29E),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, 1),
                  radius: 1.2,
                  colors: const <Color>[
                    Color(0xFF4A4E86),
                    Color(0x004A4E86),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.7, 0.8),
                  radius: 1.1,
                  colors: const <Color>[
                    Color(0xCC8A5FA8),
                    Color(0x008A5FA8),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.2, -1),
                  radius: 1.3,
                  colors: const <Color>[
                    Color(0xFFEBDCC4),
                    Color(0xE6E09A7E),
                    Color(0x00E09A7E),
                  ],
                  stops: const <double>[0, 0.45, 0.75],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The 8×8 field of dots that pulses while the image is being made.
class _DotField extends StatefulWidget {
  const _DotField({required this.theme});

  final AssistantTheme theme;

  @override
  State<_DotField> createState() => _DotFieldState();
}

class _DotFieldState extends State<_DotField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (BuildContext context, Widget? child) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            for (int row = 0; row < 8; row++)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  for (int col = 0; col < 8; col++)
                    _dot(row, col),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _dot(int row, int col) {
    // Upstream staggers with `animationDelay: (row + col) * 90ms`; the same
    // offset shifts this dot's phase inside the shared loop.
    final double phase = ((row + col) * 90) / 1400;
    final double t = (_pulse.value + phase) % 1;
    final double opacity = 0.25 + 0.55 * (0.5 - (t - 0.5).abs()) * 2;
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: auiFg(widget.theme, math.min(1, opacity)),
        shape: BoxShape.circle,
      ),
    );
  }
}
