import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// What an agent is doing right now.
enum AgentState { working, waiting, done, failed }

/// A live agent chip: state glyph, what it is doing, elapsed time and a
/// trailing control — the `agent-status` element.
class AssistantAgentStatus extends StatelessWidget {
  const AssistantAgentStatus({
    super.key,
    required this.state,
    required this.label,
    this.elapsed,
    this.trailing,
  });

  final AgentState state;
  final String label;

  /// Shown only while the agent is [AgentState.working] or
  /// [AgentState.waiting], as upstream does.
  final String? elapsed;

  /// Replaces the default pause / retry glyph.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool settled =
        state == AgentState.done || state == AgentState.failed;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: auiPaper(theme, radius: 999),
            padding: const EdgeInsets.only(
              left: 14,
              right: 6,
              top: 6,
              bottom: 6,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Semantics(
                  container: true,
                  label: <String>[
                    state.name,
                    label,
                    if (elapsed != null && !settled) elapsed!,
                  ].join(', '),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                _Lead(state: state),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 176),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: theme.foreground,
                    ),
                  ),
                ),
                if (elapsed != null && !settled) ...<Widget>[
                  const SizedBox(width: 10),
                  Text(
                    elapsed!,
                    style: auiMono(context, color: auiFg(theme, 0.3)).copyWith(
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Center(
                    child: trailing ??
                        Icon(
                          settled ? Icons.refresh : Icons.pause,
                          size: 12,
                          color: auiFg(theme, 0.45),
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

class _Lead extends StatefulWidget {
  const _Lead({required this.state});

  final AgentState state;

  @override
  State<_Lead> createState() => _LeadState();
}

class _LeadState extends State<_Lead> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.state == AgentState.working) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Lead oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state == AgentState.working) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    switch (widget.state) {
      case AgentState.done:
        return const Icon(Icons.check, size: 12, color: Color(0xFF10B981));
      case AgentState.failed:
        return Icon(Icons.close, size: 12, color: theme.destructive);
      case AgentState.working:
        return FadeTransition(
          opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color:
                  dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
              shape: BoxShape.circle,
            ),
          ),
        );
      case AgentState.waiting:
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: auiFg(theme, 0.35)),
          ),
        );
    }
  }
}
