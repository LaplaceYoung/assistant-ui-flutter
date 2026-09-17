import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// How a memory chip relates to what was already known.
enum MemoryChange { added, updated, existing }

/// One remembered fact.
@immutable
class MemoryChip {
  const MemoryChip({
    required this.id,
    required this.text,
    required this.change,
  });

  final String id;
  final String text;
  final MemoryChange change;
}

/// What the assistant committed to memory during this run, with a way to
/// forget each one — the `memory-chips` element.
class AssistantMemoryChips extends StatelessWidget {
  const AssistantMemoryChips({
    super.key,
    required this.chips,
    this.onForget,
  });

  final List<MemoryChip> chips;

  /// Adds the per-chip forget control; without it the chips are read-only.
  final ValueChanged<String>? onForget;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final int fresh = chips
        .where((MemoryChip chip) => chip.change != MemoryChange.existing)
        .length;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.psychology_outlined,
                  size: 14,
                  color: auiFg(theme, 0.3),
                ),
                const SizedBox(width: 6),
                Text(
                  fresh > 0 ? 'remembered $fresh' : 'memory',
                  style: auiMono(context, color: auiFg(theme, 0.35)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final MemoryChip chip in chips)
                  _Chip(
                    chip: chip,
                    dark: dark,
                    onForget: onForget,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.chip,
    required this.dark,
    required this.onForget,
  });

  final MemoryChip chip;
  final bool dark;
  final ValueChanged<String>? onForget;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool existing = chip.change == MemoryChange.existing;
    final Color fill = existing
        ? auiFieldColor(theme)
        : (dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6))
            .withValues(alpha: dark ? 0.15 : 0.12);
    final Color text = existing
        ? auiFg(theme, 0.55)
        : (dark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8));

    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: EdgeInsets.only(
        left: 10,
        right: onForget == null ? 10 : 4,
        top: 4,
        bottom: 4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            chip.text,
            style: TextStyle(fontSize: 12, height: 1.2, color: text),
          ),
          if (onForget != null) ...<Widget>[
            const SizedBox(width: 4),
            AuiIconAction(
              icon: Icons.close,
              label: 'Forget "${chip.text}"',
              size: 16,
              onPressed: () => onForget!(chip.id),
            ),
          ],
        ],
      ),
    );
  }
}
