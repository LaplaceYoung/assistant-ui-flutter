import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One step the agent took on the screen.
@immutable
class ComputerStep {
  const ComputerStep({
    required this.id,
    required this.action,
    required this.target,
    required this.x,
    required this.y,
  });

  final String id;
  final String action;
  final String target;

  /// Cursor position as a percentage of the screen area.
  final double x;
  final double y;
}

/// A screen the agent is driving, with where its cursor has been — the
/// `computer-use` element.
class AssistantComputerUse extends StatelessWidget {
  const AssistantComputerUse({
    super.key,
    required this.url,
    required this.steps,
    required this.activeIndex,
    this.screen,
  });

  final String url;
  final List<ComputerStep> steps;

  /// Which step is in flight; out-of-range values clamp.
  final int activeIndex;

  /// The screen itself: an image, a live view, anything.
  final Widget? screen;

  /// Upstream's `min-h-[8.5rem]`.
  static const double _minScreenHeight = 136;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color blue =
        dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
    final int index = steps.isEmpty ? -1 : activeIndex.clamp(0, steps.length - 1);
    final ComputerStep? active = index < 0 ? null : steps[index];
    // The cursor's trail: the active step plus the two before it.
    final List<ComputerStep> trail = index < 0
        ? const <ComputerStep>[]
        : steps.sublist(index >= 3 ? index - 2 : 0, index + 1);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 448),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: <Widget>[
                    for (final Color tint in <Color>[
                      const Color(0xFFEF4444),
                      const Color(0xFFF59E0B),
                      const Color(0xFF10B981),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: tint.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        decoration: auiField(theme, radius: 999),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: Text(
                          url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: auiMono(context, color: auiFg(theme, 0.45)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                constraints:
                    const BoxConstraints(minHeight: _minScreenHeight),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: auiFg(theme, 0.07)),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    // The screen sets the height; the cursor percentages are
                    // resolved against whatever that turns out to be.
                    final double width = constraints.maxWidth;
                    final double height =
                        constraints.hasBoundedHeight && constraints.maxHeight > 0
                            ? math.max(constraints.maxHeight, _minScreenHeight)
                            : _minScreenHeight;
                    return Stack(
                      children: <Widget>[
                        screen ?? const SizedBox(height: _minScreenHeight),
                        for (final (int i, ComputerStep step) in trail.indexed)
                          Positioned(
                            left: step.x.clamp(0, 100) / 100 * width - 4,
                            top: step.y.clamp(0, 100) / 100 * height - 4,
                            child: Opacity(
                              opacity: 0.18 * (i + 1),
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: blue,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        if (active != null)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOut,
                            left: active.x.clamp(0, 100) / 100 * width,
                            top: active.y.clamp(0, 100) / 100 * height,
                            child: Icon(Icons.mouse, size: 16, color: blue),
                          ),
                      ],
                    );
                  },
                ),
              ),
              if (active != null)
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: auiFg(theme, 0.07)),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    children: <Widget>[
                      Text(
                        active.action,
                        style: auiMono(context, color: auiFg(theme, 0.55)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          active.target,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            color: auiFg(theme, 0.8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${index + 1}/${steps.length}',
                        style: auiMono(context, color: auiFg(theme, 0.3))
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
}
