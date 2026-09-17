import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parsing', () {
    test('reads nodes, shapes and chains', () {
      final MermaidFlowchart chart = MermaidFlowchart.parse('''
graph TD
  A[Start] --> B{Ready?}
  B -->|yes| C(Run)
  B -->|no| D([Wait])
''')!;
      expect(chart.direction, MermaidDirection.topDown);
      expect(chart.nodes.map((MermaidNode n) => n.id).toList(),
          containsAll(<String>['A', 'B', 'C', 'D']));
      expect(
        chart.nodes.firstWhere((MermaidNode n) => n.id == 'A').shape,
        MermaidShape.box,
      );
      expect(
        chart.nodes.firstWhere((MermaidNode n) => n.id == 'B').shape,
        MermaidShape.decision,
      );
      expect(
        chart.nodes.firstWhere((MermaidNode n) => n.id == 'C').shape,
        MermaidShape.rounded,
      );
      expect(
        chart.nodes.firstWhere((MermaidNode n) => n.id == 'D').shape,
        MermaidShape.stadium,
      );
      expect(chart.edges.length, 3);
      expect(chart.edges[1].label, 'yes');
      expect(chart.edges[2].label, 'no');
    });

    test('reads the left-to-right direction and multi-hop chains', () {
      final MermaidFlowchart chart =
          MermaidFlowchart.parse('flowchart LR\n  A --> B --> C')!;
      expect(chart.direction, MermaidDirection.leftRight);
      expect(chart.edges.map((MermaidEdge e) => '${e.from}${e.to}').toList(),
          <String>['AB', 'BC']);
    });

    test('lays nodes out by layer', () {
      final MermaidFlowchart chart = MermaidFlowchart.parse('''
graph TD
  A --> B
  B --> C
  A --> C
  D
''')!;
      final Map<String, int> layers = chart.layers();
      expect(layers['A'], 0);
      expect(layers['B'], 1);
      expect(layers['C'], 2);
      // A node with no edges is a root of its own.
      expect(layers['D'], 0);
    });

    test('rejects what the subset does not cover', () {
      expect(MermaidFlowchart.parse('sequenceDiagram\n  A->>B: hi'), isNull);
      expect(MermaidFlowchart.parse(''), isNull);
      expect(MermaidFlowchart.parse('graph TD\n'), isNull);
      expect(MermaidFlowchart.parse('not a diagram'), isNull);
    });

    test('comments and subgraph markers are skipped', () {
      final MermaidFlowchart chart = MermaidFlowchart.parse('''
graph TD
  %% a note
  subgraph one
    A --> B
  end
''')!;
      expect(chart.nodes.length, 2);
      expect(chart.edges.single.to, 'B');
    });
  });

  group('rendering', () {
    testWidgets('a supported fence draws the flow without a host renderer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AssistantMermaidDiagram(
            code: 'graph TD\n  A[Start] --> B[Finish]',
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(AssistantMermaidFlowchart), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      // The source fallback is not shown when the flow renders.
      expect(find.text('diagram could not be rendered'), findsNothing);
    });

    testWidgets('an unsupported diagram falls back to the source', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AssistantMermaidDiagram(code: 'sequenceDiagram\n  A->>B: hi'),
        ),
      ));
      await tester.pump();

      expect(find.byType(AssistantMermaidFlowchart), findsNothing);
      expect(find.text('diagram could not be rendered'), findsOneWidget);
      expect(find.text('sequenceDiagram\n  A->>B: hi'), findsOneWidget);
    });

    testWidgets('a host drawing still wins over the built-in one', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AssistantMermaidDiagram(
            code: 'graph TD\n  A --> B',
            diagram: const Text('HOST DRAWING'),
          ),
        ),
      ));
      await tester.pump();

      expect(find.text('HOST DRAWING'), findsOneWidget);
      expect(find.byType(AssistantMermaidFlowchart), findsNothing);
    });

    testWidgets('the painter lays the layers out in the right direction', (
      WidgetTester tester,
    ) async {
      final MermaidFlowchart topDown =
          MermaidFlowchart.parse('graph TD\n  A --> B')!;
      final MermaidFlowchart leftRight =
          MermaidFlowchart.parse('graph LR\n  A --> B')!;

      Size paintedSize() {
        final CustomPaint paint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(AssistantMermaidFlowchart),
            matching: find.byType(CustomPaint),
          ).first,
        );
        return paint.size;
      }

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: AssistantMermaidFlowchart(chart: topDown)),
      ));
      await tester.pump();
      final Size down = paintedSize();
      // Two layers stack vertically (2×40 + 46) across one 150px node.
      expect(down, const Size(150, 126));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: AssistantMermaidFlowchart(chart: leftRight)),
      ));
      await tester.pump();
      final Size across = paintedSize();
      // The same flow laid out across: 2×150 + 46 wide, 40 tall.
      expect(across, const Size(346, 40));
    });
  });

  group('markdown integration', () {
    testWidgets('a mermaid fence renders through the element', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AssistantMarkdown(
            text: '```mermaid\ngraph TD\n  A[Start] --> B[End]\n```',
          ),
        ),
      ));
      await tester.pump();

      expect(find.byType(AssistantMermaidFlowchart), findsOneWidget);
      expect(find.text('diagram could not be rendered'), findsNothing);
    });
  });
}
