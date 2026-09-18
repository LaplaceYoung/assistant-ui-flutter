import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Which way a diagram flows.
enum MermaidDirection { topDown, leftRight }

/// One node of a parsed flowchart.
@immutable
class MermaidNode {
  const MermaidNode({
    required this.id,
    required this.label,
    this.shape = MermaidShape.box,
  });

  final String id;
  final String label;
  final MermaidShape shape;
}

/// The shapes the common subset uses.
enum MermaidShape { box, rounded, stadium, decision }

/// One edge.
@immutable
class MermaidEdge {
  const MermaidEdge({required this.from, required this.to, this.label});

  final String from;
  final String to;
  final String? label;
}

/// A parsed flowchart: the subset of Mermaid a Dart renderer can lay out
/// without the JavaScript engine — node declarations, chains and labelled
/// edges for `graph` / `flowchart` in `TD`, `TB` or `LR`.
@immutable
class MermaidFlowchart {
  const MermaidFlowchart({
    required this.direction,
    required this.nodes,
    required this.edges,
  });

  final MermaidDirection direction;
  final List<MermaidNode> nodes;
  final List<MermaidEdge> edges;

  bool get isEmpty => nodes.isEmpty;

  /// Parses the source, or returns null when it is not a flowchart this
  /// renderer understands (another diagram type, or syntax it cannot read).
  static MermaidFlowchart? parse(String source) {
    final List<String> lines = source
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    final RegExp header = RegExp(
      r'^(graph|flowchart)\s+(TD|TB|BT|LR|RL)?',
      caseSensitive: false,
    );
    final RegExpMatch? match = header.firstMatch(lines.first);
    if (match == null) return null;
    final String token = (match.group(2) ?? 'TD').toUpperCase();
    final MermaidDirection direction =
        (token == 'LR' || token == 'RL') ? MermaidDirection.leftRight : MermaidDirection.topDown;

    final Map<String, MermaidNode> nodes = <String, MermaidNode>{};
    final List<MermaidEdge> edges = <MermaidEdge>[];

    // `A[Label] -->|edge label| B(Label) --> C`
    final RegExp nodePattern = RegExp(
      r'^([A-Za-z0-9_\-]+)\s*(\[\[?[^\]]*\]?\]|\(\[[^\]]*\]\)|\(\([^)]*\)\)|\([^)]*\)|\{[^}]*\})?',
    );

    MermaidNode? readNode(String tokenText) {
      final RegExpMatch? node = nodePattern.firstMatch(tokenText.trim());
      if (node == null) return null;
      final String id = node.group(1)!;
      final String? raw = node.group(2);
      String label = id;
      MermaidShape shape = MermaidShape.box;
      if (raw != null && raw.isNotEmpty) {
        final String inner = raw
            .replaceAll(RegExp(r'^[\(\[\{]\+'), '')
            .replaceAll(RegExp(r'[\)\]\}]+$'), '');
        label = inner.isNotEmpty ? inner : id;
        if (raw.startsWith('{')) {
          shape = MermaidShape.decision;
        } else if (raw.startsWith('([') || raw.startsWith('((')) {
          shape = MermaidShape.stadium;
        } else if (raw.startsWith('(')) {
          shape = MermaidShape.rounded;
        }
      }
      return MermaidNode(id: id, label: label, shape: shape);
    }

    void remember(MermaidNode node) {
      final MermaidNode? existing = nodes[node.id];
      // A later declaration with a real label wins over a bare mention.
      if (existing == null || (existing.label == existing.id && node.label != node.id)) {
        nodes[node.id] = node;
      }
    }

    final RegExp edgeSplit = RegExp(r'\s*(-{1,3}>|={1,3}>|-\.->)\s*(\|[^|]*\|)?\s*');
    for (final String line in lines.skip(1)) {
      if (line.startsWith('%%') || line.startsWith('subgraph') || line.startsWith('end')) {
        continue;
      }
      // Split the line into node tokens and the arrows between them.
      final List<String> parts = <String>[];
      final List<String?> labels = <String?>[];
      int cursor = 0;
      for (final RegExpMatch edge in edgeSplit.allMatches(line)) {
        parts.add(line.substring(cursor, edge.start));
        labels.add(edge.group(2));
        cursor = edge.end;
      }
      parts.add(line.substring(cursor));
      if (parts.length == 1) {
        final MermaidNode? single = readNode(parts.first);
        if (single != null) remember(single);
        continue;
      }
      MermaidNode? previous;
      for (int i = 0; i < parts.length; i++) {
        final MermaidNode? node = readNode(parts[i]);
        if (node == null) return null;
        remember(node);
        if (previous != null) {
          final String? raw = labels[i - 1];
          edges.add(
            MermaidEdge(
              from: previous.id,
              to: node.id,
              label: raw == null
                  ? null
                  : raw.replaceAll('|', '').trim().isEmpty
                      ? null
                      : raw.replaceAll('|', '').trim(),
            ),
          );
        }
        previous = node;
      }
    }

    if (nodes.isEmpty) return null;
    return MermaidFlowchart(
      direction: direction,
      nodes: nodes.values.toList(),
      edges: edges,
    );
  }

