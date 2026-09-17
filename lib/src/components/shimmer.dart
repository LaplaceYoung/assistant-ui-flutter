import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A moving highlight band over whatever it wraps — the `tw-shimmer` effect.
///
/// The parameters mirror the CSS utility: the band travels across a track of
/// [trackWidth] at [speed] pixels per second, slanted by [angle], with the
/// gradient [spread] wide relative to the track height, then waits
/// [repeatDelay] before the next sweep.
class AssistantShimmer extends StatefulWidget {
  const AssistantShimmer({
    super.key,
    required this.child,
    this.angle = 15,
    this.speed = 400,
    this.spread = 120,
    this.trackHeight = 200,
    this.trackWidth,
    this.repeatDelay,
    this.baseColor,
    this.highlightColor,
    this.enabled = true,
  });

  final Widget child;

  /// The band's slant, in degrees.
  final double angle;

  /// Pixels per second.
  final double speed;

  /// The gradient's width along the band.
  final double spread;

  final double trackHeight;

  /// Defaults to the widget's own width.
  final double? trackWidth;

  /// Pause between sweeps; defaults to the CSS utility's ratio.
  final Duration? repeatDelay;

  /// The surface the highlight travels over.
  final Color? baseColor;

  /// The highlight itself.
  final Color? highlightColor;

  /// Set false to render the child unchanged (reduced-motion hosts).
  final bool enabled;

  @override
  State<AssistantShimmer> createState() => _AssistantShimmerState();
}

class _AssistantShimmerState extends State<AssistantShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycle)
      ..repeat();
  }

  @override
  void didUpdateWidget(AssistantShimmer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.speed != widget.speed ||
        oldWidget.repeatDelay != widget.repeatDelay ||
        oldWidget.trackHeight != widget.trackHeight ||
        oldWidget.spread != widget.spread ||
        oldWidget.trackWidth != widget.trackWidth) {
      _controller
        ..duration = _cycle
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The band's travel plus the pause that follows it, in CSS terms.
  Duration get _cycle {
    final double delayMs = widget.repeatDelay?.inMilliseconds.toDouble() ??
        (20000 / _speed).clamp(200, 4000).toDouble();
    return Duration(milliseconds: (_activeMs + delayMs).round());
  }

  /// The gradient's width across the track: the spread plus the angle's rise.
  double get _gradientWidth =>
      widget.spread + widget.trackHeight * math.tan(widget.angle * math.pi / 180);

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final Color highlight = widget.highlightColor ??
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);
    final Color base = widget.baseColor ?? Colors.transparent;

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double track = _track;
        final double travel = track + _gradientWidth;
        // The sweep fills the active part of the cycle; the rest is the pause,
        // so the band waits off-screen before the next pass.
        final double elapsedMs = _controller.value * _cycle.inMilliseconds;
        final double progress =
            elapsedMs >= _activeMs ? 0 : (elapsedMs / _activeMs).clamp(0.0, 1.0);
        // The band starts fully off the left edge and ends past the right one.
        final double center = -_gradientWidth + travel * progress;
        final double halfBand = (_gradientWidth / 2) / track;
        final double centerNorm = center / track;
        final double begin = (centerNorm - halfBand) * 2 - 1;
        final double end = (centerNorm + halfBand) * 2 - 1;

        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (Rect bounds) => LinearGradient(
            begin: Alignment(begin, 0),
            end: Alignment(end, 0),
            colors: <Color>[base, highlight, base],
            stops: const <double>[0, 0.5, 1],
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }

  /// The distance the band travels: the widget's own width when the host did
  /// not give one.
  double get _track => widget.trackWidth ?? widget.trackHeight;

  /// How long one sweep takes, in milliseconds.
  double get _activeMs => _travel / _speed * 1000;

  double get _speed => widget.speed <= 0 ? 400 : widget.speed;

  double get _travel => _track + _gradientWidth;
}

/// A skeleton block with the shimmer over it, for loading placeholders.
class AssistantShimmerBox extends StatelessWidget {
  const AssistantShimmerBox({
    super.key,
    this.width = double.infinity,
    this.height = 12,
    this.radius = 6,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final Color base = Theme.of(context).dividerColor.withValues(alpha: 0.4);
    return AssistantShimmer(
      trackHeight: height * 2,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}
