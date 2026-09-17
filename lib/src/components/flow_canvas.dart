import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// How an edge leaves its source node.
enum FlowRoute {
  /// Down out of the source, across, then into the top of the target.
  down,

  /// Out of the bottom, under both nodes, back up into the target.
  loopBottom,

  /// Out of the right side, around, and into the right side of the target.
  loopRight,
}

/// Where a node sits and what it says.
@immutable
class FlowNode {
  const FlowNode({
    required this.id,
    required this.title,
    required this.left,
    required this.top,
    this.width = 160,
    this.height = 56,
    this.subtitle,
  });

  final String id;
  final String title;
  final String? subtitle;

  /// Canvas coordinates; the port takes them as input instead of measuring
  /// laid-out DOM nodes the way upstream does.
  final double left;
  final double top;
  final double width;
  final double height;

  Rect get rect => Rect.fromLTWH(left, top, width, height);
}

/// A connection between two nodes.
@immutable
class FlowEdge {
  const FlowEdge({
    required this.from,
    required this.to,
    this.label,
    this.route = FlowRoute.down,
    this.midFrac,
    this.fromOffset,
    this.toOffset,
    this.laneOffset,
  });

  final String from;
  final String to;
  final String? label;
  final FlowRoute route;

  /// Where along the vertical gap the horizontal leg runs, 0..1.
  final double? midFrac;

  /// Pixel offsets from the source's and target's horizontal centers.
  final double? fromOffset;
  final double? toOffset;

  /// How far outside the nodes the lane runs.
  final double? laneOffset;
}

/// Nodes on a canvas with routed edges and labels — the `flow-canvas`
/// element.
///
/// Note: upstream measures its laid-out DOM children with a `ResizeObserver`
/// and draws the edges in an SVG overlay. Flutter cannot read a child's
/// geometry before layout, so nodes carry explicit canvas coordinates and the
/// edges are painted by a `CustomPainter` using upstream's routing math.
class AssistantFlowCanvas extends StatelessWidget {
  const AssistantFlowCanvas({
    super.key,
    required this.nodes,
    this.edges = const <FlowEdge>[],
    this.padding = 24,
  });

  final List<FlowNode> nodes;
  final List<FlowEdge> edges;

  /// Space kept around the nodes for the routed lanes.
  final double padding;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final double width = nodes.fold<double>(
          0,
          (double max, FlowNode node) => math.max(max, node.left + node.width),
        ) +
        padding;
    final double height = nodes.fold<double>(
          0,
          (double max, FlowNode node) => math.max(max, node.top + node.height),
        ) +
        padding;

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: CustomPaint(
              painter: AuiFlowEdgePainter(
                nodes: nodes,
                edges: edges,
                color: theme.mutedForeground.withValues(alpha: 0.7),
                labelColor: theme.mutedForeground,
                labelBackground: theme.background,
              ),
            ),
          ),
          for (final FlowNode node in nodes)
            Positioned(
              left: node.left,
              top: node.top,
              width: node.width,
              height: node.height,
              child: _NodeCard(node: node),
            ),
        ],
      ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  const _NodeCard({required this.node});

  final FlowNode node;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      decoration: auiPaper(theme, radius: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            node.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.3,
              fontWeight: FontWeight.w500,
              color: theme.foreground,
            ),
          ),
          if (node.subtitle != null)
            Text(
              node.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: auiMono(context, color: auiFg(theme, 0.35)),
            ),
        ],
      ),
    );
  }
}

/// Draws the routed edges; the geometry mirrors upstream's `measure()`.
class AuiFlowEdgePainter extends CustomPainter {
  AuiFlowEdgePainter({
    required this.nodes,
    required this.edges,
    required this.color,
    required this.labelColor,
    required this.labelBackground,
  });

  final List<FlowNode> nodes;
  final List<FlowEdge> edges;
  final Color color;
  final Color labelColor;
  final Color labelBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = color;
    final Paint fill = Paint()..color = color;

