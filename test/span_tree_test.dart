import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _t(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);

List<SpanData> _sample() => <SpanData>[
  SpanData(
    id: 'root',
    name: 'run',
    type: 'chain',
    status: OpenSpanStatus.completed,
    startedAt: _t(0),
    latencyMs: 100,
  ),
  SpanData(
    id: 'llm',
    name: 'gpt-5.6-luna',
    parentSpanId: 'root',
    type: 'llm',
    status: OpenSpanStatus.completed,
    startedAt: _t(10),
    latencyMs: 60,
  ),
  SpanData(
    id: 'tool',
    name: 'get_weather',
    parentSpanId: 'root',
    type: 'tool',
    status: OpenSpanStatus.failed,
    startedAt: _t(50),
    latencyMs: 40,
  ),
  SpanData(
    id: 'sub',
    name: 'summarize',
    parentSpanId: 'tool',
    type: 'llm',
    status: OpenSpanStatus.running,
    startedAt: _t(60),
    latencyMs: 10,
  ),
];

void main() {
  group('tree', () {
    test('resolves parents, depth and children', () {
      final SpanTree tree = SpanTree(_sample());
      expect(tree.length, 4);
      expect(tree.roots.single.id, 'root');
      final SpanNode root = tree.roots.single;
      expect(root.children.map((SpanNode n) => n.id), <String>['llm', 'tool']);
      expect(tree.byId('sub')!.depth, 2);
      expect(tree.byId('tool')!.hasChildren, isTrue);
      expect(tree.byId('llm')!.hasChildren, isFalse);
    });

    test('a missing parent or a cycle reads as a root', () {
      final SpanTree tree = SpanTree(<SpanData>[
        SpanData(id: 'a', name: 'a', parentSpanId: 'nope'),
        SpanData(id: 'b', name: 'b', parentSpanId: 'c'),
        SpanData(id: 'c', name: 'c', parentSpanId: 'b'),
      ]);
      expect(tree.roots.map((SpanNode n) => n.id), containsAll(<String>['a']));
      expect(tree.length, 3);
      // The cycle is broken rather than recursed forever.
      expect(tree.byId('b')!.depth, 0);
      expect(tree.byId('c')!.depth, 1);
    });

    test('collapsing hides the subtree from the visible rows', () {
      final SpanTree tree = SpanTree(_sample());
      expect(tree.visibleRows.map((SpanNode n) => n.id),
          <String>['root', 'llm', 'tool', 'sub']);

      tree.toggleCollapse('root');
      expect(tree.visibleRows.single.id, 'root');

      tree.toggleCollapse('root');
      tree.toggleCollapse('tool');
      expect(tree.visibleRows.map((SpanNode n) => n.id),
          <String>['root', 'llm', 'tool']);

      // byIndex walks the visible rows, not the raw set.
      expect(tree.byIndex(2)!.id, 'tool');
      expect(tree.byIndex(3), isNull);
    });

    test('the time range covers the earliest start to the latest end', () {
      final SpanTree tree = SpanTree(_sample());
      final SpanTimeRange range = tree.timeRange;
      expect(range.unit, _t(0));
      expect(range.min, 0);
      expect(range.max, 100);

      final ({double start, double width}) llm = range.placement(tree.byId('llm')!);
      expect(llm.start, closeTo(0.1, 0.001));
      expect(llm.width, closeTo(0.6, 0.001));
      final ({double start, double width}) tool = range.placement(tree.byId('tool')!);
      expect(tool.start, closeTo(0.5, 0.001));
    });

    test('latency comes from the timestamps when the exporter omits it', () {
      final SpanData span = SpanData(
        id: 'x',
        name: 'x',
        startedAt: _t(1000),
        endedAt: _t(1250),
      );
      expect(span.derivedLatencyMs, 250);
      expect(SpanData(id: 'y', name: 'y').derivedLatencyMs, isNull);
    });

    test('merge keeps the collapse state and adds new spans', () {
      final SpanTree tree = SpanTree(_sample());
      tree.toggleCollapse('tool');
      tree.merge(<SpanData>[
        SpanData(id: 'extra', name: 'extra', parentSpanId: 'root', startedAt: _t(80)),
      ]);
      expect(tree.length, 5);
      expect(tree.isCollapsed('tool'), isTrue);
      expect(tree.byId('extra')!.depth, 1);
    });

    test('spans read from wire JSON, snake_case included', () {
      final SpanData? span = SpanData.fromJson(<String, Object?>{
        'span_id': 's1',
        'parent_span_id': 's0',
        'name': 'retrieve',
        'type': 'retrieval',
        'status': 'ok',
        'start_time': '2026-09-17T10:00:00Z',
        'end_time': '2026-09-17T10:00:01Z',
      });
      expect(span!.id, 's1');
      expect(span.parentSpanId, 's0');
      expect(span.type, 'retrieval');
      expect(span.status, OpenSpanStatus.completed);
      expect(span.derivedLatencyMs, 1000);
      expect(SpanData.fromJson(<String, Object?>{}), isNull);
    });

    test('a flattened row list rebuilds the parent chain', () {
      final SpanTree tree = SpanTree.fromRows(<({String id, String name, int depth, int startMs, int durationMs})>[
        (id: 'a', name: 'a', depth: 0, startMs: 0, durationMs: 10),
        (id: 'b', name: 'b', depth: 1, startMs: 1, durationMs: 5),
        (id: 'c', name: 'c', depth: 2, startMs: 2, durationMs: 2),
        (id: 'd', name: 'd', depth: 1, startMs: 6, durationMs: 4),
      ]);
      expect(tree.byId('b')!.data.parentSpanId, 'a');
      expect(tree.byId('c')!.data.parentSpanId, 'b');
      expect(tree.byId('d')!.data.parentSpanId, 'a');
      expect(tree.byId('c')!.depth, 2);
    });
  });

  group('primitives', () {
    testWidgets('the timeline renders rows with badges and statuses', (
      WidgetTester tester,
    ) async {
      final SpanTree tree = SpanTree(_sample());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: AuiSpanTimeline(tree: tree))),
      ));
      await tester.pump();

      expect(find.text('run'), findsOneWidget);
      expect(find.text('gpt-5.6-luna'), findsOneWidget);
      expect(find.text('get_weather'), findsOneWidget);
      expect(find.text('summarize'), findsOneWidget);
      expect(find.text('chain'), findsOneWidget);
      expect(find.text('100ms'), findsOneWidget);
      // A running span shows the spinner instead of a check.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Failing span paints its bar with the destructive colour.
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNWidgets(2));
    });

    testWidgets('the collapse toggle hides and shows the subtree', (
      WidgetTester tester,
    ) async {
      final SpanTree tree = SpanTree(_sample());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: AuiSpanTimeline(tree: tree))),
      ));
      await tester.pump();
      expect(find.text('gpt-5.6-luna'), findsOneWidget);

      // The root's toggle is the first arrow in the tree.
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('gpt-5.6-luna'), findsNothing);
      expect(find.text('run'), findsOneWidget);
    });

    testWidgets('the bar sits where the span sits in the window', (
      WidgetTester tester,
    ) async {
      final SpanTree tree = SpanTree(_sample());
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: AuiSpanScope(
              tree: tree,
              node: tree.byId('llm')!,
              child: const AuiSpanTimelineBar(height: 8),
            ),
          ),
        ),
      ));
      await tester.pump();

      final Rect bar = tester.getRect(find.byType(Container).last);
      // The llm span starts at 10% of a 100ms window and lasts 60%.
      expect(bar.left, closeTo(400 * 0.1, 1));
      expect(bar.width, closeTo(400 * 0.6, 1));
    });

    testWidgets('a zero-length span still shows a sliver', (
      WidgetTester tester,
    ) async {
      final SpanTree tree = SpanTree(<SpanData>[
        SpanData(
          id: 'root',
          name: 'root',
          startedAt: _t(0),
          latencyMs: 100,
        ),
        SpanData(
          id: 'instant',
          name: 'instant',
          parentSpanId: 'root',
          startedAt: _t(50),
          latencyMs: 0,
        ),
      ]);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            child: AuiSpanScope(
              tree: tree,
              node: tree.byId('instant')!,
              child: const AuiSpanTimelineBar(),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.getRect(find.byType(Container).last).width, greaterThanOrEqualTo(2));
    });
  });
}
