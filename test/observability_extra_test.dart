import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('number ticker', () {
    testWidgets('renders the grouped figure and its caption', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        const AssistantNumberTicker(value: 12480, label: 'tokens saved'),
      ));
      expect(find.bySemanticsLabel('12,480'), findsOneWidget);
      expect(find.text('tokens saved'), findsOneWidget);
      // One rolling column per digit, plus the comma.
      expect(find.text('0'), findsNWidgets(5));
      handle.dispose();
    });

    testWidgets('the strip settles on the digit it shows', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantNumberTicker(value: 7, label: 'runs'),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      // Row 7 of the strip sits in the window.
      final double window = tester.getTopLeft(find.byType(ClipRect).first).dy;
      final double seven = tester.getTopLeft(find.text('7')).dy;
      expect(seven, closeTo(window, 1));
    });

    testWidgets('rolls to the new digit when the value changes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantNumberTicker(value: 41, label: 'runs'),
      ));
      await tester.pumpWidget(_wrap(
        const AssistantNumberTicker(value: 97, label: 'runs'),
      ));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('runs'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('todo list', () {
    testWidgets('counts what is done and shows each state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantTodoList(
          revision: 3,
          items: <TodoItem>[
            TodoItem(id: 'a', text: 'Read the issue', status: TodoStatus.done),
            TodoItem(id: 'b', text: 'Patch it', status: TodoStatus.active),
            TodoItem(id: 'c', text: 'Ship it', status: TodoStatus.pending),
            TodoItem(
              id: 'd',
              text: 'Run the suite',
              status: TodoStatus.failed,
              reason: '2 tests failed',
            ),
          ],
        ),
      ));
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('1/4 · rev 3'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byType(AuiSpinner), findsOneWidget);
      expect(find.text('2 tests failed'), findsOneWidget);
    });

    testWidgets('without a revision it shows the plain counter', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantTodoList(
          items: <TodoItem>[
            TodoItem(id: 'a', text: 'One', status: TodoStatus.pending),
          ],
        ),
      ));
      expect(find.text('0/1'), findsOneWidget);
    });
  });

  group('spec sheet', () {
    testWidgets('reveals rows in order and emphasises values', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantSpecSheet(
          title: 'Renderer',
          subtitle: 'flutter 3.47',
          visibleCount: 2,
          rows: <SpecRow>[
            SpecRow(label: 'engine', value: 'impeller'),
            SpecRow(label: 'artifacts', value: 'web', emphasis: true),
            SpecRow(label: 'hidden', value: 'nope'),
          ],
        ),
      ));
      expect(find.text('Renderer'), findsOneWidget);
      expect(find.text('flutter 3.47'), findsOneWidget);
      expect(find.text('impeller'), findsOneWidget);
      expect(find.text('web'), findsOneWidget);
      expect(find.text('hidden'), findsNothing);
    });
  });

  group('connection state', () {
    testWidgets('an online link renders nothing at all', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantConnectionState(phase: ConnectionPhase.online),
      ));
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('dropped offers a reconnect, resumed counts the tokens', (
      WidgetTester tester,
    ) async {
      int retries = 0;
      await tester.pumpWidget(_wrap(
        AssistantConnectionState(
          phase: ConnectionPhase.dropped,
          onRetry: () => retries++,
        ),
      ));
      expect(
        find.text('Connection lost. The run kept going on the server.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Reconnect'));
      await tester.pump();
      expect(retries, 1);

      await tester.pumpWidget(_wrap(
        const AssistantConnectionState(
          phase: ConnectionPhase.resumed,
          resumedTokens: 412,
        ),
      ));
      expect(find.text('Picked the stream back up.'), findsOneWidget);
      expect(find.text('+412 tokens'), findsOneWidget);

      await tester.pumpWidget(_wrap(
        const AssistantConnectionState(
          phase: ConnectionPhase.reconnecting,
          attempt: 3,
        ),
      ));
      expect(find.text('attempt 3'), findsOneWidget);
    });
  });

  group('timeline', () {
    testWidgets('renders one entry per revealed event', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantTimeline(
          visibleCount: 2,
          events: <TimelineEvent>[
            TimelineEvent(
              id: 'e1',
              when: TimelineWhen.past,
              time: '09:12',
              title: 'Read the issue',
            ),
            TimelineEvent(
              id: 'e2',
              when: TimelineWhen.now,
              time: '09:18',
              title: 'Patch the parser',
              detail: '3 files',
            ),
            TimelineEvent(
              id: 'e3',
              when: TimelineWhen.future,
              time: '09:30',
              title: 'Run the suite',
            ),
          ],
        ),
      ));
      expect(find.text('09:12'), findsOneWidget);
      expect(find.text('Patch the parser'), findsOneWidget);
      expect(find.text('3 files'), findsOneWidget);
      expect(find.text('Run the suite'), findsNothing);
    });
  });

  group('comparison card', () {
    testWidgets('marks the pick and greys what an option lacks', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantComparisonCard(
          traitLabels: <String>['streaming', 'tools'],
          recommendedId: 'b',
          reason: 'B streams and keeps tool calls in one message.',
          options: <ComparisonOption>[
            ComparisonOption(
              id: 'a',
              name: 'Plain HTTP',
              headline: 'no streaming',
              traits: <String?>[null, 'tools'],
            ),
            ComparisonOption(
              id: 'b',
              name: 'Data stream',
              headline: 'one message per turn',
              traits: <String?>['streaming', 'tools'],
            ),
          ],
        ),
      ));
      expect(find.text('Plain HTTP'), findsOneWidget);
      expect(find.text('Data stream'), findsOneWidget);
      expect(find.text('pick'), findsOneWidget);
      expect(find.text('B streams and keeps tool calls in one message.'),
          findsOneWidget);
      // One check per present trait, one dash for the missing one.
      expect(find.byIcon(Icons.check), findsNWidgets(3));
      expect(find.byIcon(Icons.remove), findsOneWidget);
    });
  });

  group('recommendation card', () {
    testWidgets('accepts on demand and reports confidence while idle', (
      WidgetTester tester,
    ) async {
      int accepted = 0;
      int alternatives = 0;
      await tester.pumpWidget(_wrap(
        AssistantRecommendationCard(
          state: RecommendationState.idle,
          question: 'Which transport should we use?',
          answer: 'The data stream protocol.',
          confidenceLabel: 'high confidence',
          acceptedLabel: 'Using the data stream protocol',
          onAccept: () => accepted++,
          onAlternatives: () => alternatives++,
        ),
      ));
      expect(find.text('high confidence'), findsOneWidget);
      await tester.tap(find.text('Accept'));
      await tester.tap(find.text('Alternatives'));
      await tester.pump();
      expect(accepted, 1);
      expect(alternatives, 1);

      await tester.pumpWidget(_wrap(
        const AssistantRecommendationCard(
          state: RecommendationState.accepted,
          question: 'Which transport should we use?',
          answer: 'The data stream protocol.',
          confidenceLabel: 'high confidence',
          acceptedLabel: 'Using the data stream protocol',
        ),
      ));
      expect(find.text('Using the data stream protocol'), findsOneWidget);
      expect(find.text('Accept'), findsNothing);
    });
  });

  group('data table', () {
    testWidgets('renders the header, the glyph and the numbers', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantDataTable(
          rows: <ModelUsage>[
            ModelUsage(
              name: 'luna',
              context: '128k',
              cost: r'$0.31',
            ),
            ModelUsage(name: 'opus', context: '200k', cost: r'$0.90'),
          ],
        ),
      ));
      expect(find.text('Model'), findsOneWidget);
      expect(find.text('Context'), findsOneWidget);
      expect(find.text('Cost'), findsOneWidget);
      expect(find.text('luna'), findsOneWidget);
      // The glyph is the first character of the model name, as upstream has it.
      expect(find.text('l'), findsOneWidget);
      expect(find.text('o'), findsOneWidget);
      expect(find.text('128k'), findsOneWidget);
      expect(find.text(r'$0.90'), findsOneWidget);
    });
  });

  group('chart', () {
    testWidgets('draws each variant and reports the headline', (
      WidgetTester tester,
    ) async {
      for (final ChartVariant variant in ChartVariant.values) {
        await tester.pumpWidget(_wrap(
          AssistantChart(
            label: 'Tokens / run',
            value: '1,240',
            delta: '+12%',
            variant: variant,
            visibleCount: 4,
            points: const <double>[2, 8, 5, 12, 9],
          ),
        ));
        expect(find.text('Tokens / run'), findsOneWidget);
        expect(find.text('1,240'), findsOneWidget);
        expect(find.text('+12%'), findsOneWidget);
        expect(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is CustomPaint && widget.painter is AuiChartPainter,
          ),
          findsOneWidget,
          reason: '$variant',
        );
      }
    });

    testWidgets('a falling delta is reported as a drop', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantChart(
          label: 'Cost / run',
          value: r'$0.004',
          delta: '-18%',
          visibleCount: 3,
          points: <double>[9, 7, 4],
        ),
      ));
      expect(find.text('-18%'), findsOneWidget);
    });
  });

  group('flow graph', () {
    const List<FlowGraphNode> nodes = <FlowGraphNode>[
      FlowGraphNode(
        id: 'a',
        label: 'plan',
        column: 0,
        row: 0,
        state: FlowNodeState.done,
      ),
      FlowGraphNode(
        id: 'b',
        label: 'patch',
        column: 1,
        row: 0,
        state: FlowNodeState.active,
      ),
      FlowGraphNode(
        id: 'c',
        label: 'test',
        column: 2,
        row: 1,
        state: FlowNodeState.pending,
      ),
    ];

    testWidgets('reveals nodes in order and paints the edges', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantFlowGraph(
          nodes: nodes,
          edges: <FlowGraphEdge>[
            FlowGraphEdge(from: 'a', to: 'b'),
            FlowGraphEdge(from: 'b', to: 'c'),
          ],
          visibleCount: 2,
        ),
      ));
      expect(find.text('plan'), findsOneWidget);
      expect(find.text('patch'), findsOneWidget);
      expect(find.text('test'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is CustomPaint && widget.painter is AuiFlowGraphPainter,
        ),
        findsOneWidget,
      );
    });
  });
}
