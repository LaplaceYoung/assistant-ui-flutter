import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'flow_expand.dart';
import 'surfaces.dart';
import 'theme.dart';

/// How a flow node is shaped.
enum FlowNodeVariant { box, decision }

/// Accent of a flow node.
enum FlowTone { neutral, pink, blue, red, green }

/// A diagram node with a tone and an optional diamond shape — the `flow`
/// element's node.
class AssistantFlowNode extends StatelessWidget {
  const AssistantFlowNode({
    super.key,
    required this.label,
    this.variant = FlowNodeVariant.box,
    this.tone = FlowTone.neutral,
  });

  final String label;
  final FlowNodeVariant variant;
  final FlowTone tone;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final Color accent = switch (tone) {
      FlowTone.neutral => theme.border,
      FlowTone.pink => const Color(0xFFEC4899).withValues(alpha: 0.6),
      FlowTone.blue => const Color(0xFF3B82F6).withValues(alpha: 0.6),
      FlowTone.red => const Color(0xFFEF4444).withValues(alpha: 0.6),
      FlowTone.green => const Color(0xFF22C55E).withValues(alpha: 0.6),
    };
    final Color fill = tone == FlowTone.neutral
        ? theme.background
        : accent.withValues(alpha: 0.1);
    final EdgeInsets padding = variant == FlowNodeVariant.decision
        ? const EdgeInsets.symmetric(horizontal: 32, vertical: 16)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 6);

    final Widget text = Text(
      label,
      style: TextStyle(
        fontSize: 14,
        height: 1.2,
        color: theme.foreground,
      ),
    );

    if (variant == FlowNodeVariant.decision) {
      return SizedBox(
        height: 56,
        child: CustomPaint(
          painter: _DiamondPainter(fill: fill, stroke: accent),
          child: Padding(
            padding: padding,
            child: Center(child: text),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: accent),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: padding,
      child: text,
    );
  }
}

class _DiamondPainter extends CustomPainter {
  _DiamondPainter({required this.fill, required this.stroke});

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    // Upstream draws `50,1 99,50 50,99 1,50` stretched over the node box.
    final Path path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.01)
      ..lineTo(size.width * 0.99, size.height * 0.5)
      ..lineTo(size.width * 0.5, size.height * 0.99)
      ..lineTo(size.width * 0.01, size.height * 0.5)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_DiamondPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.stroke != stroke;
}

/// A labelled connector between two nodes.
class AssistantFlowArrow extends StatelessWidget {
  const AssistantFlowArrow({
    super.key,
    this.label,
    this.reverseLabel,
    this.down = false,
    this.length = 88,
  });

  final String? label;

  /// Second label, on a second line running the other way.
  final String? reverseLabel;

  final bool down;
  final double length;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final Color color = theme.mutedForeground.withValues(alpha: 0.7);

    if (down) {
      return SizedBox(
        height: length,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            CustomPaint(
              size: Size(10, length),
              painter: _ArrowPainter(color: color, down: true),
            ),
            if (label != null)
              Positioned(
                left: 18,
                top: length / 2 - 8,
                child: Text(
                  label!,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: theme.mutedForeground,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (label != null)
          Text(
            label!,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              color: theme.mutedForeground,
            ),
          ),
        CustomPaint(
          size: Size(length, 10),
          painter: _ArrowPainter(color: color, down: false),
        ),
        if (reverseLabel != null) ...<Widget>[
          CustomPaint(
            size: Size(length, 10),
            painter: _ArrowPainter(color: color, down: false, reverse: true),
          ),
          Text(
            reverseLabel!,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              color: theme.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.color, required this.down, this.reverse = false});

  final Color color;
  final bool down;
  final bool reverse;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    final Paint fill = Paint()..color = color;
    if (down) {
      final double tip = size.height;
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, tip - 6),
        stroke,
      );
      canvas.drawPath(
        Path()
          ..moveTo(size.width / 2 - 3.5, tip - 7)
          ..lineTo(size.width / 2, tip)
          ..lineTo(size.width / 2 + 3.5, tip - 7)
          ..close(),
        fill,
      );
      return;
    }
    final double tip = reverse ? 0 : size.width;
    canvas.drawLine(
      Offset(reverse ? 6 : 0, size.height / 2),
      Offset(tip, size.height / 2),
      stroke,
    );
    canvas.drawPath(
      Path()
        ..moveTo(reverse ? 7 : size.width - 7, size.height / 2 - 3.5)
        ..lineTo(tip, size.height / 2)
        ..lineTo(reverse ? 7 : size.width - 7, size.height / 2 + 3.5)
        ..close(),
      fill,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.down != down ||
      oldDelegate.reverse != reverse;
}

/// A dashed box that groups nodes, with a label riding its top edge.
class AssistantFlowGroup extends StatelessWidget {
  const AssistantFlowGroup({super.key, required this.label, this.child});

  final String label;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Container(
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            border: Border.all(color: theme.border),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: child ?? const SizedBox.shrink(),
        ),
        Positioned(
          left: 12,
          top: 0,
          child: Container(
            color: theme.background,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                height: 1.2,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
                color: theme.mutedForeground,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The frame a flow diagram sits in: a scrollable canvas with the expand
/// surface — the `flow` element's root.
class AssistantFlow extends StatelessWidget {
  const AssistantFlow({super.key, required this.child, this.llmCode});

  final Widget child;

  /// The Mermaid source behind the diagram, when the model wrote one; shown
  /// above the drawing the way upstream renders it.
  final String? llmCode;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (llmCode != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: auiField(theme, radius: 8),
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(llmCode!, style: theme.code(context)),
                ),
              ),
            ),
          AssistantFlowExpand(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A row of flow nodes.
class AssistantFlowRow extends StatelessWidget {
  const AssistantFlowRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (final (int index, Widget child) in children.indexed) ...<Widget>[
          if (index > 0) const SizedBox(width: 12),
          child,
        ],
      ],
    );
  }
}

/// A column of flow nodes.
class AssistantFlowColumn extends StatelessWidget {
  const AssistantFlowColumn({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (final (int index, Widget child) in children.indexed) ...<Widget>[
          if (index > 0) const SizedBox(height: 12),
          child,
        ],
      ],
    );
  }
}

/// Sizes the canvas of a flow to its content, for hosts that compose one by
/// hand.
double auiFlowNodeWidth(String label) {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: label,
      style: const TextStyle(fontSize: 14),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  return math.max(64, painter.width + 28);
}
