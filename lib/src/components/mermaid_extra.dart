import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'mermaid_renderer.dart';
import 'theme.dart';

/// A parsed `pie` diagram: a title and the labelled slices under it.
class MermaidPie {
  const MermaidPie({required this.segments, this.title, this.showData = false});

  final String? title;
  final List<MermaidPieSegment> segments;

  /// `showData` in the source prints the raw value beside the percentage.
  final bool showData;

  bool get isEmpty => segments.isEmpty;

  double get total =>
      segments.fold<double>(0, (double sum, MermaidPieSegment s) => sum + s.value);

  /// Parses `pie [showData] [title …]` followed by `"Label" : value` lines.
  ///
  /// Returns null when the source is not a pie diagram or a slice cannot be
  /// read, so the caller can fall back to the source.
  static MermaidPie? parse(String source) {
    final List<String> lines = source
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;
    final String head = lines.first.toLowerCase();
    if (!head.startsWith('pie')) return null;

    bool showData = false;
    String? title;
    final RegExp titlePattern = RegExp(r'title\s+(.+)$', caseSensitive: false);
    for (final String token in lines.first.split(RegExp(r'\s+'))) {
      if (token.toLowerCase() == 'showdata') showData = true;
    }
    title = titlePattern.firstMatch(lines.first)?.group(1)?.trim();

    final List<MermaidPieSegment> segments = <MermaidPieSegment>[];
    final RegExp slice = RegExp(r'^"([^"]*)"\s*:\s*(-?[\d.]+)$');
    for (final String line in lines.skip(1)) {
      final RegExpMatch? match = slice.firstMatch(line);
      if (match == null) continue;
      final double? value = double.tryParse(match.group(2)!);
      if (value == null) return null;
      segments.add(MermaidPieSegment(label: match.group(1)!, value: value));
    }
    if (segments.isEmpty) return null;
    return MermaidPie(segments: segments, title: title, showData: showData);
  }
}

/// One slice: the label Mermaid prints in the legend, and its value.
class MermaidPieSegment {
  const MermaidPieSegment({required this.label, required this.value});

  final String label;
  final double value;
}

/// Draws a parsed pie: the donut on the left, the legend on the right.
///
/// The slices take the same eight-colour rotation Mermaid uses, so a diagram
/// reads the same as it does in a browser.
class AssistantMermaidPie extends StatelessWidget {
  const AssistantMermaidPie({super.key, required this.pie, this.size = 180});

  final MermaidPie pie;
  final double size;

