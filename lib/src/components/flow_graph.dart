import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// Where a flow node stands.
enum FlowNodeState { done, active, pending }

/// One node of a flow graph, placed on a column/row grid.
@immutable
class FlowGraphNode {
  const FlowGraphNode({
    required this.id,
    required this.label,
    required this.column,
    required this.row,
    required this.state,
  });

  final String id;
  final String label;
  final int column;
  final int row;
  final FlowNodeState state;
}

/// A connection between two nodes.
@immutable
class FlowGraphEdge {
  const FlowGraphEdge({required this.from, required this.to});

  final String from;
  final String to;
}

/// A left-to-right flow of steps on a fixed grid — the `flow-graph` element.
///
/// The types are prefixed with `FlowGraph` because `flow-canvas` already owns
/// `FlowNode` / `FlowEdge` in this package.
class AssistantFlowGraph extends StatelessWidget {
  const AssistantFlowGraph({
    super.key,
    required this.nodes,
    this.edges = const <FlowGraphEdge>[],
    required this.visibleCount,
  });

  final List<FlowGraphNode> nodes;
  final List<FlowGraphEdge> edges;

  /// How many nodes have been revealed, in order.
  final int visibleCount;

  static const double _colWidth = 96;
  static const double _rowHeight = 58;
  static const double _nodeWidth = 78;
  static const double _nodeHeight = 30;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final List<FlowGraphNode> shown = nodes.take(visibleCount).toList();
    final Set<String> shownIds =
        shown.map((FlowGraphNode node) => node.id).toSet();
    final int columns = nodes.isEmpty
        ? 1
        : nodes
                .map((FlowGraphNode node) => node.column)
                .reduce((int a, int b) => a > b ? a : b) +
            1;
    final int rows = nodes.isEmpty
        ? 1
        : nodes
                .map((FlowGraphNode node) => node.row)
                .reduce((int a, int b) => a > b ? a : b) +
            1;
    final double width = (columns - 1) * _colWidth + _nodeWidth;
    final double height = (rows - 1) * _rowHeight + _nodeHeight;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 448),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: height,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: CustomPaint(
                      painter: AuiFlowGraphPainter(
                        nodes: nodes,
                        edges: edges,
                        shownIds: shownIds,
                        colWidth: _colWidth,
                        rowHeight: _rowHeight,
                        nodeWidth: _nodeWidth,
                        nodeHeight: _nodeHeight,
                        live: auiFg(theme, 0.2),
                        dim: auiFg(theme, 0.05),
                      ),
                    ),
                  ),
                  for (final FlowGraphNode node in shown)
                    Positioned(
                      left: node.column * _colWidth,
                      top: node.row * _rowHeight,
                      width: _nodeWidth,
                      height: _nodeHeight,
                      child: _Node(node: node),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({required this.node});

  final FlowGraphNode node;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color blue =
        dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
    // Note: upstream draws the pending nodes with a dashed border; Flutter's
    // BorderSide has no dash pattern, so they read as a faint solid outline.
    final (Color fill, Color border, Color text) = switch (node.state) {
      FlowNodeState.done => (
          auiFg(theme, 0.04),
          auiFg(theme, 0.1),
          auiFg(theme, 0.5),
        ),
      FlowNodeState.active => (
          blue.withValues(alpha: 0.1),
          blue.withValues(alpha: 0.3),
          auiFg(theme, 0.9),
        ),
      FlowNodeState.pending => (
          Colors.transparent,
          auiFg(theme, 0.08),
          auiFg(theme, 0.35),
        ),
    };

    return Container(
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Text(
        node.label,
        textAlign: TextAlign.center,
        style: auiMono(context, size: 11.5, color: text).copyWith(height: 1.2),
      ),
    );
  }
}

/// Draws the flow edges as curves between node centers.
class AuiFlowGraphPainter extends CustomPainter {
  AuiFlowGraphPainter({
    required this.nodes,
    required this.edges,
    required this.shownIds,
    required this.colWidth,
    required this.rowHeight,
    required this.nodeWidth,
    required this.nodeHeight,
    required this.live,
    required this.dim,
  });

  final List<FlowGraphNode> nodes;
  final List<FlowGraphEdge> edges;
  final Set<String> shownIds;
  final double colWidth;
  final double rowHeight;
  final double nodeWidth;
  final double nodeHeight;
  final Color live;
  final Color dim;

  @override
  void paint(Canvas canvas, Size size) {
    for (final FlowGraphEdge edge in edges) {
      final FlowGraphNode? from = nodes
          .where((FlowGraphNode node) => node.id == edge.from)
          .firstOrNull;
      final FlowGraphNode? to = nodes
          .where((FlowGraphNode node) => node.id == edge.to)
          .firstOrNull;
      if (from == null || to == null) continue;
      final Offset a = Offset(
        from.column * colWidth + nodeWidth / 2,
        from.row * rowHeight + nodeHeight / 2,
      );
      final Offset b = Offset(
        to.column * colWidth + nodeWidth / 2,
        to.row * rowHeight + nodeHeight / 2,
      );
      final double midX = (a.dx + b.dx) / 2;
      final bool active = shownIds.contains(edge.from) &&
          shownIds.contains(edge.to);
      canvas.drawPath(
        Path()
          ..moveTo(a.dx + nodeWidth / 2, a.dy)
          ..cubicTo(
            midX,
            a.dy,
            midX,
            b.dy,
            b.dx - nodeWidth / 2,
            b.dy,
          ),
        Paint()
          ..color = active ? live : dim
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(AuiFlowGraphPainter oldDelegate) =>
      oldDelegate.shownIds.length != shownIds.length ||
      oldDelegate.edges.length != edges.length ||
      oldDelegate.nodes.length != nodes.length;
}
