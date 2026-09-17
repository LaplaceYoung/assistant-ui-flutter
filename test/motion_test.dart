import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('entry animation', () {
    testWidgets('fades in from a blur over 300ms', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AuiFadeInBlur(child: Text('label'))),
      ));
      await tester.pump();

      // Starts transparent with the blur applied.
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
      expect(tester.widget<ImageFiltered>(find.byType(ImageFiltered)), isNotNull);

      await tester.pump(const Duration(milliseconds: 150));
      final double mid = tester.widget<Opacity>(find.byType(Opacity)).opacity;
      expect(mid, greaterThan(0));
      expect(mid, lessThan(1));

      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
      expect(find.text('label'), findsOneWidget);
    });

    testWidgets('replays when its trigger changes', (WidgetTester tester) async {
      Widget build(String state) => MaterialApp(
            home: Scaffold(
              body: AuiFadeInBlur(trigger: state, child: Text(state)),
            ),
          );
      await tester.pumpWidget(build('first'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);

      await tester.pumpWidget(build('second'));
      await tester.pump();
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
    });

    testWidgets('a slide offset starts displaced', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AuiFadeInBlur(
            slideFrom: Offset(0, 8),
            child: Text('sliding'),
          ),
        ),
      ));
      await tester.pump();
      final Offset start = tester.getTopLeft(find.text('sliding'));
      await tester.pump(const Duration(milliseconds: 400));
      final Offset end = tester.getTopLeft(find.text('sliding'));
      expect(end.dy, lessThan(start.dy));
    });
  });

  group('press feedback', () {
    testWidgets('the pill scales to 0.96 while pressed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(child: AuiPillButton(label: 'Allow once', onPressed: () {})),
        ),
      ));
      await tester.pump();

      double scale() =>
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
      expect(scale(), 1);

      final TestGesture gesture =
          await tester.startGesture(tester.getCenter(find.text('Allow once')));
      await tester.pump();
      expect(scale(), 0.96);

      await gesture.up();
      await tester.pump();
      expect(scale(), 1);
    });

    testWidgets('an artifact card lifts on hover and scales on press', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: AssistantArtifactCard(
              title: 'Plan',
              meta: '2 pages',
              onTap: () {},
            ),
          ),
        ),
      ));
      await tester.pump();

      final Finder card = find.byType(AssistantArtifactCard);
      // The lift is a paint transform, so it is read off the widget.
      double lift() => tester
          .widget<AnimatedContainer>(
            find
                .descendant(of: card, matching: find.byType(AnimatedContainer))
                .first,
          )
          .transform!
          .getTranslation()
          .y;

      double scale() => tester
          .widget<AnimatedScale>(
            find.descendant(of: card, matching: find.byType(AnimatedScale)).first,
          )
          .scale;

      expect(lift(), 0);
      expect(scale(), 1);

      final TestGesture mouse =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(card));
      await tester.pump(const Duration(milliseconds: 200));
      expect(lift(), lessThan(0));

      final TestGesture press =
          await tester.startGesture(tester.getCenter(card));
      await tester.pump();
      expect(scale(), 0.98);
      await press.up();
      await tester.pump();
      expect(scale(), 1);
    });
  });

  group('progress and colour transitions', () {
    testWidgets('the plan bar eases to its new width', (
      WidgetTester tester,
    ) async {
      Widget build(int active) => MaterialApp(
            home: Scaffold(
              body: AssistantAgentPlan(
                steps: const <String>['plan', 'build', 'ship', 'done'],
                activeIndex: active,
              ),
            ),
          );

      double fill(WidgetTester tester) => tester
          .widget<Container>(
            find
                .descendant(
                  of: find.byType(AuiAnimatedProgressBar),
                  matching: find.byType(Container),
                )
                .last,
          )
          .constraints!
          .maxWidth;

      await tester.pumpWidget(build(1));
      await tester.pump(const Duration(milliseconds: 600));
      final double quarter = fill(tester);

      await tester.pumpWidget(build(3));
      await tester.pump(const Duration(milliseconds: 100));
      final double mid = fill(tester);
      await tester.pump(const Duration(milliseconds: 500));
      final double settled = fill(tester);

      // The fill moves over time rather than jumping to the new fraction.
      expect(mid, greaterThan(quarter));
      expect(mid, lessThan(settled));
      expect(find.byType(AuiAnimatedProgressBar), findsOneWidget);
    });

    testWidgets('a hover colour animates over its duration', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: AuiHoverColor(
              onTap: () {},
              builder: (BuildContext context, bool hovered) => ColoredBox(
                color: hovered ? Colors.red : Colors.blue,
                child: const SizedBox(width: 40, height: 20),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.widget<AnimatedContainer>(find.byType(AnimatedContainer))
          .duration, const Duration(milliseconds: 150));
    });
  });

  group('agent family wiring', () {
    testWidgets('the status label replays its entry per state', (
      WidgetTester tester,
    ) async {
      Widget build(AgentState state) => MaterialApp(
            home: Scaffold(
              body: AssistantAgentStatus(state: state, label: 'Working'),
            ),
          );
      await tester.pumpWidget(build(AgentState.working));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpWidget(build(AgentState.done));
      await tester.pump();
      expect(find.byType(AuiFadeInBlur), findsOneWidget);
      // Replayed: transparent again on the new state.
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 0);
    });

    testWidgets('the approval status line enters as the state settles', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AssistantApprovalCard(
            state: ApprovalState.done,
            command: 'rm -rf build/',
            title: 'Clean',
            subtitle: 'Removes output',
          ),
        ),
      ));
      await tester.pump();
      expect(find.byType(AuiFadeInBlur), findsOneWidget);
      expect(find.text('Finished with exit 0'), findsOneWidget);
    });
  });
}
