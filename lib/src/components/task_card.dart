import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// Where a background task stands.
enum TaskCardState { working, waiting, done, failed, cancelled }

/// One task in a run: its state, what it is doing, and the transcript and
/// result behind a disclosure — the `task-card` element.
class AssistantTaskCard extends StatefulWidget {
  const AssistantTaskCard({
    super.key,
    required this.label,
    required this.state,
    this.meta,
    this.elapsed,
    this.actions,
    this.result,
    this.transcript,
    this.open,
    this.onOpenChange,
  });

  final String label;
  final TaskCardState state;

  /// Short right-aligned note, e.g. the tool name.
  final String? meta;

  /// Shown only while the task is live.
  final String? elapsed;

  /// Rendered under the header, above the transcript.
  final Widget? actions;

  /// Rendered last, in the muted result style.
  final Widget? result;

  /// Revealed behind the chevron; without it the card is not expandable.
  final Widget? transcript;

  /// Bound open state; when null the card owns it.
  final bool? open;
  final ValueChanged<bool>? onOpenChange;

  @override
  State<AssistantTaskCard> createState() => _AssistantTaskCardState();
}

class _AssistantTaskCardState extends State<AssistantTaskCard> {
  late bool _open = widget.open ?? false;

  @override
  void didUpdateWidget(AssistantTaskCard oldWidget) {
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
    final bool hasTranscript = widget.transcript != null;
    // Upstream: a bound `open` without an `onOpenChange` is inert.
    final bool tappable = hasTranscript &&
        !(widget.open != null && widget.onOpenChange == null);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _Header(
                label: widget.label,
                state: widget.state,
                meta: widget.meta,
                elapsed: widget.elapsed,
                hasTranscript: hasTranscript,
                open: _open,
                onTap: tappable ? _toggle : null,
              ),
              if (widget.actions != null)
                _Section(child: widget.actions!),
              if (hasTranscript && _open)
                _Section(child: widget.transcript!),
              if (widget.result != null)
                _Section(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: auiFg(theme, 0.7),
                    ),
                    child: widget.result!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.border.withValues(alpha: 0.6)),
        ),
      ),
      padding: padding,
      child: child,
    );
  }
}

class _Header extends StatefulWidget {
  const _Header({
    required this.label,
    required this.state,
    required this.meta,
    required this.elapsed,
    required this.hasTranscript,
    required this.open,
    required this.onTap,
  });

  final String label;
  final TaskCardState state;
  final String? meta;
  final String? elapsed;
  final bool hasTranscript;
  final bool open;
  final VoidCallback? onTap;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool tappable = widget.onTap != null;
    return MouseRegion(
      cursor: tappable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          color: tappable && _hovered ? auiFg(theme, 0.03) : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: <Widget>[
              TaskStateGlyph(state: widget.state),
              const SizedBox(width: 10),
              Semantics(
                container: true,
                label: widget.state.name,
                child: const SizedBox.shrink(),
              ),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.3,
                    color: theme.foreground,
                  ),
                ),
              ),
              if (widget.meta != null) ...<Widget>[
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 96),
                  child: Text(
                    widget.meta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: auiMono(context, color: auiFg(theme, 0.35)),
                  ),
                ),
              ],
              if (widget.elapsed != null) ...<Widget>[
                const SizedBox(width: 10),
                Text(
                  widget.elapsed!,
                  style: auiMono(context, color: auiFg(theme, 0.3)).copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
              if (widget.hasTranscript) ...<Widget>[
                const SizedBox(width: 10),
                AnimatedRotation(
                  turns: widget.open ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right,
                    size: 12,
                    color: auiFg(theme, 0.25),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The task state glyph, shared by the card and any host that needs it.
class TaskStateGlyph extends StatelessWidget {
  const TaskStateGlyph({super.key, required this.state, this.size = 14});

  final TaskCardState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    switch (state) {
      case TaskCardState.done:
        return const Icon(Icons.check, size: 14, color: Color(0xFF10B981));
      case TaskCardState.failed:
        return Icon(Icons.close, size: size, color: theme.destructive);
      case TaskCardState.cancelled:
        return Icon(Icons.block, size: size, color: auiFg(theme, 0.35));
      case TaskCardState.working:
        return AuiSpinner(size: size, color: auiFg(theme, 0.35));
      case TaskCardState.waiting:
        return Padding(
          padding: const EdgeInsets.all(4),
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: auiFg(theme, 0.35)),
            ),
          ),
        );
    }
  }
}
