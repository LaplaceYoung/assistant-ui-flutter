import 'package:flutter/material.dart';

import 'motion.dart';
import 'surfaces.dart';
import 'theme.dart';

/// State of one call inside an [AssistantToolGroup].
enum GroupedToolState { running, done, failed }

/// One call inside an [AssistantToolGroup].
@immutable
class GroupedTool {
  const GroupedTool({
    required this.id,
    required this.name,
    required this.target,
    required this.state,
    this.durationMs,
  });

  final String id;
  final String name;

  /// What the call acted on: a path, a command, a query.
  final String target;

  final GroupedToolState state;

  /// Wall time of the call, shown when the host measured it.
  final int? durationMs;
}

/// A run of tool calls collapsed into one card: a header that counts what
/// happened, and one row per call — the `tool-group` element.
class AssistantToolGroup extends StatefulWidget {
  const AssistantToolGroup({
    super.key,
    required this.label,
    required this.tools,
    this.open,
    this.onOpenChange,
    this.initiallyOpen = false,
  });

  final String label;
  final List<GroupedTool> tools;

  /// Bound open state; when null the widget owns it from [initiallyOpen].
  final bool? open;
  final ValueChanged<bool>? onOpenChange;
  final bool initiallyOpen;

  @override
  State<AssistantToolGroup> createState() => _AssistantToolGroupState();
}

class _AssistantToolGroupState extends State<AssistantToolGroup> {
  late bool _open = widget.open ?? widget.initiallyOpen;

  @override
  void didUpdateWidget(AssistantToolGroup oldWidget) {
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
    final int running =
        widget.tools.where((GroupedTool tool) => tool.state == GroupedToolState.running).length;
    final int failed =
        widget.tools.where((GroupedTool tool) => tool.state == GroupedToolState.failed).length;
    final String count = running > 0
        ? '${widget.tools.length - running}/${widget.tools.length}'
        : failed > 0
            ? '$failed failed'
            : '${widget.tools.length} done';

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
                count: count,
                open: _open,
                running: running,
                failed: failed,
                onTap: widget.onOpenChange == null ? null : _toggle,
              ),
              if (_open)
                // `fade-in slide-in-from-top-1 animate-in duration-200`: the
                // body drops in rather than appearing.
                AuiFadeInBlur(
                  duration: const Duration(milliseconds: 200),
                  blur: 0,
                  slideFrom: const Offset(0, -4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        height: 1,
                        color: auiFg(theme, 0.06),
                      ),
                      for (final GroupedTool tool in widget.tools)
                        _ToolRow(tool: tool),
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

class _Header extends StatefulWidget {
  const _Header({
    required this.label,
    required this.count,
    required this.open,
    required this.running,
    required this.failed,
    required this.onTap,
  });

  final String label;
  final String count;
  final bool open;
  final int running;
  final int failed;
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
        child: Semantics(
          button: tappable,
          expanded: widget.open,
          label: '${widget.label}, ${widget.count}',
          child: AnimatedContainer(
            // `hover:bg-foreground/[0.03] transition-colors`.
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            color: tappable && _hovered ? auiFg(theme, 0.03) : null,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: <Widget>[
                AnimatedRotation(
                  turns: widget.open ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.chevron_right,
                    size: 12,
                    color: auiFg(theme, 0.25),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.2,
                      color: theme.foreground,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.count,
                  style: auiMono(
                    context,
                    color: auiFg(theme, 0.3),
                  ).copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _StatusGlyph(
                  running: widget.running,
                  failed: widget.failed,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusGlyph extends StatelessWidget {
  const _StatusGlyph({
    required this.running,
    required this.failed,
    required this.size,
  });

  final int running;
  final int failed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    if (running > 0) {
      return AuiSpinner(size: size, color: auiFg(theme, 0.35));
    }
    if (failed > 0) {
      return Icon(Icons.close, size: size, color: _red500);
    }
    return const Icon(Icons.check, size: 14, color: _emerald500);
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.tool});

  final GroupedTool tool;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 14,
            height: 14,
            child: Center(
              child: switch (tool.state) {
                GroupedToolState.running =>
                  AuiSpinner(size: 12, color: auiFg(theme, 0.35)),
                GroupedToolState.failed =>
                  const Icon(Icons.close, size: 12, color: _red500),
                GroupedToolState.done =>
                  const Icon(Icons.check, size: 12, color: _emerald500),
              },
            ),
          ),
          const SizedBox(width: 10),
          Text(tool.name, style: auiMono(context, color: auiFg(theme, 0.55))),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tool.target,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.2,
                color: auiFg(theme, 0.8),
              ),
            ),
          ),
          if (tool.durationMs != null) ...<Widget>[
            const SizedBox(width: 10),
            Text(
              '${tool.durationMs}ms',
              style: auiMono(context, color: auiFg(theme, 0.25)).copyWith(
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Note: upstream uses tailwind's red-500 / emerald-500 for status glyphs; the
// theme's destructive/success tokens are tuned for filled surfaces and read
// too heavy at 12px.
const Color _red500 = Color(0xFFEF4444);
const Color _emerald500 = Color(0xFF10B981);
