import 'package:flutter/foundation.dart';

/// Where a span is in its lifecycle. `skipped` is upstream's fourth state: the
/// step was planned and not taken.
enum OpenSpanStatus { running, completed, failed, skipped }

/// One span as it arrives from an exporter.
@immutable
class SpanData {
  const SpanData({
    required this.id,
    required this.name,
    this.parentSpanId,
    this.type = 'span',
    this.status = OpenSpanStatus.running,
    this.startedAt,
    this.endedAt,
    this.latencyMs,
  });

  final String id;

  /// Null, or an id that is not in the set, means the span is a root.
  final String? parentSpanId;
  final String name;

  /// What kind of work this is: `llm`, `tool`, `chain`, `retrieval`, …
  final String type;
  final OpenSpanStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// Overrides the derived latency when the exporter reports one.
  final int? latencyMs;

  /// Reads a span, accepting snake_case and camelCase field names.
  static SpanData? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Object? id = raw['id'] ?? raw['span_id'] ?? raw['spanId'];
    if (id is! String || id.isEmpty) return null;
    Object? pick(String camel, String snake) =>
        raw.containsKey(camel) ? raw[camel] : raw[snake];
    return SpanData(
      id: id,
      name: (raw['name'] as String?) ?? id,
      parentSpanId: (pick('parentSpanId', 'parent_span_id') as String?),
      type: (raw['type'] as String?) ?? 'span',
      status: switch (pick('status', 'status')) {
        'completed' || 'ok' => OpenSpanStatus.completed,
        'failed' || 'error' => OpenSpanStatus.failed,
        'skipped' => OpenSpanStatus.skipped,
        _ => OpenSpanStatus.running,
      },
      startedAt: _time(pick('startedAt', 'started_at') ?? pick('startTime', 'start_time')),
      endedAt: _time(pick('endedAt', 'ended_at') ?? pick('endTime', 'end_time')),
      latencyMs: pick('latencyMs', 'latency_ms') is num
          ? (pick('latencyMs', 'latency_ms')! as num).toInt()
          : null,
    );
  }

  int? get derivedLatencyMs {
    if (latencyMs != null) return latencyMs;
    final DateTime? start = startedAt;
    final DateTime? end = endedAt;
    if (start == null || end == null) return null;
    return end.difference(start).inMilliseconds;
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        if (parentSpanId != null) 'parentSpanId': parentSpanId,
        'type': type,
        'status': status.name,
        if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
        if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
        if (latencyMs != null) 'latencyMs': latencyMs,
      };
}

/// A span inside the tree: the row state a UI reads.
@immutable
class SpanNode {
  const SpanNode({
    required this.data,
    required this.depth,
    required this.children,
    required this.isCollapsed,
  });

  final SpanData data;

  /// Nesting level, 0 for a root.
  final int depth;
  final List<SpanNode> children;
  final bool isCollapsed;

  String get id => data.id;
  String get name => data.name;
  String get type => data.type;
  OpenSpanStatus get status => data.status;
  bool get hasChildren => children.isNotEmpty;
  int? get latencyMs => data.derivedLatencyMs;

  SpanNode copyWith({bool? isCollapsed}) => SpanNode(
        data: data,
        depth: depth,
        children: children,
        isCollapsed: isCollapsed ?? this.isCollapsed,
      );
}

/// The window every bar is placed in.
@immutable
class SpanTimeRange {
  const SpanTimeRange({required this.min, required this.max, required this.unit});

  /// Milliseconds from the tree's first start to the last end.
  final int min;
  final int max;

  /// The instant the tree starts at.
  final DateTime? unit;

  int get span => max - min <= 0 ? 1 : max - min;

  /// Where [node] sits in the window, 0..1.
  ({double start, double width}) placement(SpanNode node) {
    final int start = node.data.startedAt == null || unit == null
        ? 0
        : node.data.startedAt!.difference(unit!).inMilliseconds - min;
    final int duration = node.latencyMs ?? 0;
    return (
      start: (start / span).clamp(0.0, 1.0),
      width: (duration / span).clamp(0.0, 1.0),
    );
  }
}

/// The span tree: parents resolved, depths computed, collapse kept per span.
///
/// Mirrors `SpanResource` in `@assistant-ui/react-o11y`: a span whose parent is
/// missing from the set becomes a root, depth is resolved by walking up the
/// chain with a cache, and the window covers the earliest start to the latest
/// end.
class SpanTree extends ChangeNotifier {
  SpanTree(List<SpanData> spans) {
    _build(spans);
  }

  /// Builds a tree from flattened spans, using the depth they came with.
  factory SpanTree.fromRows(List<({String id, String name, int depth, int startMs, int durationMs})> rows) {
    final List<SpanData> spans = <SpanData>[];
    final List<String?> parents = <String?>[];
    final List<String> byDepth = <String>[];
    final DateTime base = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    for (final row in rows) {
      while (byDepth.length > row.depth) {
        byDepth.removeLast();
      }
      final String? parent = row.depth == 0 ? null : byDepth.lastOrNull;
      byDepth.add(row.id);
      spans.add(
        SpanData(
          id: row.id,
          name: row.name,
          parentSpanId: parent,
          startedAt: base.add(Duration(milliseconds: row.startMs)),
          latencyMs: row.durationMs,
        ),
      );
      parents.add(parent);
    }
    return SpanTree(spans);
  }

  final Map<String, SpanNode> _nodes = <String, SpanNode>{};
  final List<String> _roots = <String>[];
  final Set<String> _collapsed = <String>{};
  SpanTimeRange _range = const SpanTimeRange(min: 0, max: 1, unit: null);

