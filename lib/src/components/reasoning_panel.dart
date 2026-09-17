import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One step of an agent's reasoning.
@immutable
class ReasoningStep {
  const ReasoningStep({required this.title, required this.body});

  final String title;
  final String body;
}

/// The reasoning behind an answer, revealed step by step — the
/// `reasoning-panel` element.
class AssistantReasoningPanel extends StatefulWidget {
  const AssistantReasoningPanel({
    super.key,
    required this.steps,
    required this.visibleSteps,
    required this.restingLabel,
    this.streaming = false,
    this.elapsed,
    this.open,
    this.onOpenChange,
    this.initiallyOpen = false,
  });

  final List<ReasoningStep> steps;

  /// How many steps are showing.
  final int visibleSteps;

  /// Label once the run settles.
  final String restingLabel;

  final bool streaming;

  /// Shown next to `Thinking` while the run is live.
  final String? elapsed;

  /// Bound open state; when null the widget owns it from [initiallyOpen].
  final bool? open;
  final ValueChanged<bool>? onOpenChange;
  final bool initiallyOpen;

  @override
  State<AssistantReasoningPanel> createState() =>
      _AssistantReasoningPanelState();
}

class _AssistantReasoningPanelState extends State<AssistantReasoningPanel> {
  late bool _open = widget.open ?? widget.initiallyOpen;

  @override
  void didUpdateWidget(AssistantReasoningPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != null) _open = widget.open!;
  }

  void _toggle() {
    final bool next = !_open;
    if (widget.open == null) setState(() => _open = next);
    widget.onOpenChange?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color blue =
        dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
    final List<ReasoningStep> shown =
        widget.steps.take(widget.visibleSteps).toList();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Trigger(
              open: _open,
              streaming: widget.streaming,
              elapsed: widget.elapsed,
              restingLabel: widget.restingLabel,
              onTap: _toggle,
            ),
            if (_open)
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final (int index, ReasoningStep step)
                        in shown.indexed)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == shown.length - 1 ? 0 : 16,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: _StepDot(
                                active: widget.streaming &&
                                    index == shown.length - 1,
                                blue: blue,
                                dim: auiFg(theme, 0.2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    step.title,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      height: 1.3,
                                      fontWeight: FontWeight.w500,
                                      color: auiFg(theme, 0.9),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    step.body,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: auiFg(theme, 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Trigger extends StatefulWidget {
  const _Trigger({
    required this.open,
    required this.streaming,
    required this.elapsed,
    required this.restingLabel,
    required this.onTap,
  });

  final bool open;
  final bool streaming;
  final String? elapsed;
  final String restingLabel;
  final VoidCallback onTap;

  @override
  State<_Trigger> createState() => _TriggerState();
}

class _TriggerState extends State<_Trigger> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final Color color = auiFg(theme, _hovered ? 0.9 : 0.55);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Semantics(
          button: true,
          expanded: widget.open,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (widget.streaming) ...<Widget>[
                  AuiShimmerLabel(
                    text: 'Thinking',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.2,
                      color: color,
                    ),
                  ),
                  if (widget.elapsed != null) ...<Widget>[
                    const SizedBox(width: 6),
                    Text(
                      widget.elapsed!,
                      style: auiMono(context, color: auiFg(theme, 0.3))
                          .copyWith(
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ] else
                  Text(
                    widget.restingLabel,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.2,
                      color: color,
                    ),
                  ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: widget.open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more,
                    size: 14,
                    color: auiFg(theme, 0.6),
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

class _StepDot extends StatefulWidget {
  const _StepDot({
    required this.active,
    required this.blue,
    required this.dim,
  });

  final bool active;
  final Color blue;
  final Color dim;

  @override
  State<_StepDot> createState() => _StepDotState();
}

class _StepDotState extends State<_StepDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_StepDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.active && _pulse.isAnimating) {
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
    final Widget dot = Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: widget.active ? widget.blue : widget.dim,
        shape: BoxShape.circle,
      ),
    );
    return widget.active
        ? FadeTransition(
            opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
            child: dot,
          )
        : dot;
  }
}
