import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// Where a snippet's run stands.
enum RunState { idle, running, ok, error }

/// A snippet with a run control and the output it produced — the `code-runner`
/// element.
class AssistantCodeRunner extends StatelessWidget {
  const AssistantCodeRunner({
    super.key,
    required this.language,
    required this.code,
    this.state = RunState.idle,
    this.output = const <String>[],
    this.durationMs,
    this.onRun,
    this.highlighter,
  });

  final String language;
  final String code;
  final RunState state;
  final List<String> output;

  /// Wall time of the last run, shown once it settles.
  final int? durationMs;

  final VoidCallback? onRun;

  /// Replaces the plain code block, e.g. with an `AssistantSyntaxHighlighter`.
  final Widget? highlighter;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color red = dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);

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
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        language,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: auiMono(context, color: auiFg(theme, 0.35)),
                      ),
                    ),
                    if (durationMs != null && state != RunState.running) ...<Widget>[
                      Text(
                        '${durationMs}ms',
                        style: auiMono(context, color: auiFg(theme, 0.3))
                            .copyWith(
                          fontFeatures: const <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Semantics(
                      button: true,
                      enabled: state != RunState.running && onRun != null,
                      label: 'Run this snippet',
                      child: GestureDetector(
                        onTap: state == RunState.running ? null : onRun,
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: Center(
                            child: state == RunState.running
                                ? AuiSpinner(
                                    size: 14,
                                    color: auiFg(theme, 0.45),
                                  )
                                : Icon(
                                    Icons.play_arrow,
                                    size: 14,
                                    color: auiFg(theme, 0.45),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: auiFg(theme, 0.07)),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: highlighter ??
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Text(
                        code,
                        style: theme.code(context).copyWith(
                          fontSize: 12,
                          color: auiFg(theme, 0.75),
                        ),
                      ),
                    ),
              ),
              if (state != RunState.idle)
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: auiFg(theme, 0.07)),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'output',
                        style: auiMono(context, color: auiFg(theme, 0.3)),
                      ),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (final String line in output)
                              Text(
                                line,
                                style: theme.code(context).copyWith(
                                  fontSize: 12,
                                  color: state == RunState.error
                                      ? red
                                      : auiFg(theme, 0.7),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (state == RunState.running) const _RunningCaret(),
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

class _RunningCaret extends StatefulWidget {
  const _RunningCaret();

  @override
  State<_RunningCaret> createState() => _RunningCaretState();
}

class _RunningCaretState extends State<_RunningCaret>
    with SingleTickerProviderStateMixin {
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
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1).animate(_pulse),
      child: Container(
        width: 2,
        height: 12,
        decoration: BoxDecoration(
          color: auiFg(theme, 0.4),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}
