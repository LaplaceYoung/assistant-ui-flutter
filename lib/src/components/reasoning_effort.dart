import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One thinking budget the user can pick.
@immutable
class EffortLevel {
  const EffortLevel({
    required this.key,
    required this.label,
    required this.budget,
  });

  final String key;
  final String label;

  /// Token budget of this level.
  final int budget;
}

/// A segmented thinking-effort picker with the budget spent so far — the
/// `reasoning-effort` element.
class AssistantReasoningEffort extends StatelessWidget {
  const AssistantReasoningEffort({
    super.key,
    required this.levels,
    required this.selectedKey,
    required this.spent,
    this.onSelect,
  });

  final List<EffortLevel> levels;
  final String selectedKey;

  /// Tokens spent on thinking in this run.
  final int spent;

  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color blue =
        dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
    final EffortLevel? selected = levels
        .where((EffortLevel level) => level.key == selectedKey)
        .firstOrNull;
    final int budget = selected?.budget ?? 0;
    final double used = budget == 0 ? 0 : spent / budget;

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
                    'Thinking',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: theme.foreground,
                    ),
                  ),
                ),
                Text(
                  '${_fmt(spent)} / ${_fmt(budget)}',
                  style: auiMono(context, color: auiFg(theme, 0.35)).copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: auiField(theme, radius: 999),
              padding: const EdgeInsets.all(2),
              child: Row(
                children: <Widget>[
                  for (final EffortLevel level in levels)
                    Expanded(
                      child: _Segment(
                        label: level.label,
                        active: level.key == selectedKey,
                        onTap: onSelect == null
                            ? null
                            : () => onSelect!(level.key),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Semantics(
              label: 'Thinking budget used',
              value: '${_fmt(spent)} of ${_fmt(budget)}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  height: 3,
                  color: auiFg(theme, 0.06),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: math.max(0, math.min(1, used)),
                      child: ColoredBox(color: blue),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Upstream formats with `toLocaleString("en-US")`.
  static String _fmt(int value) {
    final String digits = value.toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return out.toString();
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Semantics(
      button: onTap != null,
      selected: active,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? theme.background : null,
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: auiFg(theme, active ? 0.9 : 0.45),
            ),
          ),
        ),
      ),
    );
  }
}