  /// Mermaid's default palette, in order.
  static const List<Color> palette = <Color>[
    Color(0xFFECECFF),
    Color(0xFFE8E8FF),
    Color(0xFFF5F5FF),
    Color(0xFFDDDDEE),
    Color(0xFFD0D0E8),
    Color(0xFFC4C4E0),
    Color(0xFFB8B8D8),
    Color(0xFFACACD0),
  ];

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    if (pie.isEmpty || pie.total <= 0) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (pie.title != null) ...<Widget>[
          Text(
            pie.title!,
            style: theme.body(context).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: size,
              height: size,
              child: CustomPaint(
                painter: _PiePainter(
                  segments: pie.segments,
                  total: pie.total,
                  stroke: theme.background,
                  dark: dark,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final (int index, MermaidPieSegment segment)
                    in pie.segments.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: _slice(index, dark),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: theme.border),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          segment.label,
                          style: theme.small(context)
                              .copyWith(color: theme.foreground),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          pie.showData
                              ? '${_percent(segment.value)} · ${_number(segment.value)}'
                              : _percent(segment.value),
                          style: theme.small(context).copyWith(
                            color: theme.mutedForeground,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static Color _slice(int index, bool dark) {
    final Color base = palette[index % palette.length];
    // The palette is a sequence of pale violets; on dark ground the same order
    // reads as a deeper rotation so the slices stay apart.
    return dark ? Color.lerp(base, const Color(0xFF6E6ED8), 0.55)! : base;
  }

  static String _percent(double value) => '${value.round()}%';

  static String _number(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';
}

class _PiePainter extends CustomPainter {
  _PiePainter({
    required this.segments,
    required this.total,
    required this.stroke,
    required this.dark,
  });

  final List<MermaidPieSegment> segments;
  final double total;
  final Color stroke;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Rect arc = rect.deflate(2);
    double start = -math.pi / 2;
    final Paint paint = Paint()..style = PaintingStyle.fill;
    final Paint divider = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = stroke;

    final double sum = segments.fold<double>(
      0,
      (double acc, MermaidPieSegment s) => acc + (s.value <= 0 ? 0 : s.value),
    );
    for (final (int index, MermaidPieSegment segment) in segments.indexed) {
      if (segment.value <= 0) continue;
      final double sweep = (segment.value / sum) * 2 * math.pi;
      paint.color = AssistantMermaidPie._slice(index, dark);
      canvas.drawArc(arc, start, sweep, true, paint);
      canvas.drawArc(arc, start, sweep, true, divider);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_PiePainter old) =>
      old.total != total || old.segments != segments || old.dark != dark;
}

/// A parsed `sequenceDiagram`: who is talking, in what order, saying what.
class MermaidSequence {
  const MermaidSequence({required this.participants, required this.messages});

  /// The lifelines, in the order they first appear.
  final List<String> participants;
  final List<MermaidSequenceMessage> messages;

  bool get isEmpty => participants.isEmpty || messages.isEmpty;

  /// Parses `sequenceDiagram`, `participant` declarations and the arrow lines.
  ///
  /// Understood: `->>` solid, `-->>` dashed, `-)` open, self-messages, and
  /// `Note over A, B: …`. Anything else returns null so the caller falls back.
  static MermaidSequence? parse(String source) {
    final List<String> lines = source
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;
    if (!lines.first.toLowerCase().startsWith('sequencediagram')) return null;

    final List<String> order = <String>[];
    final Map<String, String> alias = <String, String>{};
    void see(String name) {
      if (!order.contains(name)) order.add(name);
    }

    final List<MermaidSequenceMessage> messages = <MermaidSequenceMessage>[];
    final RegExp arrow = RegExp(
      r'^(\w+)\s*(-->>|->>|-->|->|-\)|--\))\s*(\w+)\s*:\s*(.+)$',
    );
    final RegExp note = RegExp(r'^note\s+(over|left of|right of)\s+([^:]+):\s*(.+)$',
        caseSensitive: false);

    for (final String line in lines.skip(1)) {
      final String lower = line.toLowerCase();
      if (lower.startsWith('participant ') || lower.startsWith('actor ')) {
        final List<String> parts =
            line.split(RegExp(r'\s+as\s+', caseSensitive: false));
        final String id = parts.first.split(RegExp(r'\s+')).last.trim();
        final String name = parts.length > 1 ? parts[1].trim() : id;
        alias[id] = name;
        see(id);
        continue;
      }
      final RegExpMatch? asNote = note.firstMatch(line);
      if (asNote != null) {
        final List<String> targets = asNote
            .group(2)!
            .split(',')
            .map((String s) => s.trim())
            .where((String s) => s.isNotEmpty)
            .toList();
        for (final String target in targets) {
          see(target);
        }
        messages.add(
          MermaidSequenceMessage(
            from: targets.first,
            to: targets.last,
            text: asNote.group(3)!.trim(),
            note: true,
          ),
        );
        continue;
      }
      final RegExpMatch? match = arrow.firstMatch(line);
      if (match == null) {
        if (lower.startsWith('loop') ||
            lower.startsWith('alt') ||
            lower.startsWith('end') ||
            lower.startsWith('activate') ||
            lower.startsWith('deactivate')) {
          // Control blocks are read past: the messages inside still draw.
          continue;
        }
        return null;
      }
      see(match.group(1)!);
      see(match.group(3)!);
      messages.add(
        MermaidSequenceMessage(
          from: match.group(1)!,
          to: match.group(3)!,
          text: match.group(4)!.trim(),
          dashed: match.group(2)!.startsWith('--'),
          open: match.group(2)!.endsWith(')'),
        ),
      );
    }

    if (order.isEmpty || messages.isEmpty) return null;
    return MermaidSequence(
      participants: <String>[
        for (final String id in order) alias[id] ?? id,
      ],
      messages: messages,
    );
  }
}

/// One arrow (or note) between two lifelines.
class MermaidSequenceMessage {
  const MermaidSequenceMessage({
    required this.from,
    required this.to,
    required this.text,
    this.dashed = false,
    this.open = false,
    this.note = false,
  });

  final String from;
  final String to;
  final String text;
  final bool dashed;
  final bool open;
  final bool note;
}

/// Draws a parsed sequence: boxes on top, lifelines under them, arrows between.
class AssistantMermaidSequence extends StatelessWidget {
  const AssistantMermaidSequence({
    super.key,
    required this.sequence,
    this.laneWidth = 150,
    this.rowHeight = 46,
  });

  final MermaidSequence sequence;
  final double laneWidth;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    if (sequence.isEmpty) return const SizedBox.shrink();
    final double height = 56 + sequence.messages.length * rowHeight + 24;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: sequence.participants.length * laneWidth + 40,
          height: height,
          child: CustomPaint(
            painter: _SequencePainter(
              sequence: sequence,
              laneWidth: laneWidth,
              rowHeight: rowHeight,
              theme: theme,
            ),
          ),
        ),
      ],
    );
  }
}

class _SequencePainter extends CustomPainter {
  _SequencePainter({
    required this.sequence,
    required this.laneWidth,
    required this.rowHeight,
    required this.theme,
  });

