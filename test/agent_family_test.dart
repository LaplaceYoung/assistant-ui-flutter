import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('agent plan', () {
    testWidgets('marks past, current and future steps', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantAgentPlan(
          steps: <String>['Read the issue', 'Patch the parser', 'Run tests'],
          activeIndex: 1,
        ),
      ));
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('1 of 3'), findsOneWidget);
      expect(find.text('Read the issue'), findsOneWidget);
      expect(find.text('Run tests'), findsOneWidget);
      // One check for the finished step, one spinner for the active one.
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byType(AuiSpinner), findsOneWidget);
    });

    testWidgets('an index past the end reads as fully done', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantAgentPlan(
          steps: <String>['Read the issue', 'Patch the parser'],
          activeIndex: 9,
        ),
      ));
      expect(find.text('2 of 2'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNWidgets(2));
      expect(find.byType(AuiSpinner), findsNothing);
    });
  });

  group('agent status', () {
    testWidgets('names the state and keeps the elapsed while live', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        const AssistantAgentStatus(
          state: AgentState.working,
          label: 'Searching the repo',
          elapsed: '4s',
        ),
      ));
      expect(find.text('Searching the repo'), findsOneWidget);
      expect(find.text('4s'), findsOneWidget);
      // One node announces the whole chip.
      expect(
        find.bySemanticsLabel(RegExp('^working, Searching the repo, 4s')),
        findsOneWidget,
      );
      // Live states offer pause.
      expect(find.byIcon(Icons.pause), findsOneWidget);
      handle.dispose();
    });

    testWidgets('settled states drop the clock and offer a retry', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantAgentStatus(
          state: AgentState.done,
          label: 'Patched the parser',
          elapsed: '12s',
        ),
      ));
      expect(find.text('12s'), findsNothing);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await tester.pumpWidget(_wrap(
        const AssistantAgentStatus(state: AgentState.failed, label: 'Crashed'),
      ));
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('a trailing widget replaces the default control', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantAgentStatus(
          state: AgentState.waiting,
          label: 'Waiting on approval',
          trailing: Icon(Icons.more_horiz),
        ),
      ));
      expect(find.byIcon(Icons.more_horiz), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
    });
  });

  group('agent handoff', () {
    testWidgets('shows the two agents, the reason and what carried over', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantAgentHandoff(
          from: 'planner',
          to: 'patcher',
          reason: 'The plan needs code changes in three files.',
          carried: <String>['the failing test name', 'the file list'],
        ),
      ));
      expect(find.text('planner'), findsOneWidget);
      expect(find.text('patcher'), findsOneWidget);
      expect(find.text('The plan needs code changes in three files.'),
          findsOneWidget);
      expect(find.text('carried over'), findsOneWidget);
      expect(find.text('the failing test name'), findsOneWidget);
    });

    testWidgets('a settled handoff hides the carried block when empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantAgentHandoff(
          from: 'patcher',
          to: 'runner',
          reason: 'Done here.',
          settled: true,
        ),
      ));
      expect(find.text('carried over'), findsNothing);
      expect(find.text('Done here.'), findsOneWidget);
    });
  });

  group('agent card', () {
    const AssistantAgentCard card = AssistantAgentCard(
      name: 'searcher',
      description: 'Searches the repo for symbols.',
      provider: 'local',
      version: '1.4',
      model: 'luna',
      endpoint: 'http://127.0.0.1:7331/mcp',
      skills: <AgentSkill>[
        AgentSkill(name: 'grep', description: 'search file contents'),
      ],
    );

    testWidgets('lists the skills and connects on demand', (
      WidgetTester tester,
    ) async {
      int connects = 0;
      await tester.pumpWidget(_wrap(
        AssistantAgentCard(
          name: card.name,
          description: card.description,
          provider: card.provider,
          version: card.version,
          model: card.model,
          endpoint: card.endpoint,
          skills: card.skills,
          onConnect: () => connects++,
        ),
      ));
      expect(find.text('searcher'), findsOneWidget);
      expect(find.text('v1.4'), findsOneWidget);
      expect(find.text('grep'), findsOneWidget);
      expect(find.text('http://127.0.0.1:7331/mcp'), findsOneWidget);
      expect(find.text('luna'), findsOneWidget);

      await tester.tap(find.text('Connect'));
      await tester.pump();
      expect(connects, 1);
    });

    testWidgets('a connected card shows the check instead of the button', (
      WidgetTester tester,
    ) async {
      int connects = 0;
      await tester.pumpWidget(_wrap(
        AssistantAgentCard(
          name: card.name,
          description: card.description,
          provider: card.provider,
          version: card.version,
          model: card.model,
          endpoint: card.endpoint,
          skills: card.skills,
          connected: true,
          onConnect: () => connects++,
        ),
      ));
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Connect'), findsNothing);
      await tester.tap(find.text('Connected'));
      await tester.pump();
      expect(connects, 0);
    });
  });

  group('subagent list', () {
    testWidgets('per-agent progress follows the counts', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantSubagentList(
          agents: <SubagentItem>[
            SubagentItem(name: 'reader', model: 'luna'),
            SubagentItem(name: 'writer', model: 'opus'),
          ],
          completedCount: 1,
          progress: <double>[100, 40],
        ),
      ));
      expect(find.text('reader'), findsOneWidget);
      expect(find.text('opus'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byType(AuiSpinner), findsOneWidget);
      expect(find.bySemanticsLabel('writer progress'), findsOneWidget);
    });

    testWidgets('the summary row appears only when asked', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantSubagentList(
          agents: <SubagentItem>[
            SubagentItem(name: 'reader', model: 'luna'),
          ],
          completedCount: 1,
          progress: <double>[100],
          showSummary: true,
          summaryAgent: SubagentItem(name: 'summary', model: 'luna-mini'),
        ),
      ));
      expect(find.text('summary'), findsOneWidget);
      expect(find.byType(AuiShimmerBar), findsOneWidget);
    });
  });

  group('canvas split', () {
    testWidgets('renders the thread, the document header and its lines', (
      WidgetTester tester,
    ) async {
      int copies = 0;
      int closes = 0;
      await tester.pumpWidget(_wrap(
        AssistantCanvasSplit(
          title: 'notes.md',
          version: 3,
          saved: true,
          writing: true,
          messages: const <AssistantCanvasMessage>[
            AssistantCanvasMessage(text: 'Draft the notes'),
            AssistantCanvasMessage(
              text: 'On it.',
              speaker: 'assistant',
            ),
          ],
          lines: const <AssistantCanvasLine>[
            AssistantCanvasLine('Release notes', heading: true),
            AssistantCanvasLine('Streaming landed.'),
          ],
          onCopy: () => copies++,
          onClose: () => closes++,
        ),
      ));
      expect(find.text('Draft the notes'), findsOneWidget);
      expect(find.text('On it.'), findsOneWidget);
      expect(find.text('notes.md'), findsOneWidget);
      expect(find.text('v3'), findsOneWidget);
      expect(find.text('saved'), findsOneWidget);
      expect(find.text('Release notes'), findsOneWidget);
      expect(find.text('Streaming landed.'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.copy));
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(copies, 1);
      expect(closes, 1);
    });

    testWidgets('an unsaved document reads as editing', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantCanvasSplit(title: 'notes.md'),
      ));
      expect(find.text('editing'), findsOneWidget);
      expect(find.text('saved'), findsNothing);
    });
  });

  group('flow canvas', () {
    const List<FlowNode> nodes = <FlowNode>[
      FlowNode(id: 'a', title: 'Planner', left: 24, top: 24),
      FlowNode(id: 'b', title: 'Patcher', left: 260, top: 160),
    ];

    testWidgets('paints an edge per connection and the labels', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantFlowCanvas(
          nodes: nodes,
          edges: <FlowEdge>[
            FlowEdge(from: 'a', to: 'b', label: 'handoff'),
            FlowEdge(from: 'b', to: 'a', route: FlowRoute.loopBottom),
          ],
        ),
      ));
      expect(find.text('Planner'), findsOneWidget);
      expect(find.text('Patcher'), findsOneWidget);
      final Finder edgePaint = find.byWidgetPredicate(
        (Widget widget) =>
            widget is CustomPaint && widget.painter is AuiFlowEdgePainter,
      );
      expect(edgePaint, findsOneWidget);
      expect(
        (tester.widget<CustomPaint>(edgePaint).painter! as AuiFlowEdgePainter)
            .edges,
        hasLength(2),
      );
    });

    testWidgets('the painter repaints only when the geometry changes', (
      WidgetTester tester,
    ) async {
      final AuiFlowEdgePainter first = AuiFlowEdgePainter(
        nodes: nodes,
        edges: const <FlowEdge>[FlowEdge(from: 'a', to: 'b')],
        color: const Color(0xFF888888),
        labelColor: const Color(0xFF888888),
        labelBackground: const Color(0xFFFFFFFF),
      );
      final AuiFlowEdgePainter same = AuiFlowEdgePainter(
        nodes: nodes,
        edges: const <FlowEdge>[FlowEdge(from: 'a', to: 'b')],
        color: const Color(0xFF888888),
        labelColor: const Color(0xFF888888),
        labelBackground: const Color(0xFFFFFFFF),
      );
      expect(same.shouldRepaint(first), isFalse);

      final AuiFlowEdgePainter moved = AuiFlowEdgePainter(
        nodes: const <FlowNode>[
          FlowNode(id: 'a', title: 'Planner', left: 24, top: 48),
          FlowNode(id: 'b', title: 'Patcher', left: 260, top: 160),
        ],
        edges: const <FlowEdge>[FlowEdge(from: 'a', to: 'b')],
        color: const Color(0xFF888888),
        labelColor: const Color(0xFF888888),
        labelBackground: const Color(0xFFFFFFFF),
      );
      expect(moved.shouldRepaint(first), isTrue);
    });
  });

  group('computer use', () {
    testWidgets('shows the url, the cursor position and the active step', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantComputerUse(
          url: 'https://example.com',
          activeIndex: 2,
          steps: <ComputerStep>[
            ComputerStep(
              id: 'a',
              action: 'click',
              target: 'Sign in',
              x: 10,
              y: 20,
            ),
            ComputerStep(
              id: 'b',
              action: 'type',
              target: 'email field',
              x: 30,
              y: 40,
            ),
            ComputerStep(
              id: 'c',
              action: 'submit',
              target: 'Continue',
              x: 50,
              y: 60,
            ),
          ],
        ),
      ));
      expect(find.text('https://example.com'), findsOneWidget);
      expect(find.text('submit'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('3/3'), findsOneWidget);
      expect(find.byIcon(Icons.mouse), findsOneWidget);
    });

    testWidgets('no steps means no cursor and no action bar', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantComputerUse(url: 'about:blank', steps: [], activeIndex: 0),
      ));
      expect(find.text('about:blank'), findsOneWidget);
      expect(find.byIcon(Icons.mouse), findsNothing);
    });
  });
}
