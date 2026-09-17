import 'dart:async';

import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Widget _app(LocalRuntime runtime) => AuiRuntimeProvider(
      runtime: runtime,
      child: const MaterialApp(
        home: Scaffold(body: AssistantThread()),
      ),
    );

void main() {
  testWidgets('shows the empty state, then the sent message', (
    WidgetTester tester,
  ) async {
    final ManualAdapter adapter = ManualAdapter();
    final LocalRuntime runtime = LocalRuntime(adapter: adapter);

    await tester.pumpWidget(_app(runtime));
    expect(find.text('How can I help you today?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Hello there');
    await tester.pump();
    expect(runtime.state.composer.text, 'Hello there');

    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();

    expect(adapter.runs, hasLength(1));
    expect(find.text('Hello there'), findsOneWidget);
    expect(find.text('How can I help you today?'), findsNothing);
  });

  testWidgets('renders streamed assistant text and a stop button', (
    WidgetTester tester,
  ) async {
    final ManualAdapter adapter = ManualAdapter();
    final LocalRuntime runtime = LocalRuntime(adapter: adapter);

    await tester.pumpWidget(_app(runtime));
    await tester.enterText(find.byType(TextField), 'weather?');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();

    // Mid-run the composer offers stop instead of send.
    expect(find.byIcon(Icons.stop), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);

    adapter.emit(<MessagePart>[const TextPart('It is ')]);
    await tester.pump();
    adapter.emit(<MessagePart>[const TextPart('It is sunny.')]);
    await tester.pump();

    expect(find.textContaining('It is sunny.'), findsOneWidget);

    await adapter.finish();
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.stop), findsNothing);
    expect(find.byIcon(Icons.copy), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
  });

  testWidgets('cancel from the stop button marks the message incomplete', (
    WidgetTester tester,
  ) async {
    final ManualAdapter adapter = ManualAdapter();
    final LocalRuntime runtime = LocalRuntime(adapter: adapter);

    await tester.pumpWidget(_app(runtime));
    await tester.enterText(find.byType(TextField), 'stop me');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();

    adapter.emit(<MessagePart>[const TextPart('partial')]);
    await tester.pump();

    await tester.tap(find.byIcon(Icons.stop));
    await tester.pump();
    await tester.pump();

    final ThreadMessage assistant = runtime.state.thread.messages.last;
    expect(assistant.status, isA<MessageStatusIncomplete>());
    expect(assistant.text, 'partial');
  });

  testWidgets('renders a tool call card with its result', (
    WidgetTester tester,
  ) async {
    final ManualAdapter adapter = ManualAdapter();
    final LocalRuntime runtime = LocalRuntime(
      adapter: adapter,
      options: LocalRuntimeOptions(
        tools: <String, ToolDefinition>{
          'get_weather': ToolDefinition(
            description: 'weather',
            execute: (Map<String, Object?> args) async => 'sunny',
          ),
        },
      ),
    );

    await tester.pumpWidget(_app(runtime));
    await tester.enterText(find.byType(TextField), 'weather?');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();

    adapter.emit(<MessagePart>[
      const ToolCallPart(
        toolCallId: 'call_1',
        toolName: 'get_weather',
        args: <String, Object?>{'city': 'SF'},
      ),
    ]);
    await adapter.finish();
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('get_weather'), findsWidgets);
    expect(find.textContaining('sunny'), findsOneWidget);
  });

  testWidgets('markdown renders headings, code fences and lists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssistantMarkdown(
            text: '# Title\n\nSome **bold** and `code`.\n\n```dart\nfinal x = 1;\n```\n\n- one\n- two',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Title'), findsOneWidget);
    expect(find.text('dart'), findsOneWidget);
    expect(find.textContaining('final x = 1;'), findsOneWidget);
    expect(find.text('•'), findsNWidgets(2));
  });

  testWidgets('branch picker switches between regenerated answers', (
    WidgetTester tester,
  ) async {
    final ManualAdapter adapter = ManualAdapter();
    final LocalRuntime runtime = LocalRuntime(adapter: adapter);

    await tester.pumpWidget(_app(runtime));
    await tester.enterText(find.byType(TextField), 'hi');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();

    adapter.emit(<MessagePart>[const TextPart('first')]);
    await adapter.finish();
    await tester.pump();
    await tester.pump();

    expect(find.text('first'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing,
        reason: 'a single branch has nothing to pick between');

    unawaited(runtime.thread.reload());
    await tester.pump();
    adapter.emit(<MessagePart>[const TextPart('second')]);
    await adapter.finish();
    await tester.pump();
    await tester.pump();

    expect(find.text('second'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();

    expect(find.text('first'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('assistant messages render markdown, reasoning and tool cards', (
    WidgetTester tester,
  ) async {
    final LocalRuntime runtime = LocalRuntime(
      adapter: ManualAdapter(),
      initialMessages: <ThreadMessage>[
        ThreadMessage.single(
          id: 'u1',
          role: MessageRole.user,
          content: const <MessagePart>[TextPart('weather?')],
          createdAt: DateTime(2024),
        ),
        ThreadMessage.single(
          id: 'a1',
          role: MessageRole.assistant,
          content: const <MessagePart>[
            ReasoningPart('Weighing the options'),
            TextPart('Try this:\n\n```dart\nfinal x = 1;\n```'),
            ToolCallPart(
              toolCallId: 'call_1',
              toolName: 'get_weather',
              args: <String, Object?>{'city': 'SF'},
              result: 'sunny',
            ),
          ],
          createdAt: DateTime(2024),
        ),
      ],
    );

    await tester.pumpWidget(_app(runtime));
    await tester.pump();

    expect(find.textContaining('Thought process'), findsOneWidget);
    expect(find.text('dart'), findsOneWidget);
    expect(find.textContaining('final x = 1;'), findsOneWidget);
    expect(find.textContaining('get_weather finished'), findsOneWidget);
    expect(find.textContaining('sunny'), findsOneWidget);
  });
}
