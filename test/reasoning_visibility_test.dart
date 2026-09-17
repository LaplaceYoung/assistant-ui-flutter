import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Widget _thread(LocalRuntime runtime, {bool showReasoning = true}) => MaterialApp(
      home: Scaffold(
        body: AuiRuntimeProvider(
          runtime: runtime,
          child: AssistantThread(showReasoning: showReasoning),
        ),
      ),
    );

/// A thread seeded with a reasoning part and an answer.
LocalRuntime _seeded() => LocalRuntime(
      adapter: ManualAdapter(),
      initialMessages: <ThreadMessage>[
        ThreadMessage.single(
          id: 'a1',
          role: MessageRole.assistant,
          createdAt: DateTime(2026, 1, 1),
          content: const <MessagePart>[
            ReasoningPart('weighing the two options'),
            TextPart('Here is the answer.'),
          ],
        ),
      ],
    );

void main() {
  testWidgets('the reasoning parts hide when the host says so', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_thread(_seeded()));
    await tester.pump();
    expect(find.textContaining('weighing the two options'), findsOneWidget);
    expect(find.textContaining('Here is the answer.'), findsOneWidget);

    await tester.pumpWidget(_thread(_seeded(), showReasoning: false));
    await tester.pump();
    expect(find.textContaining('weighing the two options'), findsNothing);
    // The answer is untouched: the knob hides one part, not the message.
    expect(find.textContaining('Here is the answer.'), findsOneWidget);
  });

  testWidgets('the thread reports the thinking tokens the adapter reported', (
    WidgetTester tester,
  ) async {
    final ManualAdapter adapter = ManualAdapter();
    final LocalRuntime runtime = LocalRuntime(adapter: adapter);
    await tester.pumpWidget(_thread(runtime));
    await tester.pump();
    expect(runtime.state.thread.thinkingTokens, 0);

    await runtime.thread.send(content: <MessagePart>[const TextPart('go')]);
    await tester.pump();
    adapter.emit(
      const <MessagePart>[ReasoningPart('thinking'), TextPart('done')],
    );
    adapter.current.add(
      ChatModelRunResult(
        content: const <MessagePart>[],
        metadata: const MessageMetadata(thinkingTokens: 512),
      ),
    );
    await tester.pump();
    expect(runtime.state.thread.thinkingTokens, 512);

    // A later report without the field keeps what was counted.
    adapter.current.add(
      const ChatModelRunResult(content: <MessagePart>[]),
    );
    await tester.pump();
    expect(runtime.state.thread.thinkingTokens, 512);
  });
}
