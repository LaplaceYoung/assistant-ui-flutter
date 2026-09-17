import 'package:flutter/material.dart';

import 'theme.dart';

/// Shape of an icon control. Upstream uses 8px radii for action bars and full
/// circles for composer controls.
enum AssistantIconButtonShape { roundedSquare, circle }

/// Accessible icon button with a tooltip and a hover-only background — the
/// `tooltip-icon-button` element.
///
/// Sizes follow upstream: 32px controls with a 6-8px radius in action bars,
/// 36px circular controls in composers.
class AssistantTooltipIconButton extends StatefulWidget {
  const AssistantTooltipIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.size = 32,
    this.iconSize = 16,
    this.shape = AssistantIconButtonShape.roundedSquare,
    this.radius = 8,
    this.foregroundColor,
    this.backgroundColor,
    this.hoverColor,
    this.disabledColor,
    this.badge,
  });

  final IconData icon;

  /// Also the semantics label; pass an empty string for purely decorative
  /// buttons.
  final String tooltip;

  /// Null disables the button: no hover state, no pointer.
  final VoidCallback? onPressed;

  final double size;
  final double iconSize;
  final AssistantIconButtonShape shape;
  final double radius;

  final Color? foregroundColor;
  final Color? backgroundColor;
  final Color? hoverColor;
  final Color? disabledColor;

  /// Optional overlay, for example a small count.
  final Widget? badge;

  @override
  State<AssistantTooltipIconButton> createState() =>
      _AssistantTooltipIconButtonState();
}

class _AssistantTooltipIconButtonState
    extends State<AssistantTooltipIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool enabled = widget.onPressed != null;
    final Color foreground = !enabled
        ? (widget.disabledColor ?? theme.border)
        : (widget.foregroundColor ?? theme.mutedForeground);
    final Color? hoverBackground = !enabled
        ? null
        : (widget.hoverColor ??
            (theme.brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.black.withValues(alpha: 0.07)));
    final Color background = widget.backgroundColor ?? Colors.transparent;

    final Widget button = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _hovered && enabled ? hoverBackground : background,
            borderRadius: widget.shape == AssistantIconButtonShape.circle
                ? BorderRadius.circular(widget.size / 2)
                : BorderRadius.circular(widget.radius),
          ),
          child: widget.badge == null
              ? Icon(widget.icon, size: widget.iconSize, color: foreground)
              : Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Icon(widget.icon, size: widget.iconSize, color: foreground),
                    Positioned(right: -4, top: -4, child: widget.badge!),
                  ],
                ),
        ),
      ),
    );

    if (widget.tooltip.isEmpty) return button;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: button,
    );
  }
}
