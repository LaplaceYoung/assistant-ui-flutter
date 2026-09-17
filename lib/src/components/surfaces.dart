import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Fills, borders, text styles and controls shared by the tool, HITL and panel
/// elements — the Dart side of upstream `elements/surfaces.tsx`.
///
/// The values are copied from those class strings: `paper` is
/// `bg-background border-border/60` (dark lifts to `bg-popover`), `field` is
/// `bg-foreground/[0.04]` (dark `[0.06]`), `mono` is 11px tight tracking.

/// Card surface: light sits on the page background, dark lifts one step.
BoxDecoration auiPaper(
  AssistantTheme theme, {
  double radius = 16,
  Color? color,
}) {
  return BoxDecoration(
    color: color ??
        (theme.brightness == Brightness.dark
            ? theme.muted
            : theme.background),
    border: Border.all(color: theme.border.withValues(alpha: 0.6)),
    borderRadius: BorderRadius.circular(radius),
  );
}

/// Inset fill for code blocks, config values, key caps and chips.
Color auiFieldColor(AssistantTheme theme) => theme.foreground.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.06 : 0.04,
    );

/// [auiFieldColor] as a rounded box, for the elements that show one.
BoxDecoration auiField(
  AssistantTheme theme, {
  double radius = 12,
  Color? color,
}) {
  return BoxDecoration(
    color: color ?? auiFieldColor(theme),
    borderRadius: BorderRadius.circular(radius),
  );
}

/// `font-mono text-[11px] tracking-tight`, in the theme's mono family.
TextStyle auiMono(
  BuildContext context, {
  double size = 11,
  Color? color,
  FontWeight? weight,
}) {
  final AssistantTheme theme = AssistantTheme.of(context);
  return theme.code(context).copyWith(
        fontSize: size,
        height: 1.25,
        letterSpacing: -0.2,
        color: color ?? theme.mutedForeground,
        fontWeight: weight,
      );
}

/// Secondary text at a given alpha of the foreground, the way upstream writes
/// `text-foreground/55`.
Color auiFg(AssistantTheme theme, double alpha) =>
    theme.foreground.withValues(alpha: alpha);

/// The rotating `Loader2Icon` upstream pairs with `animate-spin`.
class AuiSpinner extends StatelessWidget {
  const AuiSpinner({super.key, this.size = 13, this.color, this.strokeWidth});

  final double size;
  final Color? color;
  final double? strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth ?? math.max(1.2, size / 9),
        color: color,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}

/// Text with a highlight sweeping across it while [active] — upstream's
/// `ShimmerLabel`, used for in-flight tool timelines and status lines.
class AuiShimmerLabel extends StatefulWidget {
  const AuiShimmerLabel({
    super.key,
    required this.text,
    this.active = true,
    this.style,
  });

  final String text;
  final bool active;
  final TextStyle? style;

  @override
  State<AuiShimmerLabel> createState() => _AuiShimmerLabelState();
}

class _AuiShimmerLabelState extends State<AuiShimmerLabel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(AuiShimmerLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle style = widget.style ?? DefaultTextStyle.of(context).style;
    if (!widget.active) return Text(widget.text, style: style);

    final Color base = style.color ?? const Color(0xFF000000);
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        // A soft band travelling left to right: -1.5 → 1.5 in alignment space.
        final double at = _controller.value * 3 - 1.5;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect bounds) => LinearGradient(
            begin: Alignment(at - 0.6, 0),
            end: Alignment(at + 0.6, 0),
            colors: <Color>[
              base,
              base.withValues(alpha: 0.35),
              base,
            ],
            stops: const <double>[0, 0.5, 1],
          ).createShader(bounds),
          child: child,
        );
      },
      child: Text(widget.text, style: style),
    );
  }
}

/// A shimmering bar for indeterminate work — upstream's `.shimmer-bg`.
class AuiShimmerBar extends StatefulWidget {
  const AuiShimmerBar({
    super.key,
    this.height = 3,
    this.radius = 999,
    this.color,
  });

  final double height;
  final double radius;
  final Color? color;

  @override
  State<AuiShimmerBar> createState() => _AuiShimmerBarState();
}

