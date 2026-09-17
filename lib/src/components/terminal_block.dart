import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// How the block is painted.
enum TerminalVariant { paper, ink }

/// A command and its output as it streams — the `terminal-block` element.
class AssistantTerminalBlock extends StatelessWidget {
  const AssistantTerminalBlock({
    super.key,
    required this.command,
    required this.lines,
    required this.visibleCount,
    this.done = false,
    this.variant = TerminalVariant.paper,
  });

  final String command;
  final List<String> lines;

  /// How many output lines have arrived.
  final int visibleCount;

  /// Swaps the spinner for `exit 0` and drops the caret.
  final bool done;

  final TerminalVariant variant;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool ink = variant == TerminalVariant.ink;
    final TextStyle code = theme.code(context).copyWith(fontSize: 12);
    // The ink variant sits on the foreground color, as upstream's does.
    final Color header = ink ? theme.background : auiFg(theme, 0.9);
    final Color body = ink
        ? theme.background.withValues(alpha: 0.55)
        : auiFg(theme, 0.5);
    final Color least = ink
        ? theme.background.withValues(alpha: 0.35)
        : auiFg(theme, 0.35);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 448),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: ink
              ? BoxDecoration(
                  color: theme.foreground,
                  borderRadius: BorderRadius.circular(16),
                )
              : auiPaper(theme, radius: 16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        command,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: code.copyWith(color: header),
                      ),
                    ),
                    if (done) ...<Widget>[
                      const Icon(
                        Icons.check,
                        size: 12,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'exit 0',
                        style: auiMono(context, color: least),
                      ),
                    ] else
                      AuiSpinner(size: 12, color: least),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 136),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final (int index, String line)
                          in lines.take(visibleCount).indexed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            line,
                            style: code.copyWith(
                              color: index == lines.length - 1 && done
                                  ? (ink ? theme.background : auiFg(theme, 0.9))
                                  : body,
                            ),
                          ),
                        ),
                      if (!done) const _Caret(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Caret extends StatefulWidget {
  const _Caret();

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1).animate(_pulse),
      child: Container(
        width: 6,
        height: 12,
        color: (dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6))
            .withValues(alpha: 0.7),
      ),
    );
  }
}
