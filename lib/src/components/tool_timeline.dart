import 'package:flutter/material.dart';

import 'motion.dart';
import 'surfaces.dart';
import 'theme.dart';

/// One line of agent work inside [AssistantToolTimeline]: what it is doing and
/// the thing it is doing it to.
@immutable
class AssistantTimelineStep {
  const AssistantTimelineStep({
    required this.verb,
    required this.chip,
    required this.icon,
  });

  final String verb;

  /// The file, command or symbol the verb applies to.
  final String chip;

  final IconData icon;
}

/// A changed file shown under the steps, with its diff counts.
@immutable
class AssistantTimelineStat {
  const AssistantTimelineStat({required this.file, this.added, this.removed});

  final String file;
  final int? added;
  final int? removed;
}

/// Collapsible list of what an agent is doing, with the active step shimmering
/// while the run streams and a resting summary when it settles — the
/// `tool-timeline` element.
class AssistantToolTimeline extends StatefulWidget {
  const AssistantToolTimeline({
    super.key,
    required this.steps,
    required this.visibleSteps,
    required this.restingLabel,
    required this.activeLabel,
    this.streaming = false,
    this.open,
    this.onOpenChange,
    this.initiallyOpen = false,
    this.stats = const <AssistantTimelineStat>[],
  });

  final List<AssistantTimelineStep> steps;

  /// How many steps of [steps] are shown; the rest are withheld until the run
  /// progresses, the way upstream reveals them one at a time.
  final int visibleSteps;

  /// Label while the run streams and while it rests.
  final String activeLabel;
  final String restingLabel;

  final bool streaming;

  /// Bound open state; when null the widget owns it from [initiallyOpen].
  final bool? open;
  final ValueChanged<bool>? onOpenChange;
  final bool initiallyOpen;

  final List<AssistantTimelineStat> stats;

  @override
  State<AssistantToolTimeline> createState() => _AssistantToolTimelineState();
}

class _AssistantToolTimelineState extends State<AssistantToolTimeline> {
  late bool _open = widget.open ?? widget.initiallyOpen;

  @override
  void didUpdateWidget(AssistantToolTimeline oldWidget) {
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
    final TextStyle labelStyle = TextStyle(
      fontSize: 13.5,
      height: 1.2,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    final List<AssistantTimelineStep> steps =
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
              onTap: _toggle,
              labelStyle: labelStyle,
              activeLabel: widget.activeLabel,
              restingLabel: widget.restingLabel,
            ),
            if (_open)
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final (int index, AssistantTimelineStep step)
                        in steps.indexed)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == steps.length - 1 &&
                                  widget.stats.isEmpty
                              ? 0
                              : 10,
                        ),
                        // `fade-in slide-in-from-bottom-1 animate-in
                        // duration-300`: a step slides up as it is revealed.
                        child: AuiFadeInBlur(
                          key: ValueKey<String>('step-$index'),
                          duration: const Duration(milliseconds: 300),
                          blur: 0,
                          slideFrom: const Offset(0, 4),
                          child: _StepRow(
                            step: step,
                            active: widget.streaming &&
                                index == steps.length - 1,
                            labelStyle: labelStyle,
                          ),
                        ),
                      ),
                    if (widget.stats.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: <Widget>[
                            for (final AssistantTimelineStat stat
                                in widget.stats)
                              _StatChip(stat: stat, dark: dark),
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
    required this.onTap,
    required this.labelStyle,
    required this.activeLabel,
    required this.restingLabel,
  });

  final bool open;
  final bool streaming;
  final VoidCallback onTap;
  final TextStyle labelStyle;
  final String activeLabel;
  final String restingLabel;

  @override
  State<_Trigger> createState() => _TriggerState();
}

class _TriggerState extends State<_Trigger> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    // Upstream tints the trigger on hover: text-foreground/55 -> /90.
    final TextStyle hoveredStyle = widget.labelStyle.copyWith(
      color: auiFg(theme, _hovered ? 0.9 : 0.55),
    );
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
                AnimatedRotation(
                  // `duration-200 ease-[cubic-bezier(0.32,0.72,0,1)]`.
                  turns: widget.open ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  curve: const Cubic(0.32, 0.72, 0, 1),
                  child: Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: auiFg(theme, 0.6),
                  ),
                ),
                const SizedBox(width: 6),
                AuiSwapLabel(
                  active: widget.streaming ? 0 : 1,
                  children: <Widget>[
                    AuiShimmerLabel(
                      text: widget.activeLabel,
                      active: widget.streaming,
                      style: hoveredStyle,
                    ),
                    Text(widget.restingLabel, style: hoveredStyle),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.active,
    required this.labelStyle,
  });

  final AssistantTimelineStep step;
  final bool active;
  final TextStyle labelStyle;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(step.icon, size: 14, color: auiFg(theme, 0.35)),
        const SizedBox(width: 8),
        Flexible(
          child: AuiShimmerLabel(
            text: step.verb,
            active: active,
            style: labelStyle,
          ),
        ),
        const SizedBox(width: 8),
        _Chip(text: step.chip),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.stat, required this.dark});

  final AssistantTimelineStat stat;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    // Note: upstream uses tailwind emerald-600/400 and red-600/400; the theme
    // only carries success/destructive, which read too heavy at 11px here.
    final Color added = dark ? const Color(0xFF34D399) : const Color(0xFF059669);
    final Color removed = dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    return _Chip(
      text: stat.file,
      trailing: <Widget>[
        if (stat.added != null)
          Text(
            '+${stat.added}',
            style: auiMono(context, color: added),
          ),
        if (stat.removed != null)
          Text(
            '−${stat.removed}',
            style: auiMono(context, color: removed),
          ),
      ],
      trailingGap: 4,
      theme: theme,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.text,
    this.trailing = const <Widget>[],
    this.trailingGap = 0,
    this.theme,
  });

  final String text;
  final List<Widget> trailing;
  final double trailingGap;
  final AssistantTheme? theme;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme resolved =
        theme ?? AssistantTheme.of(context);
    return Container(
      decoration: auiField(resolved, radius: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            text,
            style: auiMono(context, color: auiFg(resolved, 0.7)),
          ),
          if (trailing.isNotEmpty) ...<Widget>[
            SizedBox(width: trailingGap),
            ...trailing,
          ],
        ],
      ),
    );
  }
}
