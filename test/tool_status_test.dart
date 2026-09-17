import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

List<GroupedTool> _tools(GroupedToolState last) => <GroupedTool>[
      const GroupedTool(
        id: 'a',
        name: 'read_file',
        target: 'lib/main.dart',
        state: GroupedToolState.done,
        durationMs: 118,
      ),
      const GroupedTool(
        id: 'b',
        name: 'grep',
        target: 'runtime',
        state: GroupedToolState.done,
      ),
      GroupedTool(
        id: 'c',
        name: 'write_file',
        target: 'lib/theme.dart',
        state: last,
        durationMs: last == GroupedToolState.running ? null : 250,
      ),
    ];

void main() {
  group('tool group', () {
    testWidgets('counts what is running, done and failed', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        AssistantToolGroup(
          label: '3 tool calls',
          tools: _tools(GroupedToolState.running),
        ),
      ));
      expect(find.text('2/3'), findsOneWidget);

      await tester.pumpWidget(_wrap(
        AssistantToolGroup(
          label: '3 tool calls',
          tools: _tools(GroupedToolState.done),
        ),
      ));
      expect(find.text('3 done'), findsOneWidget);

      await tester.pumpWidget(_wrap(
        AssistantToolGroup(
          label: '3 tool calls',
          tools: _tools(GroupedToolState.failed),
        ),
      ));
      expect(find.text('1 failed'), findsOneWidget);
    });

    testWidgets('the trailing glyph follows the worst state', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        AssistantToolGroup(
          label: '3 tool calls',
          tools: _tools(GroupedToolState.running),
        ),
      ));
      expect(find.byType(AuiSpinner), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);

      await tester.pumpWidget(_wrap(
        AssistantToolGroup(
          label: '3 tool calls',
          tools: _tools(GroupedToolState.failed),
        ),
      ));
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byType(AuiSpinner), findsNothing);

      await tester.pumpWidget(_wrap(
        AssistantToolGroup(
          label: '3 tool calls',
          tools: _tools(GroupedToolState.done),
        ),
      ));
      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('starts collapsed and opens on tap', (
      WidgetTester tester,
    ) async {
      final List<bool> reports = <bool>[];
      await tester.pumpWidget(_wrap(
        AssistantToolGroup(
          label: '3 tool calls',
          tools: _tools(GroupedToolState.done),
          onOpenChange: reports.add,
        ),
      ));
      expect(find.text('read_file'), findsNothing);

      await tester.tap(find.text('3 tool calls'));
      await tester.pump();
      expect(reports, <bool>[true]);
      expect(find.text('read_file'), findsOneWidget);
      expect(find.text('lib/main.dart'), findsOneWidget);
      expect(find.text('118ms'), findsOneWidget);

      await tester.tap(find.text('3 tool calls'));
      await tester.pump();
      expect(reports, <bool>[true, false]);
      expect(find.text('read_file'), findsNothing);
    });

    testWidgets('a bound open state renders rows without a tap', (
      WidgetTester tester,
    ) async {
      final List<bool> reports = <bool>[];
      await tester.pumpWidget(_wrap(
        AssistantToolGroup(
          label: '3 tool calls',
          tools: _tools(GroupedToolState.done),
          open: true,
          onOpenChange: reports.add,
        ),
      ));
      expect(find.text('write_file'), findsOneWidget);

      await tester.tap(find.text('3 tool calls'));
      await tester.pump();
      expect(reports, <bool>[false]);
      // The parent owns `open`, so the rows stay.
      expect(find.text('write_file'), findsOneWidget);
    });

    testWidgets('shows a duration only when the host measured one', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        AssistantToolGroup(
          label: '3 tool calls',
          tools: _tools(GroupedToolState.done),
          initiallyOpen: true,
        ),
      ));
      expect(find.text('118ms'), findsOneWidget);
      expect(find.text('250ms'), findsOneWidget);
      // The middle tool carries no duration.
      expect(find.text('grep'), findsOneWidget);
      expect(find.textContaining('ms'), findsNWidgets(2));
    });
  });

  group('tool error', () {
    testWidgets('renders the failure and its retry budget', (
      WidgetTester tester,
    ) async {
      int retries = 0;
      int skips = 0;
      await tester.pumpWidget(_wrap(
        AssistantToolError(
          name: 'write_file',
          target: 'lib/theme.dart',
          message: 'EACCES: permission denied',
          attempt: 2,
          maxAttempts: 3,
          onRetry: () => retries++,
          onSkip: () => skips++,
        ),
      ));
      expect(find.text('write_file'), findsOneWidget);
      expect(find.text('lib/theme.dart'), findsOneWidget);
      expect(find.text('EACCES: permission denied'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(retries, 1);
      expect(skips, 1);
    });

    testWidgets('a retry in flight swaps the glyph and blocks the button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        AssistantToolError(
          name: 'write_file',
          target: 'lib/theme.dart',
          message: 'boom',
          attempt: 3,
          maxAttempts: 3,
          retrying: true,
          onRetry: () {},
        ),
      ));
      expect(find.text('Retrying'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.byType(AuiSpinner), findsOneWidget);
      expect(
        tester
            .widget<AuiPillButton>(find.widgetWithText(AuiPillButton, 'Retrying'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('skip disables itself without a callback', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantToolError(
          name: 'write_file',
          target: 'lib/theme.dart',
          message: 'boom',
          attempt: 1,
          maxAttempts: 3,
        ),
      ));
      expect(
        tester
            .widget<AuiPillButton>(find.widgetWithText(AuiPillButton, 'Skip'))
            .onPressed,
        isNull,
      );
    });
  });

  group('styled tool grouping', () {
    testWidgets('folds consecutive calls into one card', (
      WidgetTester tester,
    ) async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);

      await tester.pumpWidget(
        AuiRuntimeProvider(
          runtime: runtime,
          child: MaterialApp(
            home: Scaffold(
              body: AuiThreadLayout(
                viewport: AuiThreadViewport(
                  child: AuiThreadMessages(
                    builder: (
                      BuildContext context,
                      ThreadMessage message,
                      bool isLast,
                    ) {
                      return AuiMessage(
                        child: AssistantMessageParts(groupToolCalls: true),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await runtime.thread.send(
        content: <MessagePart>[const TextPart('go')],
      );
      await tester.pump();

      adapter.emit(<MessagePart>[
        const ToolCallPart(
          toolCallId: 'a',
          toolName: 'read_file',
          args: <String, Object?>{'path': 'lib/main.dart'},
        ),
        const ToolCallPart(toolCallId: 'b', toolName: 'grep'),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('2 tool calls'), findsOneWidget);
      expect(find.byType(AssistantToolGroup), findsOneWidget);
      expect(find.byType(AssistantToolCallCard), findsNothing);
      // Both calls are still pending, so the counter reads running/total.
      expect(find.text('0/2'), findsOneWidget);
    });
  });
}
