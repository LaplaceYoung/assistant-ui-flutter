import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('flow', () {
    testWidgets('renders nodes, tones and the arrow labels', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        const Material(
          color: Colors.transparent,
          child: AssistantFlow(
            child: AssistantFlowRow(
              children: <Widget>[
                AssistantFlowNode(label: 'Prompt'),
                AssistantFlowArrow(label: 'ask', reverseLabel: 'answer'),
                AssistantFlowNode(
                  label: 'Route?',
                  variant: FlowNodeVariant.decision,
                  tone: FlowTone.blue,
                ),
              ],
            ),
          ),
        ),
      ));
      expect(find.text('Prompt'), findsOneWidget);
      expect(find.text('Route?'), findsOneWidget);
      expect(find.text('ask'), findsOneWidget);
      expect(find.text('answer'), findsOneWidget);
      // The expand control appears once the frame is pointed at.
      final TestGesture mouse =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Prompt')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byIcon(Icons.fullscreen), findsOneWidget);
      await mouse.removePointer();
      handle.dispose();
    });

    testWidgets('groups carry their label', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const Material(
          color: Colors.transparent,
          child: AssistantFlowGroup(
            label: 'prepare',
            child: AssistantFlowNode(label: 'Fetch'),
          ),
        ),
      ));
      expect(find.text('PREPARE'), findsOneWidget);
      expect(find.text('Fetch'), findsOneWidget);
    });

    testWidgets('the mermaid source is shown when the host has one', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const Material(
          color: Colors.transparent,
          child: AssistantFlow(
            llmCode: 'graph TD; A-->B',
            child: AssistantFlowNode(label: 'A'),
          ),
        ),
      ));
      expect(find.text('graph TD; A-->B'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });
  });

  group('flow expand', () {
    testWidgets('opens a full-screen viewer with the zoom controls', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        const AssistantFlowExpand(
          alwaysShowTrigger: true,
          child: Text('diagram body'),
        ),
      ));
      expect(find.text('diagram body'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsNothing);

      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pump();
      // The viewer overlays the app with its toolbar.
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      final InteractiveViewer viewer =
          tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(),
          closeTo(1.25, 0.001));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.byType(InteractiveViewer), findsNothing);
      handle.dispose();
    });

    testWidgets('reset returns the transform to identity', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        const AssistantFlowExpand(
          alwaysShowTrigger: true,
          child: Text('body'),
        ),
      ));
      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      final InteractiveViewer viewer =
          tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
      expect(viewer.transformationController!.value.getMaxScaleOnAxis(),
          closeTo(1, 0.001));
      handle.dispose();
    });
  });
}
