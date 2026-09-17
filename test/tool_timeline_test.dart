import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

const AssistantTimelineStep _readStep = AssistantTimelineStep(
  verb: 'Reading',
  chip: 'lib/main.dart',
  icon: Icons.description_outlined,
);
const AssistantTimelineStep _editStep = AssistantTimelineStep(
  verb: 'Editing',
  chip: 'lib/theme.dart',
  icon: Icons.edit_outlined,
);
const AssistantTimelineStep _testStep = AssistantTimelineStep(
  verb: 'Running',
  chip: 'flutter test',
  icon: Icons.terminal,
);

void main() {
  group('tool timeline', () {
    testWidgets('swaps the active and resting labels with the run', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantToolTimeline(
          steps: <AssistantTimelineStep>[_readStep],
          visibleSteps: 1,
          activeLabel: 'Working…',
          restingLabel: 'Worked for 12s',
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Worked for 12s'), findsOneWidget);
      expect(find.text('Working…'), findsNothing);

      await tester.pumpWidget(_wrap(
        const AssistantToolTimeline(
          steps: <AssistantTimelineStep>[_readStep],
          visibleSteps: 1,
          streaming: true,
          activeLabel: 'Working…',
          restingLabel: 'Worked for 12s',
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Working…'), findsOneWidget);
    });

    testWidgets('starts collapsed and reveals steps on tap', (
      WidgetTester tester,
    ) async {
      final List<bool> reports = <bool>[];
      await tester.pumpWidget(_wrap(
        AssistantToolTimeline(
          steps: const <AssistantTimelineStep>[_readStep, _editStep],
          visibleSteps: 2,
          restingLabel: 'Worked for 12s',
          activeLabel: 'Working…',
          onOpenChange: reports.add,
        ),
      ));
      expect(find.text('Reading'), findsNothing);

      await tester.tap(find.text('Worked for 12s'));
      await tester.pump();
      expect(reports, <bool>[true]);
      expect(find.text('Reading'), findsOneWidget);
      expect(find.text('Editing'), findsOneWidget);
      expect(find.text('lib/main.dart'), findsOneWidget);

      await tester.tap(find.text('Worked for 12s'));
      await tester.pump();
      expect(reports, <bool>[true, false]);
      expect(find.text('Reading'), findsNothing);
    });

    testWidgets('shows only the steps the run has reached', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantToolTimeline(
          steps: <AssistantTimelineStep>[_readStep, _editStep, _testStep],
          visibleSteps: 2,
          initiallyOpen: true,
          restingLabel: 'Worked for 12s',
          activeLabel: 'Working…',
        ),
      ));
      expect(find.text('Reading'), findsOneWidget);
      expect(find.text('Editing'), findsOneWidget);
      expect(find.text('Running'), findsNothing);
    });

    testWidgets('lists changed files with their diff counts', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantToolTimeline(
          steps: <AssistantTimelineStep>[_editStep],
          visibleSteps: 1,
          initiallyOpen: true,
          restingLabel: 'Worked for 12s',
          activeLabel: 'Working…',
          stats: <AssistantTimelineStat>[
            AssistantTimelineStat(file: 'lib/main.dart', added: 12, removed: 3),
            AssistantTimelineStat(file: 'README.md', added: 4),
          ],
        ),
      ));
      expect(find.text('lib/main.dart'), findsOneWidget);
      expect(find.text('+12'), findsOneWidget);
      expect(find.text('−3'), findsOneWidget);
      expect(find.text('README.md'), findsOneWidget);
      expect(find.text('+4'), findsOneWidget);
    });

    testWidgets('a bound open state renders the steps without a tap', (
      WidgetTester tester,
    ) async {
      final List<bool> reports = <bool>[];
      await tester.pumpWidget(_wrap(
        AssistantToolTimeline(
          steps: const <AssistantTimelineStep>[_readStep],
          visibleSteps: 1,
          open: true,
          restingLabel: 'Worked for 12s',
          activeLabel: 'Working…',
          onOpenChange: reports.add,
        ),
      ));
      expect(find.text('Reading'), findsOneWidget);

      await tester.tap(find.text('Worked for 12s'));
      await tester.pump();
      expect(reports, <bool>[false]);
      // The parent owns the state, so the rows stay until it flips `open`.
      expect(find.text('Reading'), findsOneWidget);
    });
  });

  group('grouped parts', () {
    Widget groupedApp(
      LocalRuntime runtime,
      List<List<AuiPartGroupMember>> groups,
    ) {
      return AuiRuntimeProvider(
        runtime: runtime,
        child: MaterialApp(
          home: Scaffold(
            body: AuiThreadLayout(
              viewport: AuiThreadViewport(
                child: AuiThreadMessages(
                  builder: (BuildContext context, ThreadMessage message,
                      bool isLast) {
                    return AuiMessage(
                      child: AuiMessageParts(
                        groupBy: (MessagePart part, int index) =>
                            part is ToolCallPart ? 'tools' : null,
                        partGroupBuilder: (BuildContext context, String group,
                            List<AuiPartGroupMember> members) {
                          groups.add(members);
                          return Text('$group ×${members.length}');
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('folds consecutive tool calls into one group', (
      WidgetTester tester,
    ) async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);
      final List<List<AuiPartGroupMember>> groups =
          <List<AuiPartGroupMember>>[];

      await tester.pumpWidget(groupedApp(runtime, groups));
      await runtime.thread.send(content: <MessagePart>[const TextPart('go')]);
      await tester.pump();

      adapter.emit(<MessagePart>[
        const ToolCallPart(toolCallId: 'a', toolName: 'read_file'),
        const ToolCallPart(toolCallId: 'b', toolName: 'write_file'),
      ]);
      await tester.pump();
      await tester.pump();

      expect(groups, hasLength(1));
      expect(find.text('tools ×2'), findsOneWidget);

      groups.clear();
      adapter.emit(<MessagePart>[
        const ToolCallPart(toolCallId: 'a', toolName: 'read_file'),
        const ToolCallPart(toolCallId: 'b', toolName: 'write_file'),
        const TextPart('done'),
      ]);
      await tester.pump();
      await tester.pump();

      expect(groups, hasLength(1));
      expect(groups.single, hasLength(2));
      expect(find.text('tools ×2'), findsOneWidget);
    });

    testWidgets('a part between tool calls splits the group', (
      WidgetTester tester,
    ) async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);
      final List<List<AuiPartGroupMember>> groups =
          <List<AuiPartGroupMember>>[];

      await tester.pumpWidget(groupedApp(runtime, groups));
      await runtime.thread.send(content: <MessagePart>[const TextPart('go')]);
      await tester.pump();

      adapter.emit(<MessagePart>[
        const ToolCallPart(toolCallId: 'a', toolName: 'read_file'),
        const TextPart('thinking'),
        const ToolCallPart(toolCallId: 'b', toolName: 'write_file'),
      ]);
      await tester.pump();
      await tester.pump();

      expect(groups, hasLength(2));
      expect(groups.every((List<AuiPartGroupMember> g) => g.length == 1), isTrue);
      expect(find.text('tools ×1'), findsNWidgets(2));
      expect(find.text('thinking'), findsOneWidget);
    });
  });
}
