import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

/// Sends one message through the composer, the way a reader would.
Future<void> testsend(WidgetTester tester, LocalRuntime runtime) async {
  await runtime.thread.send(content: <MessagePart>[const TextPart('go')]);
  await tester.pump();
}

void main() {
  group('empty state', () {
    testWidgets('greets, suggests and offers the composer', (
      WidgetTester tester,
    ) async {
      final List<String> picked = <String>[];
      int sends = 0;
      await tester.pumpWidget(_wrap(
        AssistantEmptyState(
          greeting: 'How can I help you today?',
          suggestions: const <String>['Weather in Tokyo', 'Draft a plan'],
          onSuggestion: picked.add,
          composerPlaceholder: 'Ask anything…',
          onSend: () => sends++,
        ),
      ));
      expect(find.text('How can I help you today?'), findsOneWidget);
      expect(find.text('Ask anything…'), findsOneWidget);

      await tester.tap(find.text('Weather in Tokyo'));
      await tester.pump();
      expect(picked, <String>['Weather in Tokyo']);

      await tester.tap(find.bySemanticsLabel('Send'));
      await tester.pump();
      expect(sends, 1);
    });

    testWidgets('hides the composer when none is configured', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantEmptyState(greeting: 'Hi'),
      ));
      expect(find.text('Hi'), findsOneWidget);
      expect(find.bySemanticsLabel('Send'), findsNothing);
    });
  });

  group('error state', () {
    testWidgets('names the failure and retries', (WidgetTester tester) async {
      int retries = 0;
      await tester.pumpWidget(_wrap(
        AssistantErrorState(
          title: 'The run failed',
          detail: 'upstream returned 502',
          onRetry: () => retries++,
        ),
      ));
      expect(find.text('The run failed'), findsOneWidget);
      expect(find.text('upstream returned 502'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(retries, 1);
    });

    testWidgets('a retry in flight replaces the card', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantErrorState(
          title: 'The run failed',
          detail: 'upstream returned 502',
          retrying: true,
        ),
      ));
      expect(find.text('Retrying'), findsOneWidget);
      expect(find.text('The run failed'), findsNothing);
    });
  });

  group('suggestions', () {
    testWidgets('reports a pick and marks the selected one', (
      WidgetTester tester,
    ) async {
      final List<String> picked = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantSuggestions(
          suggestions: const <String>['Summarize', 'Translate'],
          selected: 'Translate',
          onSuggestion: picked.add,
        ),
      ));
      await tester.tap(find.text('Summarize'));
      await tester.pump();
      expect(picked, <String>['Summarize']);
      expect(find.text('Translate'), findsOneWidget);
    });

    testWidgets('the list variant stacks the rows', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantSuggestions(
          suggestions: <String>['One', 'Two'],
          variant: AuiSuggestionVariant.list,
        ),
      ));
      expect(find.text('One'), findsOneWidget);
      expect(find.text('Two'), findsOneWidget);
    });
  });

  group('day separator', () {
    testWidgets('rules the days and reveals times on hover', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantDaySeparator(
          messages: <DatedMessage>[
            DatedMessage(
              id: 'm1',
              day: 'Today',
              time: '09:12',
              role: 'user',
              text: 'Draft the notes',
            ),
            DatedMessage(
              id: 'm2',
              day: 'Today',
              time: '09:13',
              role: 'assistant',
              text: 'On it.',
            ),
            DatedMessage(
              id: 'm3',
              day: 'Yesterday',
              time: '18:02',
              role: 'user',
              text: 'What changed?',
            ),
          ],
        ),
      ));
      // One rule per distinct day, in order.
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('09:12'), findsOneWidget);
    });
  });

  group('streaming text', () {
    testWidgets('reveals words up to the count and shows the caret', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantStreamingText(
          streaming: true,
          count: 3,
          segments: <StreamingSegment>[
            StreamingSegment('The data stream'),
            StreamingSegment('keeps calls inline', mono: true),
          ],
        ),
      ));
      expect(find.text('The'), findsOneWidget);
      expect(find.text('data'), findsOneWidget);
      expect(find.text('stream'), findsOneWidget);
      expect(find.text('keeps'), findsNothing);
    });

    testWidgets('a settled run drops the caret', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const AssistantStreamingText(
          count: 2,
          segments: <StreamingSegment>[StreamingSegment('All done here')],
        ),
      ));
      expect(find.text('All'), findsOneWidget);
      expect(find.text('done'), findsOneWidget);
      expect(find.text('here'), findsNothing);
    });
  });

  group('shared conversation', () {
    testWidgets('reads as read only and can continue', (
      WidgetTester tester,
    ) async {
      int continues = 0;
      await tester.pumpWidget(_wrap(
        AssistantSharedConversation(
          title: 'Streaming rollout',
          sharedBy: 'laplace',
          sharedAt: '2h ago',
          onContinue: () => continues++,
          turns: const <SharedTurn>[
            SharedTurn(id: 't1', role: 'user', text: 'Why the rewrite?'),
            SharedTurn(id: 't2', role: 'assistant', text: 'Tool calls.'),
          ],
        ),
      ));
      expect(find.text('Streaming rollout'), findsOneWidget);
      expect(find.text('shared by laplace · 2h ago'), findsOneWidget);
      expect(find.text('read only'), findsOneWidget);
      await tester.tap(find.text('Continue in your own chat'), warnIfMissed: false);
      await tester.pump();
      expect(continues, 1);
    });
  });

  group('regenerate menu', () {
    testWidgets('opens, marks the current option and picks another', (
      WidgetTester tester,
    ) async {
      final List<String> picked = <String>[];
      final List<bool> opens = <bool>[];
      await tester.pumpWidget(_wrap(
        AssistantRegenerateMenu(
          options: const <RegenerateOption>[
            RegenerateOption(id: 'luna', label: 'Luna', detail: 'fast'),
            RegenerateOption(id: 'opus', label: 'Opus', detail: 'deep'),
          ],
          currentId: 'luna',
          open: false,
          onOpenChange: opens.add,
          onPick: picked.add,
        ),
      ));
      await tester.tap(find.bySemanticsLabel('Regenerate with a different model'));
      await tester.pump();
      expect(opens, <bool>[true]);

      await tester.pumpWidget(_wrap(
        AssistantRegenerateMenu(
          options: const <RegenerateOption>[
            RegenerateOption(id: 'luna', label: 'Luna', detail: 'fast'),
            RegenerateOption(id: 'opus', label: 'Opus', detail: 'deep'),
          ],
          currentId: 'luna',
          open: true,
          onOpenChange: opens.add,
          onPick: picked.add,
        ),
      ));
      expect(find.text('current'), findsOneWidget);
      await tester.tap(find.text('Opus'));
      await tester.pump();
      expect(picked, <String>['opus']);
    });
  });

  group('scroll anchor', () {
    testWidgets('the pill appears only once the reader scrolls up', (
      WidgetTester tester,
    ) async {
      final LocalRuntime runtime =
          LocalRuntime(adapter: StaticAdapter(<MessagePart>[]));
      await tester.pumpWidget(
        AuiRuntimeProvider(
          runtime: runtime,
          child: const MaterialApp(
            home: Scaffold(body: AssistantThread()),
          ),
        ),
      );
      await tester.pump();
      // Pinned at the bottom: the pill is present but invisible.
      expect(find.text('Jump to latest'), findsOneWidget);
      expect(
        tester.widget<AnimatedOpacity>(
          find
              .ancestor(
                of: find.text('Jump to latest'),
                matching: find.byType(AnimatedOpacity),
              )
              .first,
        ).opacity,
        0,
      );
    });
  });

  group('stopped run', () {
    testWidgets('a stopped run offers to continue', (
      WidgetTester tester,
    ) async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);
      await tester.pumpWidget(
        AuiRuntimeProvider(
          runtime: runtime,
          child: const MaterialApp(
            home: Scaffold(body: AssistantThread()),
          ),
        ),
      );
      await testsend(tester, runtime);
      adapter.emit(<MessagePart>[const TextPart('It is ')]);
      await tester.pump();
      expect(find.text('Continue'), findsNothing);

      runtime.thread.cancelRun();
      await tester.pump();
      await tester.pump();
      expect(find.text('Continue'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pump();
      // The affordance starts a fresh run from the stopped message.
      expect(adapter.runs, hasLength(2));
    });
  });

  group('inline edit', () {
    testWidgets('warns how much history the edit discards', (
      WidgetTester tester,
    ) async {
      final LocalRuntime runtime =
          LocalRuntime(adapter: StaticAdapter(<MessagePart>[]));
      await tester.pumpWidget(
        AuiRuntimeProvider(
          runtime: runtime,
          child: const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AssistantInlineComposer(
                  discardNotice: '3 replies will be discarded',
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('3 replies will be discarded'), findsOneWidget);
    });

    testWidgets('no warning when the host does not send one', (
      WidgetTester tester,
    ) async {
      final LocalRuntime runtime =
          LocalRuntime(adapter: StaticAdapter(<MessagePart>[]));
      await tester.pumpWidget(
        AuiRuntimeProvider(
          runtime: runtime,
          child: const MaterialApp(
            home: Scaffold(body: Center(child: AssistantInlineComposer())),
          ),
        ),
      );
      expect(find.textContaining('discarded'), findsNothing);
    });
  });
}