  final MermaidSequence sequence;
  final double laneWidth;
  final double rowHeight;
  final AssistantTheme theme;

  double _lane(String name) {
    final int index = sequence.participants.indexOf(name);
    return 20 + laneWidth / 2 + index * laneWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..color = theme.border
      ..strokeWidth = 1.5;
    final Paint box = Paint()
      ..color = theme.muted
      ..style = PaintingStyle.fill;
    final Paint boxEdge = Paint()
      ..color = theme.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Lifelines first, so the boxes sit over them.
    for (int i = 0; i < sequence.participants.length; i++) {
      final double x = _lane(sequence.participants[i]);
      canvas.drawLine(Offset(x, 40), Offset(x, size.height - 8), line);
    }

    // The boxes name the participants.
    for (final String name in sequence.participants) {
      final double x = _lane(name);
      final Rect rect = Rect.fromCenter(
        center: Offset(x, 28),
        width: laneWidth - 24,
        height: 32,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        box,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        boxEdge,
      );
      _text(
        canvas,
        name,
        Offset(rect.center.dx, rect.center.dy),
        theme.foreground,
        center: true,
      );
    }

    // Then the messages, one row each.
    for (final (int index, MermaidSequenceMessage message)
        in sequence.messages.indexed) {
      final double y = 72 + index * rowHeight;
      if (message.note) {
        final double left = _lane(message.from);
        final double right = _lane(message.to);
        final double cx = message.from == message.to
            ? left + laneWidth * 0.6
            : (left + right) / 2;
        final Rect rect = Rect.fromCenter(
          center: Offset(cx, y),
          width: laneWidth - 16,
          height: 30,
        );
        final Paint fill = Paint()..color = theme.muted;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          boxEdge,
        );
        _text(canvas, message.text, Offset(cx, y), theme.foreground,
            center: true, maxWidth: rect.width - 12);
        continue;
      }

      final double from = _lane(message.from);
      final double to = _lane(message.to);
      if (from != to) {
        _arrow(canvas, theme, from, to, y, message);
        final double mid = (from + to) / 2;
        _text(
          canvas,
          message.text,
          Offset(mid, y - 10),
          theme.foreground,
          center: true,
          maxWidth: (to - from).abs().abs() - 12,
        );
      } else {
        // A self-message loops out and back.
        final Path loop = Path()
          ..moveTo(from, y - 8)
          ..lineTo(from + 44, y - 8)
          ..lineTo(from + 44, y + 8)
          ..lineTo(from + 4, y + 8);
        canvas.drawPath(
          loop,
          Paint()
            ..color = theme.mutedForeground
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        _text(canvas, message.text, Offset(from + 52, y), theme.foreground,
            maxWidth: laneWidth - 60);
      }
    }
  }

