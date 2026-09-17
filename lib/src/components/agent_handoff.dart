import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One agent passing work to another, with what it carried over — the
/// `agent-handoff` element.
class AssistantAgentHandoff extends StatelessWidget {
  const AssistantAgentHandoff({
    super.key,
    required this.from,
    required this.to,
    required this.reason,
    this.carried = const <String>[],
    this.settled = false,
  });

  final String from;
  final String to;
  final String reason;

  /// Facts the receiving agent inherited.
  final List<String> carried;

  /// Settled handoffs fade to the neutral palette.
  final bool settled;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                Opacity(
                  opacity: settled ? 0.45 : 1,
                  child: _Pill(
                    label: from,
                    icon: Icons.smart_toy_outlined,
                    fill: auiFieldColor(theme),
                    text: auiFg(theme, 0.45),
                  ),
                ),
                Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: settled ? auiFg(theme, 0.25) : blue,
                ),
                _Pill(
                  label: to,
                  icon: Icons.smart_toy_outlined,
                  fill: settled
                      ? auiFieldColor(theme)
                      : blue.withValues(alpha: dark ? 0.15 : 0.12),
                  text: settled
                      ? auiFg(theme, 0.8)
                      : (dark
                          ? const Color(0xFF93C5FD)
                          : const Color(0xFF1D4ED8)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: auiFg(theme, 0.55),
              ),
            ),
            if (carried.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('carried over', style: auiMono(context, color: auiFg(theme, 0.3))),
              const SizedBox(height: 4),
              for (final String item in carried)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: auiFg(theme, 0.12)),
                      ),
                    ),
                    padding: const EdgeInsets.only(left: 10),
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: auiFg(theme, 0.6),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.icon,
    required this.fill,
    required this.text,
  });

  final String label;
  final IconData icon;
  final Color fill;
  final Color text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: text),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, height: 1.2, color: text),
          ),
        ],
      ),
    );
  }
}
