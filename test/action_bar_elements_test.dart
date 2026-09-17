import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Widget _message(LocalRuntime runtime, Widget child) => MaterialApp(
      home: Scaffold(
        body: AuiRuntimeProvider(
          runtime: runtime,
          child: AuiThreadMessages(
            builder: (BuildContext context, ThreadMessage message, bool isLast) =>
                AuiMessage(
              message: message,
              isLast: isLast,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const AssistantMessageParts(),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );

ThreadMessage _assistant({
  required MessageStatus status,
  required List<MessagePart> content,
  int branchCount = 1,
}) =>
    ThreadMessage(
      id: 'm1',
      role: MessageRole.assistant,
      createdAt: DateTime(2026, 1, 1),
      status: status,
      branches: <MessageBranch>[
        for (final List<MessagePart> parts in <List<MessagePart>>[
          content,
          if (branchCount > 1)
            const <MessagePart>[TextPart('The other answer.')],
        ])
          MessageBranch(parts),
      ],
    );

void main() {
  group('stopped-run', () {
    testWidgets('a cancelled answer offers Continue, which resumes from it', (
      WidgetTester tester,
    ) async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(
        adapter: adapter,
        initialMessages: <ThreadMessage>[
          _assistant(
            status: const MessageStatusIncomplete(reason: IncompleteReason.cancelled),
            content: const <MessagePart>[TextPart('Half an answer')],
          ),
        ],
      );

      await tester.pumpWidget(_message(runtime, const AssistantContinueRun()));
      await tester.pump();
      expect(find.text('Continue'), findsOneWidget);
      // The partial content stays on screen, as upstream keeps it.
      expect(find.text('Half an answer'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(adapter.hasRun, isTrue);
      expect(adapter.contexts.single.messages.last.id, 'm1',
          reason: 'the run picks up from the stopped message');
    });

    testWidgets('a complete answer offers nothing', (WidgetTester tester) async {
      final LocalRuntime runtime = LocalRuntime(
        adapter: ManualAdapter(),
        initialMessages: <ThreadMessage>[
          _assistant(
            status: const MessageStatusComplete(),
            content: const <MessagePart>[TextPart('Done')],
          ),
        ],
      );
      await tester.pumpWidget(_message(runtime, const AssistantContinueRun()));
      await tester.pump();
      expect(find.text('Continue'), findsNothing);
    });
  });

  group('message-branches', () {
    testWidgets('alternatives show the picker, one branch shows none', (
      WidgetTester tester,
    ) async {
      final LocalRuntime runtime = LocalRuntime(
        adapter: ManualAdapter(),
        initialMessages: <ThreadMessage>[
          _assistant(
            status: const MessageStatusComplete(),
            content: const <MessagePart>[TextPart('First answer')],
            branchCount: 2,
          ),
        ],
      );
      await tester.pumpWidget(
        _message(runtime, const AssistantBranchPickerBar()),
      );
      await tester.pump();
      expect(find.textContaining('1'), findsWidgets);

      final LocalRuntime single = LocalRuntime(
        adapter: ManualAdapter(),
        initialMessages: <ThreadMessage>[
          _assistant(
            status: const MessageStatusComplete(),
            content: const <MessagePart>[TextPart('Only answer')],
          ),
        ],
      );
      await tester.pumpWidget(
        _message(single, const AssistantBranchPickerBar()),
      );
      await tester.pump();
      expect(find.text('1 / 2'), findsNothing);
    });
  });

  group('message-actions', () {
    testWidgets('a settled answer offers copy and reload', (
      WidgetTester tester,
    ) async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(
        adapter: adapter,
        initialMessages: <ThreadMessage>[
          _assistant(
            status: const MessageStatusComplete(),
            content: const <MessagePart>[TextPart('Copy me')],
          ),
        ],
      );
      await tester.pumpWidget(_message(runtime, const AssistantActionBar()));
      await tester.pump();
      expect(find.byIcon(Icons.copy), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);

      // Reloading starts a run from that message again.
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();
      expect(adapter.hasRun, isTrue);
      expect(adapter.contexts.single.messages.last.id, 'm1');
    });
  });
}