class _AuiShimmerBarState extends State<AuiShimmerBar>
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
    final Color base = widget.color ?? auiFg(theme, 0.35);
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double at = _controller.value * 3 - 1.5;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (Rect bounds) => LinearGradient(
            begin: Alignment(at - 0.6, 0),
            end: Alignment(at + 0.6, 0),
            colors: <Color>[base, base.withValues(alpha: 0.2), base],
            stops: const <double>[0, 0.5, 1],
          ).createShader(bounds),
          child: child,
        );
      },
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Two labels that swap place with a width animation — upstream's
/// `SwapLabel`. The blur of the outgoing label is dropped: Flutter's
/// `ImageFiltered`-based blur on text at these sizes reads as smudge.
class AuiSwapLabel extends StatelessWidget {
  const AuiSwapLabel({
    super.key,
    required this.active,
    required this.children,
    this.duration = const Duration(milliseconds: 300),
  });

  /// Index of the visible child.
  final int active;
  final List<Widget> children;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.centerLeft,
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (Widget? current, List<Widget> previous) => Stack(
          alignment: Alignment.centerLeft,
          children: <Widget>[...previous, if (current != null) current],
        ),
        child: KeyedSubtree(
          key: ValueKey<int>(active),
          child: children[active],
        ),
      ),
    );
  }
}

/// The two button flavours the HITL cards use: `ghost` for the secondary
/// action, `ink` for the affirmative one.
enum AuiPillButtonVariant { ghost, ink }

/// Pill button with upstream's sizes (32px tall, 14px horizontal padding,
/// 12px w500 label) and press scale.
class AuiPillButton extends StatefulWidget {
  const AuiPillButton({
    super.key,
    required this.label,
    this.icon,
    this.leading,
    this.onPressed,
    this.variant = AuiPillButtonVariant.ghost,
    this.height = 32,
    this.spinnerSize = 12,
    this.padding = 14,
  });

  final String label;
  final IconData? icon;

  /// Takes precedence over [icon]; used when the affordance is mid-flight.
  final Widget? leading;

  /// Null disables the button; the ghost variant drops to 30% opacity.
  final VoidCallback? onPressed;
  final AuiPillButtonVariant variant;
  final double height;
  final double spinnerSize;
  final double padding;

  @override
  State<AuiPillButton> createState() => _AuiPillButtonState();
}

class _AuiPillButtonState extends State<AuiPillButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool enabled = widget.onPressed != null;
    final bool ink = widget.variant == AuiPillButtonVariant.ink;
    final Color label = ink
        ? theme.primaryForeground
        : auiFg(theme, enabled ? (_hovered ? 0.9 : 0.55) : 0.3);
    final Color fill = ink
        ? theme.primary.withValues(alpha: _hovered && enabled ? 0.9 : 1)
        : (_hovered && enabled ? auiFieldColor(theme) : Colors.transparent);

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: widget.height,
            padding: EdgeInsets.symmetric(horizontal: widget.padding),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(widget.height / 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (widget.leading != null) ...<Widget>[
                  widget.leading!,
                  const SizedBox(width: 6),
                ] else if (widget.icon != null) ...<Widget>[
                  Icon(widget.icon, size: widget.spinnerSize, color: label),
                  const SizedBox(width: 6),
                ],
                // The label gives way first: a pill in a narrow host must
                // not push its row over the edge.
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: label,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 24px circular ghost control upstream reuses across elements — its
/// `ghostButton` class: no fill until hover, then `bg-foreground/[0.06]`.
class AuiIconAction extends StatefulWidget {
  const AuiIconAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 24,
  });

  final IconData icon;

  /// Also the semantics label — the control is icon-only.
  final String label;
  final VoidCallback? onPressed;
  final double size;

  @override
  State<AuiIconAction> createState() => _AuiIconActionState();
}

class _AuiIconActionState extends State<AuiIconAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: _hovered && enabled ? auiFg(theme, 0.06) : null,
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.icon,
              size: widget.size * 0.58,
              color: auiFg(theme, _hovered && enabled ? 0.9 : 0.45),
            ),
          ),
        ),
      ),
    );
  }
}