  /// The layer each node sits in: roots at 0, then one step per edge.
  Map<String, int> layers() {
    final Map<String, int> depth = <String, int>{};
    final Set<String> incoming = <String>{
      for (final MermaidEdge edge in edges) edge.to,
    };
    for (final MermaidNode node in nodes) {
      if (!incoming.contains(node.id)) depth[node.id] = 0;
    }
    if (depth.isEmpty && nodes.isNotEmpty) depth[nodes.first.id] = 0;

    // Relax along the edges until nothing moves (bounded: node count).
    for (int pass = 0; pass < nodes.length; pass++) {
      bool moved = false;
      for (final MermaidEdge edge in edges) {
        final int? from = depth[edge.from];
        if (from == null) continue;
        final int candidate = from + 1;
        if ((depth[edge.to] ?? -1) < candidate) {
          depth[edge.to] = candidate;
          moved = true;
        }
      }
      if (!moved) break;
    }
    for (final MermaidNode node in nodes) {
      depth.putIfAbsent(node.id, () => 0);
    }
    return depth;
  }
}

/// Draws a parsed flowchart: boxes laid out by layer, arrows between them.
///
/// This is the Dart stand-in for Mermaid itself, covering the flowchart subset
/// a chat answer usually emits; anything outside it is reported as unsupported
/// so the element can show the source instead.
class AssistantMermaidFlowchart extends StatelessWidget {
  const AssistantMermaidFlowchart({
    super.key,
    required this.chart,
    this.nodeWidth = 150,
    this.nodeHeight = 40,
    this.gap = 46,
    this.fontFamily,
  });

  /// The family the labels are drawn in; null lets the platform decide.
  final String? fontFamily;

  final MermaidFlowchart chart;
  final double nodeWidth;
  final double nodeHeight;

  /// Space between layers.
  final double gap;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final Map<String, int> depth = chart.layers();
    final int layers = depth.values.fold<int>(0, math.max) + 1;
    final Map<int, List<MermaidNode>> byLayer = <int, List<MermaidNode>>{};
    for (final MermaidNode node in chart.nodes) {
      byLayer.putIfAbsent(depth[node.id]!, () => <MermaidNode>[]).add(node);
    }
    final int widest = byLayer.values.fold<int>(1, (int a, List<MermaidNode> b) => math.max(a, b.length));

    // The layer axis runs with the node's height when the flow goes down and
    // with its width when it goes across.
    final bool down = chart.direction == MermaidDirection.topDown;
    final double alongExtent = down ? nodeHeight : nodeWidth;
    final double acrossExtent = down ? nodeWidth : nodeHeight;
    final double along = layers * alongExtent + (layers - 1) * gap;
    final double across = widest * acrossExtent + (widest - 1) * 28;
    final Size size = down ? Size(across, along) : Size(along, across);

    return CustomPaint(
      size: size,
      painter: _FlowchartPainter(
        chart: chart,
        depth: depth,
        theme: theme,
        nodeWidth: nodeWidth,
        nodeHeight: nodeHeight,
        gap: gap,
        textDirection: Directionality.of(context),
      ),
    );
  }
}

class _FlowchartPainter extends CustomPainter {
  _FlowchartPainter({
    required this.chart,
    required this.depth,
    required this.theme,
    required this.nodeWidth,
    required this.nodeHeight,
    required this.gap,
    required this.textDirection,
  });

  final MermaidFlowchart chart;
  final Map<String, int> depth;
  final AssistantTheme theme;
  final double nodeWidth;
  final double nodeHeight;
  final double gap;
  final TextDirection textDirection;

  final Map<String, Rect> _boxes = <String, Rect>{};
  final Map<String, TextPainter> _labels = <String, TextPainter>{};

  @override
  void paint(Canvas canvas, Size size) {
    _layout();
    _paintEdges(canvas);
    _paintNodes(canvas);
  }

