import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The duration to use for a piece of motion: zero when the platform asks for
/// reduced motion (`prefers-reduced-motion` on web, and the accessibility
/// setting on the other platforms — upstream's `motion-reduce:*`).
Duration auiMotionDuration(BuildContext context, Duration base) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false
        ? Duration.zero
        : base;

/// The entry animation the elements use: `fade-in blur-in-[2px] animate-in
/// duration-300`. Runs once when the widget appears or when [trigger] changes.
class AuiFadeInBlur extends StatefulWidget {
  const AuiFadeInBlur({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
    this.blur = 2,
    this.slideFrom,
    this.trigger,
  });

  final Widget child;
  final Duration duration;

  /// The starting blur radius, in pixels.
  final double blur;

  /// An optional slide-in offset, for `slide-in-from-*` variants.
  final Offset? slideFrom;

  /// Replays the animation whenever this changes.
  final Object? trigger;

  @override
  State<AuiFadeInBlur> createState() => _AuiFadeInBlurState();
}

class _AuiFadeInBlurState extends State<AuiFadeInBlur>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: land on the final state and stay there.
    final bool reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _controller.duration =
        reduced ? Duration.zero : widget.duration;
    if (reduced && _controller.value != 1) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(AuiFadeInBlur oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = auiMotionDuration(context, widget.duration);
    }
    if (oldWidget.trigger != widget.trigger || oldWidget.child != widget.child) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeOut.transform(_controller.value);
        Widget body = child!;
        if (widget.slideFrom != null) {
          final Offset from = widget.slideFrom!;
          body = Transform.translate(
            offset: Offset(from.dx * (1 - t), from.dy * (1 - t)),
            child: body,
          );
        }
        if (widget.blur > 0) {
          body = ImageFiltered(
            imageFilter: ui.ImageFilter.blur(
              sigmaX: widget.blur * (1 - t),
              sigmaY: widget.blur * (1 - t),
            ),
            child: body,
          );
        }
        return Opacity(opacity: t.clamp(0.0, 1.0), child: body);
      },
      child: widget.child,
    );
  }
}

/// The press feedback the elements share: `active:scale-[0.96]` (or 0.98) and
/// an optional hover lift of one pixel, both over 150ms.
class AuiPressable extends StatefulWidget {
  const AuiPressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressedScale = 0.96,
    this.hoverLift = 0,
    this.duration = const Duration(milliseconds: 150),
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedScale;

  /// How far the child rises while hovered, in pixels.
  final double hoverLift;

  final Duration duration;

  @override
  State<AuiPressable> createState() => _AuiPressableState();
}

class _AuiPressableState extends State<AuiPressable> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapCancel: widget.onTap == null
            ? null
            : () => setState(() => _pressed = false),
        onTapUp: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? widget.pressedScale : 1,
          duration: auiMotionDuration(context, widget.duration),
          curve: Curves.easeOut,
          child: AnimatedSlide(
            offset: Offset(0, _hovered && !_pressed ? -widget.hoverLift / 10 : 0),
            duration: auiMotionDuration(context, widget.duration),
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// A bar whose fill animates its width: upstream's
/// `transition-[width] duration-500`.
class AuiAnimatedProgressBar extends StatelessWidget {
  const AuiAnimatedProgressBar({
    super.key,
    required this.value,
    this.height = 4,
    this.duration = const Duration(milliseconds: 500),
    this.color,
    this.track,
  });

  /// 0..1.
  final double value;
  final double height;
  final Duration duration;
  final Color? color;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value, end: value),
      duration: auiMotionDuration(context, duration),
      curve: Curves.easeOut,
      builder: (BuildContext context, double animated, Widget? _) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) =>
            Stack(
          children: <Widget>[
            if (track != null)
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: track,
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            Container(
              height: height,
              width: constraints.maxWidth * animated.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The popover entry: `fade-in zoom-in-95 animate-in duration-150`, the
/// radix-layer default the elements use for tooltips, menus and popovers.
class AuiZoomFadeIn extends StatefulWidget {
  const AuiZoomFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 150),
    this.from = 0.95,
    this.alignment = Alignment.topCenter,
    this.trigger,
  });

  final Widget child;
  final Duration duration;

  /// The starting scale.
  final double from;

  /// Where the zoom grows from: radix transforms from the popover's side.
  final Alignment alignment;

  /// Replays the animation whenever this changes.
  final Object? trigger;

  @override
  State<AuiZoomFadeIn> createState() => _AuiZoomFadeInState();
}

class _AuiZoomFadeInState extends State<AuiZoomFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bool reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced && _controller.value != 1) _controller.value = 1;
  }

  @override
  void didUpdateWidget(AuiZoomFadeIn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = auiMotionDuration(context, widget.duration);
    }
    if (oldWidget.trigger != widget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
        child: ScaleTransition(
          alignment: widget.alignment,
          scale: Tween<double>(begin: widget.from, end: 1).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOut),
          ),
          child: widget.child,
        ),
      );
}

/// Hover colour transitions: `transition-colors duration-150/200`.
class AuiHoverColor extends StatefulWidget {
  const AuiHoverColor({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 150),
    this.onTap,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final Duration duration;
  final VoidCallback? onTap;

  @override
  State<AuiHoverColor> createState() => _AuiHoverColorState();
}

class _AuiHoverColorState extends State<AuiHoverColor> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: widget.onTap == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: auiMotionDuration(context, widget.duration),
            curve: Curves.easeOut,
            child: widget.builder(context, _hovered),
          ),
        ),
      );
}
