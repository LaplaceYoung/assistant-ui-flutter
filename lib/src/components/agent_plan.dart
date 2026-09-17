import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'motion.dart';
import 'surfaces.dart';
import 'theme.dart';

/// The plan an agent is walking through, with the current step spinning — the
/// `agent-plan` element.
class AssistantAgentPlan extends StatelessWidget {
  const AssistantAgentPlan({
    super.key,
    required this.steps,
    required this.activeIndex,
  });

  final List<String> steps;

  /// Index of the step in flight; everything before it reads as done.
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final int total = steps.length;
    // Clamp rather than trust the host: an out-of-range index must not draw a
    // 130% bar.
    final int completed = activeIndex.clamp(0, total);
    final bool allDone = completed >= total;
    final double progress = total == 0 ? 0 : completed / total;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Plan',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: theme.foreground,
                    ),
                  ),
                ),
                Text(
                  '$completed of $total',
                  style: auiMono(context, color: auiFg(theme, 0.35)).copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              // `transition-[width] duration-500`: the fill eases to the new
              // fraction instead of jumping.
              child: AuiAnimatedProgressBar(
                value: math.max(0, math.min(1, progress)),
                height: 3,
                track: auiFg(theme, 0.06),
                color: auiFg(theme, 0.8),
              ),
            ),
            const SizedBox(height: 12),
            for (final (int index, String step) in steps.indexed)
              Padding(
                padding: EdgeInsets.only(bottom: index == steps.length - 1 ? 0 : 10),
                child: _Step(
                  label: step,
                  done: allDone || index < completed,
                  active: !allDone && index == completed,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.label,
    required this.done,
    required this.active,
  });

  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final double alpha = done
        ? 0.4
        : active
            ? 0.9
            : 0.35;
    return Row(
      children: <Widget>[
        SizedBox(
          width: 16,
          height: 16,
          child: Center(
            child: done
                ? Icon(Icons.check, size: 14, color: auiFg(theme, 0.35))
                : active
                    ? AuiSpinner(size: 14, color: auiFg(theme, 0.9))
                    : Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: auiFg(theme, 0.15),
                          shape: BoxShape.circle,
                        ),
                      ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.3,
              color: auiFg(theme, alpha),
            ),
          ),
        ),
      ],
    );
  }
}