  void _layout() {
    _boxes.clear();
    final Map<int, List<MermaidNode>> byLayer = <int, List<MermaidNode>>{};
    for (final MermaidNode node in chart.nodes) {
      byLayer.putIfAbsent(depth[node.id]!, () => <MermaidNode>[]).add(node);
    }
    final bool down = chart.direction == MermaidDirection.topDown;
    final double alongExtent = down ? nodeHeight : nodeWidth;
    final double acrossExtent = down ? nodeWidth : nodeHeight;
    for (final MapEntry<int, List<MermaidNode>> entry in byLayer.entries) {
      final int layer = entry.key;
      final List<MermaidNode> nodes = entry.value;
      for (int i = 0; i < nodes.length; i++) {
        final double alongStart = layer * (alongExtent + gap) + gap / 2;
        final double acrossStart = i * (acrossExtent + 28);
        final Rect rect = down
            ? Rect.fromLTWH(acrossStart, alongStart, nodeWidth, nodeHeight)
            : Rect.fromLTWH(alongStart, acrossStart, nodeWidth, nodeHeight);
        _boxes[nodes[i].id] = rect;
        _labels[nodes[i].id] = _text(nodes[i].label, theme.foreground);
      }
    }
  }

  TextPainter _text(String value, Color color) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: textDirection,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: nodeWidth - 16);
    return painter;
  }

  void _paintNodes(Canvas canvas) {
    for (final MapEntry<String, Rect> entry in _boxes.entries) {
      final MermaidNode node =
          chart.nodes.firstWhere((MermaidNode n) => n.id == entry.key);
      final Rect rect = entry.value;
      final Paint fill = Paint()..color = theme.muted;
      final Paint stroke = Paint()
        ..color = theme.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      switch (node.shape) {
        case MermaidShape.box:
          canvas.drawRect(rect, fill);
          canvas.drawRect(rect, stroke);
        case MermaidShape.rounded:
        case MermaidShape.stadium:
          final RRect rrect = RRect.fromRectAndRadius(
            rect,
            Radius.circular(node.shape == MermaidShape.stadium ? nodeHeight / 2 : 8),
          );
          canvas.drawRRect(rrect, fill);
          canvas.drawRRect(rrect, stroke);
        case MermaidShape.decision:
          final Path path = Path()
            ..moveTo(rect.center.dx, rect.top)
            ..lineTo(rect.right, rect.center.dy)
            ..lineTo(rect.center.dx, rect.bottom)
            ..lineTo(rect.left, rect.center.dy)
            ..close();
          canvas.drawPath(path, fill);
          canvas.drawPath(path, stroke);
      }
      final TextPainter label = _labels[entry.key]!;
      label.paint(
        canvas,
        Offset(
          rect.center.dx - label.width / 2,
          rect.center.dy - label.height / 2,
        ),
      );
    }
  }

  void _paintEdges(Canvas canvas) {
    final Paint line = Paint()
      ..color = theme.mutedForeground
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    for (final MermaidEdge edge in chart.edges) {
      final Rect? from = _boxes[edge.from];
      final Rect? to = _boxes[edge.to];
      if (from == null || to == null) continue;
      final bool down = chart.direction == MermaidDirection.topDown;
      final Offset start = down
          ? Offset(from.center.dx, from.bottom)
          : Offset(from.right, from.center.dy);
      final Offset end = down
          ? Offset(to.center.dx, to.top)
          : Offset(to.left, to.center.dy);

      final Path path = Path()..moveTo(start.dx, start.dy);
      if (down) {
        final double midY = (start.dy + end.dy) / 2;
        path
          ..lineTo(start.dx, midY)
          ..lineTo(end.dx, midY)
          ..lineTo(end.dx, end.dy);
      } else {
        final double midX = (start.dx + end.dx) / 2;
        path
          ..lineTo(midX, start.dy)
          ..lineTo(midX, end.dy)
          ..lineTo(end.dx, end.dy);
      }
      canvas.drawPath(path, line);

      // Arrow head.
      final Path head = Path();
      const double size = 6;
      if (down) {
        head
          ..moveTo(end.dx, end.dy)
          ..lineTo(end.dx - size / 2, end.dy - size)
          ..lineTo(end.dx + size / 2, end.dy - size)
          ..close();
      } else {
        head
          ..moveTo(end.dx, end.dy)
          ..lineTo(end.dx - size, end.dy - size / 2)
          ..lineTo(end.dx - size, end.dy + size / 2)
          ..close();
      }
      canvas.drawPath(
        head,
        Paint()..color = theme.mutedForeground,
      );

      final String? label = edge.label;
      if (label != null && label.isNotEmpty) {
        final TextPainter painter = _text(label, theme.mutedForeground);
        painter.paint(
          canvas,
          Offset((start.dx + end.dx) / 2 - painter.width / 2, (start.dy + end.dy) / 2 - 10),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FlowchartPainter oldDelegate) =>
      oldDelegate.chart != chart || oldDelegate.theme != theme;
}
