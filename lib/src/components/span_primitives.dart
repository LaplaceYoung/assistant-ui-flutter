import 'package:flutter/material.dart';

import '../runtime/span_tree.dart';
import 'theme.dart';

/// The span the primitives below render: the `react-o11y` span scope, as a
/// plain inherited value instead of a store scope.
class AuiSpanScope extends InheritedWidget {
  const AuiSpanScope({
    super.key,
    required this.tree,
    required this.node,
    required super.child,
  });

  final SpanTree tree;
  final SpanNode node;

  static AuiSpanScope of(BuildContext context) {
    final AuiSpanScope? scope =
        context.dependOnInheritedWidgetOfExactType<AuiSpanScope>();
    assert(scope != null, 'No AuiSpanScope found in this context.');
    return scope!;
  }

  static AuiSpanScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuiSpanScope>();

  @override
  bool updateShouldNotify(AuiSpanScope oldWidget) =>
      oldWidget.node != node || oldWidget.tree != tree;
}

/// The row wrapper: indent, collapse toggle and the children below it — the
/// starting point for any span view.
class AuiSpanRoot extends StatelessWidget {
  const AuiSpanRoot({
    super.key,
    required this.child,
    this.indentPerDepth = 12,
    this.showToggle = true,
  });

  final Widget child;
  final double indentPerDepth;
  final bool showToggle;

  @override
  Widget build(BuildContext context) {
    final AuiSpanScope scope = AuiSpanScope.of(context);
    final SpanNode node = scope.node;
    return Padding(
      padding: EdgeInsets.only(left: node.depth * indentPerDepth),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (showToggle) AuiSpanCollapseToggle(),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// The span's name.
class AuiSpanName extends StatelessWidget {
  const AuiSpanName({super.key, this.style});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final SpanNode node = AuiSpanScope.of(context).node;
    return Text(
      node.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style ?? theme.code(context).copyWith(fontSize: 12),
    );
  }
}

/// What kind of work the span is: `llm`, `tool`, `chain`, …
class AuiSpanTypeBadge extends StatelessWidget {
  const AuiSpanTypeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final SpanNode node = AuiSpanScope.of(context).node;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.muted,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        node.type,
        style: theme.small(context).copyWith(fontSize: 10),
      ),
    );
  }
}

/// The status dot: a spinner while running, a check, a cross, or a dash.
class AuiSpanStatusIndicator extends StatelessWidget {
  const AuiSpanStatusIndicator({super.key, this.size = 12});

  final double size;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final SpanNode node = AuiSpanScope.of(context).node;
    if (node.status == OpenSpanStatus.running) {
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 1.6,
          color: theme.mutedForeground,
        ),
      );
    }
    final (IconData icon, Color color) = switch (node.status) {
      OpenSpanStatus.completed => (Icons.check, const Color(0xFF16A34A)),
      OpenSpanStatus.failed => (Icons.close, theme.destructive),
      OpenSpanStatus.skipped => (Icons.remove, theme.mutedForeground),
      OpenSpanStatus.running => (Icons.autorenew, theme.mutedForeground),
    };
    return Icon(icon, size: size, color: color);
  }
}

/// Collapses or expands the span's children.
class AuiSpanCollapseToggle extends StatelessWidget {
  const AuiSpanCollapseToggle({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final AuiSpanScope scope = AuiSpanScope.of(context);
    final SpanNode node = scope.node;
    if (!node.hasChildren) {
      return SizedBox(width: size, height: size);
    }
    return SizedBox(
      width: size,
      height: size,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => scope.tree.toggleCollapse(node.id),
          child: AnimatedRotation(
            turns: node.isCollapsed ? -0.25 : 0,
            duration: const Duration(milliseconds: 150),
            child: Icon(
              Icons.keyboard_arrow_down,
              size: size,
              color: theme.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}

/// Indent for a child row.
class AuiSpanIndent extends StatelessWidget {
  const AuiSpanIndent({super.key, this.width = 12});

  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(width: width);
}

/// The children of the span, hidden while it is collapsed. Each child gets its
/// own [AuiSpanScope].
class AuiSpanChildren extends StatelessWidget {
  const AuiSpanChildren({
    super.key,
    required this.child,
    this.spacing = 4,
  });

  final Widget Function(BuildContext context, SpanNode node, int index) child;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final AuiSpanScope scope = AuiSpanScope.of(context);
    final SpanNode node = scope.node;
    if (node.isCollapsed || node.children.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < node.children.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: spacing),
          AuiSpanScope(
            tree: scope.tree,
            node: node.children[i],
            child: child(context, node.children[i], i),
          ),
        ],
      ],
    );
  }
}

/// One span bar, placed on the tree's window — the timeline a waterfall view
/// is built from.
class AuiSpanTimelineBar extends StatelessWidget {
  const AuiSpanTimelineBar({super.key, this.height = 8, this.radius = 4});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final AuiSpanScope scope = AuiSpanScope.of(context);
    final SpanNode node = scope.node;
    final ({double start, double width}) at =
        scope.tree.timeRange.placement(node);
    final Color color = switch (node.status) {
      OpenSpanStatus.completed => theme.foreground,
      OpenSpanStatus.failed => theme.destructive,
      OpenSpanStatus.skipped => theme.mutedForeground,
      OpenSpanStatus.running => theme.mutedForeground,
    };
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double track = constraints.maxWidth;
        return SizedBox(
          height: height,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: at.start * track),
              child: Container(
                // A zero-length span still gets a visible sliver.
                width: (at.width * track).clamp(2.0, track),
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(radius),
                  border: node.status == OpenSpanStatus.running
                      ? Border.all(color: color.withValues(alpha: 0.4))
                      : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The whole tree as a list: root rows with their children beneath.
class AuiSpanTimeline extends StatelessWidget {
  const AuiSpanTimeline({
    super.key,
    required this.tree,
    this.spacing = 6,
  });

  final SpanTree tree;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tree,
      builder: (BuildContext context, Widget? _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final SpanNode root in tree.roots) ...<Widget>[
            if (root != tree.roots.first) SizedBox(height: spacing),
            _SpanRow(tree: tree, node: root),
          ],
        ],
      ),
    );
  }
}

class _SpanRow extends StatelessWidget {
  const _SpanRow({required this.tree, required this.node, this.spacing = 6});

  final SpanTree tree;
  final SpanNode node;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return AuiSpanScope(
      tree: tree,
      node: node,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AuiSpanRoot(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const AuiSpanStatusIndicator(),
                    const SizedBox(width: 6),
                    const AuiSpanTypeBadge(),
                    const SizedBox(width: 6),
                    const Expanded(child: AuiSpanName()),
                    if (node.latencyMs != null)
                      Text(
                        '${node.latencyMs}ms',
                        style: AssistantTheme.of(context)
                            .small(context)
                            .copyWith(fontSize: 11),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                const AuiSpanTimelineBar(),
              ],
            ),
          ),
          AuiSpanChildren(
            spacing: spacing,
            child: (BuildContext context, SpanNode child, int index) =>
                _SpanRow(tree: tree, node: child, spacing: spacing),
          ),
        ],
      ),
    );
  }
}
