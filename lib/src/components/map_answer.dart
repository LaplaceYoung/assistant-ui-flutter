import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// A place on the map.
@immutable
class MapPin {
  const MapPin({
    required this.id,
    required this.label,
    required this.detail,
    required this.x,
    required this.y,
  });

  final String id;
  final String label;

  /// Right-aligned note in the list, e.g. the distance.
  final String detail;

  /// Position in percent of the map area.
  final double x;
  final double y;
}

/// A map with pins, an optional dashed route and the pin list — the
/// `map-answer` element.
class AssistantMapAnswer extends StatelessWidget {
  const AssistantMapAnswer({
    super.key,
    required this.pins,
    required this.activeId,
    this.route = false,
    this.onSelect,
  });

  final List<MapPin> pins;

  /// Pin drawn in the strong blue and highlighted in the list.
  final String activeId;

  /// Draws the dashed path through the pins, in order.
  final bool route;

  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color blue =
        dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                height: 160,
                color: auiFieldColor(theme),
                child: LayoutBuilder(
                  builder: (
                    BuildContext context,
                    BoxConstraints constraints,
                  ) {
                    final double width = constraints.maxWidth;
                    final double height = constraints.maxHeight;
                    return Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _MapPainter(
                              grid: auiFg(theme, 0.06),
                              pins: pins,
                              route: route,
                              routeColor: blue.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                        for (final MapPin pin in pins)
                          Positioned(
                            left: pin.x.clamp(0, 100) / 100 * width - 12,
                            top: pin.y.clamp(0, 100) / 100 * height - 12,
                            child: _Pin(
                              pin: pin,
                              active: pin.id == activeId,
                              onSelect: onSelect,
                              dark: dark,
                              blue: blue,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              for (final MapPin pin in pins)
                _PinRow(
                  pin: pin,
                  active: pin.id == activeId,
                  onSelect: onSelect,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({
    required this.pin,
    required this.active,
    required this.onSelect,
    required this.dark,
    required this.blue,
  });

  final MapPin pin;
  final bool active;
  final ValueChanged<String>? onSelect;
  final bool dark;
  final Color blue;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Semantics(
      label: pin.label,
      selected: active,
      button: onSelect != null,
      child: GestureDetector(
        onTap: onSelect == null ? null : () => onSelect!(pin.id),
        child: SizedBox(
          width: 24,
          height: 24,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: active ? 14 : 10,
              height: active ? 14 : 10,
              decoration: BoxDecoration(
                color: active ? blue : auiFg(theme, 0.45),
                shape: BoxShape.circle,
                border: Border.all(color: theme.background, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinRow extends StatelessWidget {
  const _PinRow({
    required this.pin,
    required this.active,
    required this.onSelect,
  });

  final MapPin pin;
  final bool active;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return _HoverRow(
      onTap: onSelect == null ? null : () => onSelect!(pin.id),
      active: active,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Expanded(
            child: Text(
              pin.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                color: auiFg(theme, 0.85),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            pin.detail,
            style: auiMono(context, color: auiFg(theme, 0.3)),
          ),
        ],
      ),
    );
  }
}

class _HoverRow extends StatefulWidget {
  const _HoverRow({
    required this.child,
    required this.onTap,
    required this.active,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool active;

  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: widget.active
                ? auiFg(theme, 0.03)
                : (_hovered && widget.onTap != null
                    ? auiFg(theme, 0.02)
                    : null),
            border: Border(top: BorderSide(color: auiFg(theme, 0.06))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: widget.child,
        ),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter({
    required this.grid,
    required this.pins,
    required this.route,
    required this.routeColor,
  });

  final Color grid;
  final List<MapPin> pins;
  final bool route;
  final Color routeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..color = grid
      ..strokeWidth = 0.6;
    for (final double y in <double>[18, 42, 66, 88]) {
      canvas.drawLine(
        Offset(0, y / 100 * size.height),
        Offset(size.width, y / 100 * size.height),
        line,
      );
    }
    for (final double x in <double>[22, 50, 74]) {
      canvas.drawLine(
        Offset(x / 100 * size.width, 0),
        Offset(x / 100 * size.width, size.height),
        line,
      );
    }
    if (!route || pins.length < 2) return;
    // Upstream draws `stroke-dasharray: 3 2`; Flutter has no dashed stroke, so
    // the segments are emitted by hand.
    final Paint dashed = Paint()
      ..color = routeColor
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < pins.length - 1; i++) {
      final Offset a = Offset(
        pins[i].x / 100 * size.width,
        pins[i].y / 100 * size.height,
      );
      final Offset b = Offset(
        pins[i + 1].x / 100 * size.width,
        pins[i + 1].y / 100 * size.height,
      );
      final double length = (b - a).distance;
      if (length == 0) continue;
      final Offset step = (b - a) / length;
      double drawn = 0;
      while (drawn < length) {
        final double dash = drawn + 3 <= length ? 3 : length - drawn;
        canvas.drawLine(a + step * drawn, a + step * (drawn + dash), dashed);
        drawn += 5;
      }
    }
  }

  @override
  bool shouldRepaint(_MapPainter oldDelegate) =>
      oldDelegate.pins != pins || oldDelegate.route != route;
}
