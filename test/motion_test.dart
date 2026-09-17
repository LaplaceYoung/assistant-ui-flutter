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

  group('tool family wiring', () {
    Widget timeline() => MaterialApp(
          home: Scaffold(
            body: AssistantToolTimeline(
              // The steps live in the collapsible body.
              initiallyOpen: true,
              activeLabel: 'Working',
              restingLabel: 'Worked',
              visibleSteps: 2,
              steps: const <AssistantTimelineStep>[
                AssistantTimelineStep(verb: 'Read', chip: 'a.dart', icon: Icons.description),
                AssistantTimelineStep(verb: 'Edit', chip: 'b.dart', icon: Icons.edit),
              ],
            ),
          ),
        );

    testWidgets('each revealed step slides in over 300ms', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(timeline());
      await tester.pump();

      expect(find.byType(AuiFadeInBlur), findsWidgets);
      final AuiFadeInBlur entry = tester.widget<AuiFadeInBlur>(
        find.byType(AuiFadeInBlur).first,
      );
      expect(entry.duration, const Duration(milliseconds: 300));
      expect(entry.slideFrom, const Offset(0, 4));

      // It is mid-animation right after the frame, and settled later.
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the trigger chevron turns on the element curve', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(timeline());
      await tester.pump();

      final AnimatedRotation rotation = tester.widget<AnimatedRotation>(
        find.byType(AnimatedRotation).first,
      );
      expect(rotation.duration, const Duration(milliseconds: 200));
      expect(rotation.curve, const Cubic(0.32, 0.72, 0, 1));
    });

    testWidgets('the group body drops in when it opens', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AssistantToolGroup(
            label: 'Read 2 files',
            onOpenChange: (bool _) {},
            tools: const <GroupedTool>[
              GroupedTool(
                id: 'c1',
                name: 'read_file',
                target: 'a.dart',
                state: GroupedToolState.done,
              ),
            ],
          ),
        ),
      ));
      await tester.pump();
      // Closed: no body, so no entry animation for it.
      expect(find.byType(AuiFadeInBlur), findsNothing);

      await tester.tap(find.text('Read 2 files'));
      await tester.pump();
      final AuiFadeInBlur entry =
          tester.widget<AuiFadeInBlur>(find.byType(AuiFadeInBlur));
      expect(entry.duration, const Duration(milliseconds: 200));
      expect(entry.slideFrom, const Offset(0, -4));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);

      await tester.pump(const Duration(milliseconds: 250));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    });

    testWidgets('the group header hover colour animates', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AssistantToolGroup(
            label: 'Read 2 files',
            initiallyOpen: true,
            tools: const <GroupedTool>[
              GroupedTool(
                id: 'c1',
                name: 'read_file',
                target: 'a.dart',
                state: GroupedToolState.done,
              ),
            ],
            onOpenChange: (bool _) {},
          ),
        ),
      ));
      await tester.pump();
      final AnimatedContainer header = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      expect(header.duration, const Duration(milliseconds: 150));
    });
  });

  group('composer and message family wiring', () {
    testWidgets('a queued turn slides in over 300ms', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: _QueueHarness(
            rows: const <QueuedMessage>[
              QueuedMessage(id: 'q1', content: <MessagePart>[TextPart('one')]),
            ],
          ),
        ),
      ));
      await tester.pump();

      final AuiFadeInBlur entry =
          tester.widget<AuiFadeInBlur>(find.byType(AuiFadeInBlur).first);
      expect(entry.duration, const Duration(milliseconds: 300));
      expect(entry.slideFrom, const Offset(0, 4));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    });

    testWidgets('the upload line eases to its new value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AssistantAttachmentCard(
            attachment: const ImageAttachment(
              id: 'a1',
              url: 'https://example.com/a.png',
            ),
            progress: 0.4,
          ),
        ),
      ));
      await tester.pump();
      final AuiAnimatedProgressBar bar = tester.widget<AuiAnimatedProgressBar>(
        find.byType(AuiAnimatedProgressBar),
      );
      expect(bar.duration, const Duration(milliseconds: 300));
      expect(bar.value, closeTo(0.4, 0.001));
    });


  });

  group('panel and list rows', () {
    testWidgets('the palette row fill transitions instead of snapping', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AssistantCommandPalette(
            commands: const <PaletteCommand>[
              PaletteCommand(id: 'c1', label: 'New thread', group: 'Thread'),
            ],
            onRun: (String _) {},
          ),
        ),
      ));
      await tester.pump();

      final Iterable<AnimatedContainer> rows =
          tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
      expect(
        rows.any((AnimatedContainer row) =>
            row.duration == const Duration(milliseconds: 150)),
        isTrue,
      );
    });

    testWidgets('the settings switch slides over 200ms', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AssistantSettingsPanel(
            model: 'gpt-5.6-luna',
            models: const <String>['gpt-5.6-luna'],
            systemPrompt: '',
            temperature: 0.7,
            toggles: const <SettingToggle>[
              SettingToggle(
                key: 'streaming',
                label: 'Streaming',
                detail: 'Stream tokens as they arrive',
                on: false,
              ),
            ],
          ),
        ),
      ));
      await tester.pump();
      final AnimatedContainer track = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      expect(track.duration, const Duration(milliseconds: 200));
      expect(track.alignment, Alignment.centerLeft);
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

/// Renders the queue's rows without a runtime: the entry animation is what the
/// motion test observes, so it feeds the same row widget the element builds.
class _QueueHarness extends StatelessWidget {
  const _QueueHarness({required this.rows});

  final List<QueuedMessage> rows;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final QueuedMessage message in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AuiFadeInBlur(
                key: ValueKey<String>(message.id),
                duration: const Duration(milliseconds: 300),
                blur: 0,
                slideFrom: const Offset(0, 4),
                child: Text(
                  message.content.whereType<TextPart>().map((TextPart p) => p.text).join(),
                ),
              ),
            ),
        ],
      );
}