    for (final FlowEdge edge in edges) {
      final FlowNode? from = _node(edge.from);
      final FlowNode? to = _node(edge.to);
      if (from == null || to == null) continue;
      final Rect a = from.rect;
      final Rect b = to.rect;

      switch (edge.route) {
        case FlowRoute.down:
          final double sx = a.center.dx + (edge.fromOffset ?? 0);
          final double ex = b.center.dx + (edge.toOffset ?? 0);
          final double midY =
              a.bottom + (b.top - a.bottom) * (edge.midFrac ?? 0.5);
          final double? laneX = edge.laneOffset == null
              ? null
              : sx + edge.laneOffset!;
          final Path path = Path()..moveTo(sx, a.bottom);
          if (laneX == null) {
            path
              ..lineTo(sx, midY)
              ..lineTo(ex, midY)
              ..lineTo(ex, b.top - 6);
          } else {
            path
              ..lineTo(sx, a.bottom + 8)
              ..lineTo(laneX, a.bottom + 8)
              ..lineTo(laneX, midY)
              ..lineTo(ex, midY)
              ..lineTo(ex, b.top - 6);
          }
          canvas.drawPath(path, stroke);
          _arrowDown(canvas, fill, ex, b.top);
          if (edge.label != null) {
            _label(
              canvas,
              edge.label!,
              Offset(((laneX ?? sx) + ex) / 2, midY),
            );
          }
        case FlowRoute.loopBottom:
          final double sx = a.center.dx + (edge.fromOffset ?? 0);
          final double ex = b.center.dx + (edge.toOffset ?? 0);
          final double laneY =
              math.max(a.bottom, b.bottom) + (edge.laneOffset ?? 28);
          canvas.drawPath(
            Path()
              ..moveTo(sx, a.bottom)
              ..lineTo(sx, laneY)
              ..lineTo(ex, laneY)
              ..lineTo(ex, b.bottom + 6),
            stroke,
          );
          _arrowUp(canvas, fill, ex, b.bottom);
          if (edge.label != null) {
            _label(canvas, edge.label!, Offset((sx + ex) / 2, laneY));
          }
        case FlowRoute.loopRight:
          final double laneX =
              math.max(a.right, b.right) + (edge.laneOffset ?? 32);
          canvas.drawPath(
            Path()
              ..moveTo(a.right, a.center.dy)
              ..lineTo(laneX, a.center.dy)
              ..lineTo(laneX, b.center.dy)
              ..lineTo(b.right + 6, b.center.dy),
            stroke,
          );
          _arrowLeft(canvas, fill, b.right, b.center.dy);
          if (edge.label != null) {
            _label(
              canvas,
              edge.label!,
              Offset(laneX, (a.center.dy + b.center.dy) / 2),
            );
          }
      }
    }
  }

  FlowNode? _node(String id) =>
      nodes.where((FlowNode node) => node.id == id).firstOrNull;

  void _arrowDown(Canvas canvas, Paint fill, double x, double tipY) {
    canvas.drawPath(
      Path()
        ..moveTo(x - 3.5, tipY - 6)
        ..lineTo(x + 3.5, tipY - 6)
        ..lineTo(x, tipY)
        ..close(),
      fill,
    );
  }

  void _arrowUp(Canvas canvas, Paint fill, double x, double tipY) {
    canvas.drawPath(
      Path()
        ..moveTo(x - 3.5, tipY + 6)
        ..lineTo(x + 3.5, tipY + 6)
        ..lineTo(x, tipY)
        ..close(),
      fill,
    );
  }

  void _arrowLeft(Canvas canvas, Paint fill, double tipX, double y) {
    canvas.drawPath(
      Path()
        ..moveTo(tipX + 6, y - 3.5)
        ..lineTo(tipX + 6, y + 3.5)
        ..lineTo(tipX, y)
        ..close(),
      fill,
    );
  }

  void _label(Canvas canvas, String text, Offset at) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 12, color: labelColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final Rect box = Rect.fromCenter(
      center: at,
      width: painter.width + 12,
      height: painter.height,
    );
    canvas.drawRect(box, Paint()..color = labelBackground);
    painter.paint(
      canvas,
      Offset(box.left + 6, box.top),
    );
  }

  @override
  bool shouldRepaint(AuiFlowEdgePainter oldDelegate) {
    if (oldDelegate.edges.length != edges.length ||
        oldDelegate.nodes.length != nodes.length) {
      return true;
    }
    for (int i = 0; i < nodes.length; i++) {
      if (oldDelegate.nodes[i].rect != nodes[i].rect) return true;
    }
    return oldDelegate.color != color;
  }
}
