import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// The classic three dots, staggered so they read as presence rather than
/// noise — the `typing-indicator` element.
class AssistantTypingIndicator extends StatefulWidget {
  const AssistantTypingIndicator({
    super.key,
    this.dotSize = 6,
    this.spacing = 4,
    this.period = const Duration(milliseconds: 1100),
  });

  final double dotSize;
  final double spacing;
  final Duration period;

  @override
  State<AssistantTypingIndicator> createState() =>
      _AssistantTypingIndicatorState();
}

class _AssistantTypingIndicatorState extends State<AssistantTypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return SizedBox(
      height: widget.dotSize * 2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < 3; i++) ...<Widget>[
              if (i > 0) SizedBox(width: widget.spacing),
              _Dot(
                size: widget.dotSize,
                color: theme.mutedForeground,
                // Each dot peaks a third of a period after the previous one.
                opacity: _opacityFor(i / 3),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _opacityFor(double offset) {
    final double phase = (_controller.value + offset) % 1.0;
    // Fade in over the first half, out over the second.
    final double wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return 0.25 + 0.75 * math.min(1, math.max(0, wave));
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color, required this.opacity});

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      );
}

/// Live status line naming what the agent is doing, with elapsed time — the
/// `thinking-indicator` element.
class AssistantThinkingIndicator extends StatefulWidget {
  const AssistantThinkingIndicator({
    super.key,
    required this.label,
    this.startedAt,
    this.shimmer = true,
  });

  /// For example "Searching the web" or "Running get_weather".
  final String label;

  /// When the step started; elapsed seconds tick from here.
  final DateTime? startedAt;

  final bool shimmer;

  @override
  State<AssistantThinkingIndicator> createState() =>
      _AssistantThinkingIndicatorState();
}

class _AssistantThinkingIndicatorState extends State<AssistantThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final double elapsed = widget.startedAt == null
            ? 0
            : DateTime.now().difference(widget.startedAt!).inMilliseconds / 1000;
        final double t = _controller.value;
        final double sweep = (t * 2 - 0.5).clamp(0.0, 1.0);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ShaderMask(
              shaderCallback: (Rect bounds) => LinearGradient(
                colors: <Color>[
                  theme.mutedForeground,
                  theme.foreground,
                  theme.mutedForeground,
                ],
                stops: <double>[
                  (sweep - 0.3).clamp(0.0, 1.0),
                  sweep,
                  (sweep + 0.3).clamp(0.0, 1.0),
                ],
              ).createShader(bounds),
              child: Text(
                widget.label,
                style: theme.small(context).copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (widget.startedAt != null) ...<Widget>[
              const SizedBox(width: 8),
              Text(
                '${elapsed.toStringAsFixed(1)}s',
                style: theme.small(context).copyWith(
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Placeholder shown while the model has produced nothing yet — the
/// `loading-state` element, drawn as a pulsing matrix instead of a spinner.
class AssistantLoadingState extends StatefulWidget {
  const AssistantLoadingState({
    super.key,
    this.cellSize = 5,
    this.spacing = 4,
    this.label = 'Generating',
  });

  final double cellSize;
  final double spacing;

  /// The caption under the matrix; the live element carries one.
  final String? label;

  @override
  State<AssistantLoadingState> createState() => _AssistantLoadingStateState();
}

class _AssistantLoadingStateState extends State<AssistantLoadingState>
    with SingleTickerProviderStateMixin {
  // The live element is a three-by-three matrix of round cells that a wave
  // walks through, with its caption underneath.
  static const int _columns = 3;
  static const int _rows = 3;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int row = 0; row < _rows; row++)
            Padding(
              padding: EdgeInsets.only(top: row == 0 ? 0 : widget.spacing),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (int column = 0; column < _columns; column++)
                    Padding(
                      padding: EdgeInsets.only(
                        left: column == 0 ? 0 : widget.spacing,
                      ),
                      child: _cell(theme, row * _columns + column),
                    ),
                ],
              ),
            ),
          if (widget.label != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: _columns * widget.cellSize + (_columns - 1) * widget.spacing,
                child: Text(
                  widget.label!,
                  textAlign: TextAlign.center,
                  style: theme.small(context).copyWith(
                    color: theme.mutedForeground,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(AssistantTheme theme, int index) {
    final double wave = (_controller.value * _rows * _columns - index).abs();
    final double opacity = (1 - (wave / 3)).clamp(0.15, 1.0);
    return Opacity(
      opacity: opacity,
      child: Container(
        width: widget.cellSize,
        height: widget.cellSize,
        decoration: BoxDecoration(
          color: theme.mutedForeground,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