  void _arrow(
    Canvas canvas,
    AssistantTheme theme,
    double from,
    double to,
    double y,
    MermaidSequenceMessage message,
  ) {
    final bool rightwards = to > from;
    final double start = from + (rightwards ? 6 : -6);
    final double end = to - (rightwards ? 10 : -10);
    final Paint stroke = Paint()
      ..color = theme.mutedForeground
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    if (message.dashed) {
      // A dashed run, drawn as short segments so it reads as a reply.
      const double dash = 6;
      const double gap = 4;
      final double length = (end - start).abs();
      final double step = rightwards ? 1 : -1;
      double at = 0;
      while (at < length) {
        final double seg = math.min(dash, length - at);
        canvas.drawLine(
          Offset(start + step * at, y),
          Offset(start + step * (at + seg), y),
          stroke,
        );
        at += dash + gap;
      }
    } else {
      canvas.drawLine(Offset(start, y), Offset(end, y), stroke);
    }
    // The head: a filled triangle, or an open one for `-)`.
    final Path head = Path();
    if (rightwards) {
      head
        ..moveTo(end + 10, y)
        ..lineTo(end, y - 5)
        ..lineTo(end, y + 5);
    } else {
      head
        ..moveTo(end - 10, y)
        ..lineTo(end, y - 5)
        ..lineTo(end, y + 5);
    }
    head.close();
    canvas.drawPath(
      head,
      Paint()
        ..color = theme.mutedForeground
        ..style = message.open ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 1.5,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset at,
    Color color, {
    bool center = false,
    double? maxWidth,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 12, height: 1.2, color: color),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
      textAlign: center ? TextAlign.center : TextAlign.start,
    )..layout(maxWidth: maxWidth ?? 400);
    painter.paint(
      canvas,
      center
          ? Offset(at.dx - painter.width / 2, at.dy - painter.height / 2)
          : at,
    );
  }

  @override
  bool shouldRepaint(_SequencePainter old) =>
      old.sequence != sequence || old.theme != theme;
}

/// Parses `stateDiagram-v2` into the flowchart the built-in painter already
/// knows how to lay out: states become rounded nodes, `[*]` becomes a start or
/// end marker, and the labelled transitions become edges.
///
/// Composite states (`state X { … }`) are read past, so the transitions inside
/// them still draw; the grouping itself is not painted.
MermaidStateDiagram? parseStateDiagram(String source) {
  final List<String> lines = source
      .split('\n')
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty)
      .toList();
  if (lines.isEmpty) return null;
  final String head = lines.first.toLowerCase();
  if (!head.startsWith('statediagram')) return null;

  const String start = '__start';
  const String end = '__end';
  final Map<String, MermaidNode> nodes = <String, MermaidNode>{};
  final List<MermaidEdge> edges = <MermaidEdge>[];

  void see(String id, {MermaidShape? shape}) {
    nodes.putIfAbsent(
      id,
      () => MermaidNode(
        id: id,
        label: id == start || id == end ? '' : id,
        shape: shape ?? MermaidShape.rounded,
      ),
    );
  }

  final RegExp transition =
      RegExp(r'^(\[\*\]|\w+)\s*-->\s*(\[\*\]|\w+)\s*(?::\s*(.+))?$');
  for (final String line in lines.skip(1)) {
    final String lower = line.toLowerCase();
    if (lower.startsWith('state ') ||
        lower == '}' ||
        lower.startsWith('direction ') ||
        lower.startsWith('note ')) {
      // Composite headers, their closing brace, and notes: read past.
      continue;
    }
    final RegExpMatch? match = transition.firstMatch(line);
    if (match == null) return null;
    final String rawFrom = match.group(1)!;
    final String rawTo = match.group(2)!;
    final String from = rawFrom == '[*]' ? start : rawFrom;
    final String to = rawTo == '[*]' ? end : rawTo;
    see(from, shape: from == start ? MermaidShape.stadium : null);
    see(to, shape: to == end ? MermaidShape.stadium : null);
    final String? label = match.group(3)?.trim();
    edges.add(
      MermaidEdge(
        from: from,
        to: to,
        label: label == null || label.isEmpty ? null : label,
      ),
    );
  }
  if (nodes.isEmpty || edges.isEmpty) return null;
  return MermaidStateDiagram(
    MermaidFlowchart(
      direction: MermaidDirection.leftRight,
      nodes: nodes.values.toList(),
      edges: edges,
    ),
  );
}

/// A parsed state diagram, held as the flowchart that draws it.
class MermaidStateDiagram {
  const MermaidStateDiagram(this.chart);

  final MermaidFlowchart chart;
}