  List<SpanNode> get roots => <SpanNode>[
        for (final String id in _roots) _nodes[id]!,
      ];

  SpanTimeRange get timeRange => _range;

  int get length => _nodes.length;

  SpanNode? byId(String id) => _nodes[id];

  /// The node at [index] in a pre-order walk over the *visible* rows.
  SpanNode? byIndex(int index) {
    final List<SpanNode> rows = visibleRows;
    return index < 0 || index >= rows.length ? null : rows[index];
  }

  /// The rows a tree view shows: children of a collapsed node stay hidden.
  List<SpanNode> get visibleRows {
    final List<SpanNode> rows = <SpanNode>[];
    void walk(SpanNode node) {
      rows.add(node);
      if (node.isCollapsed) return;
      for (final SpanNode child in node.children) {
        walk(child);
      }
    }

    for (final SpanNode root in roots) {
      walk(root);
    }
    return rows;
  }

  bool isCollapsed(String id) => _collapsed.contains(id);

  void toggleCollapse(String id) {
    if (!_nodes.containsKey(id)) return;
    if (!_collapsed.remove(id)) _collapsed.add(id);
    _rebuildNodes();
    notifyListeners();
  }

  /// Adds or replaces spans, keeping the collapse state.
  void merge(List<SpanData> spans) {
    final List<SpanData> all = <SpanData>[
      for (final SpanNode node in _nodes.values) node.data,
      ...spans,
    ];
    _build(all);
    notifyListeners();
  }

  void _build(List<SpanData> spans) {
    _nodes.clear();
    _roots.clear();

    final Map<String, SpanData> byId = <String, SpanData>{};
    for (final SpanData span in spans) {
      byId[span.id] = span;
    }

    // A parent that is not in the set (or a cycle) reads as a root.
    final Map<String, String?> parents = <String, String?>{};
    for (final SpanData span in byId.values) {
      final String? parent = span.parentSpanId;
      parents[span.id] =
          parent != null && parent != span.id && byId.containsKey(parent)
              ? parent
              : null;
    }
    for (final String id in byId.keys) {
      if (_isCyclic(id, parents, byId)) parents[id] = null;
    }

    final Map<String, int> depths = <String, int>{};
    int depthOf(String id) {
      final int? cached = depths[id];
      if (cached != null) return cached;
      final List<String> path = <String>[];
      String? current = id;
      int depth = -1;
      while (current != null && depths[current] == null) {
        path.add(current);
        current = parents[current];
      }
      if (current != null) depth = depths[current]!;
      for (final String entry in path.reversed) {
        depth += 1;
        depths[entry] = depth;
      }
      return depths[id]!;
    }

    final Map<String, List<String>> childrenOf = <String, List<String>>{};
    for (final SpanData span in byId.values) {
      final String? parent = parents[span.id];
      if (parent == null) {
        _roots.add(span.id);
      } else {
        childrenOf.putIfAbsent(parent, () => <String>[]).add(span.id);
      }
    }

    int compare(String a, String b) {
      final DateTime? left = byId[a]!.startedAt;
      final DateTime? right = byId[b]!.startedAt;
      if (left == null || right == null) return a.compareTo(b);
      final int order = left.compareTo(right);
      return order != 0 ? order : a.compareTo(b);
    }

    SpanNode buildNode(String id) {
      final List<String> children =
          List<String>.of(childrenOf[id] ?? const <String>[])..sort(compare);
      return SpanNode(
        data: byId[id]!,
        depth: depthOf(id),
        isCollapsed: _collapsed.contains(id),
        children: <SpanNode>[
          for (final String child in children) buildNode(child),
        ],
      );
    }

    _roots.sort(compare);
    for (final String id in _roots) {
      _nodes[id] = buildNode(id);
    }
    // Re-point every child at the node instance the walk produced.
    void index(SpanNode node) {
      for (final SpanNode child in node.children) {
        _nodes[child.id] = child;
        index(child);
      }
    }

    for (final String id in _roots) {
      index(_nodes[id]!);
    }

    _range = _computeRange(byId.values);
  }

  void _rebuildNodes() {
    final List<SpanData> spans = <SpanData>[
      for (final SpanNode node in _nodes.values) node.data,
    ];
    _build(spans);
  }

  bool _isCyclic(
    String id,
    Map<String, String?> parents,
    Map<String, SpanData> byId,
  ) {
    final Set<String> seen = <String>{id};
    String? current = parents[id];
    while (current != null) {
      if (!seen.add(current)) return true;
      if (!byId.containsKey(current)) return false;
      current = parents[current];
    }
    return false;
  }

  SpanTimeRange _computeRange(Iterable<SpanData> spans) {
    DateTime? min;
    int max = 0;
    DateTime? base;
    for (final SpanData span in spans) {
      final DateTime? start = span.startedAt;
      if (start == null) continue;
      base ??= start;
      if (start.isBefore(base)) base = start;
      if (min == null || start.isBefore(min)) min = start;
      final int end = start.difference(base).inMilliseconds +
          (span.derivedLatencyMs ?? 0);
      if (end > max) max = end;
    }
    if (base == null) return const SpanTimeRange(min: 0, max: 1, unit: null);
    return SpanTimeRange(
      min: min!.difference(base).inMilliseconds,
      max: max,
      unit: base,
    );
  }
}

DateTime? _time(Object? raw) {
  if (raw is String) return DateTime.tryParse(raw);
  if (raw is int) {
    return DateTime.fromMillisecondsSinceEpoch(
      raw > 10000000000 ? raw : raw * 1000,
      isUtc: true,
    );
  }
  return null;
}
