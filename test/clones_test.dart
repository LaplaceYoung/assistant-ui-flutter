import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Widget _app(LocalRuntime runtime, Widget clone) => AuiRuntimeProvider(
      runtime: runtime,
      child: MaterialApp(home: Scaffold(body: clone)),
    );

LocalRuntime _runtime({List<ThreadMessage> messages = const <ThreadMessage>[]}) =>
    LocalRuntime(adapter: ManualAdapter(), initialMessages: messages);

List<ThreadMessage> _conversation() => <ThreadMessage>[
      ThreadMessage.single(
        id: 'u1',
        role: MessageRole.user,
        content: const <MessagePart>[TextPart('Hello there')],
        createdAt: DateTime(2024),
      ),
      ThreadMessage.single(
        id: 'a1',
        role: MessageRole.assistant,
        content: const <MessagePart>[TextPart('**Hi** — how can I help?')],
        createdAt: DateTime(2024),
      ),
    ];

void main() {
  testWidgets('chatgpt clone: empty state, composer and disclaimer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_runtime(), const ChatGptClone()));
    await tester.pump();

    expect(find.text('Where should we begin?'), findsOneWidget);
    expect(find.text('Ask anything'), findsOneWidget);

    // Four-state action: idle and empty renders the disabled send control.
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
  });

  testWidgets('chatgpt clone: user bubble and always-visible assistant actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_runtime(messages: _conversation()), const ChatGptClone()),
    );
    await tester.pump();

    expect(find.textContaining('Hello there'), findsOneWidget);
    expect(
      find.text('ChatGPT can make mistakes. Check important info.'),
      findsOneWidget,
    );
    expect(find.textContaining('Hi'), findsWidgets);
    // Assistant action bar is always visible and carries the vendor actions.
    expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
    expect(find.byIcon(Icons.ios_share), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz), findsOneWidget);
  });

  testWidgets('claude clone: sparkle heading, model picker and mode tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_runtime(), const ClaudeClone()));
    await tester.pump();

    // Once as the serif heading, once as the composer's hint.
    expect(find.text('How can I help you today?'), findsNWidgets(2));
    expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    expect(find.text('Sonnet 4.5'), findsOneWidget);
    for (final String tab in <String>['Write', 'Learn', 'Code', 'From Drive', 'From Calendar']) {
      expect(find.text(tab), findsOneWidget);
    }
  });

  testWidgets('claude clone: conversation keeps the serif chrome and disclaimer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _app(_runtime(messages: _conversation()), const ClaudeClone()),
    );
    await tester.pump();

    expect(find.textContaining('Hello there'), findsOneWidget);
    expect(
      find.text('Claude can make mistakes. Please double-check responses.'),
      findsOneWidget,
    );
    // Assistant actions are hover-only, so they exist but do not occupy space.
    expect(find.byIcon(Icons.thumb_up_outlined), findsOneWidget);
  });

  testWidgets('gemini clone: greeting, plus menu and model picker', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(_runtime(), const GeminiClone()));
    await tester.pump();

    expect(find.text('How can I help you today?'), findsOneWidget);
    expect(find.text('Ask Gemini'), findsOneWidget);
    expect(find.text('Fast'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Add photos & files'), findsOneWidget);
    expect(find.text('Deep Research'), findsOneWidget);
    expect(find.text('Guided Learning'), findsOneWidget);
  });

  testWidgets('grok clone: wordmark, collapsing model pill and mic slot', (
    WidgetTester tester,
  ) async {
    final LocalRuntime runtime = _runtime();
    await tester.pumpWidget(_app(runtime, const GrokClone()));
    await tester.pump();

    expect(find.text('grok'), findsOneWidget);
    expect(find.text('Grok 4.1'), findsOneWidget);
    expect(find.byIcon(Icons.attach_file), findsOneWidget);

    // Typing collapses the pill to its icon and swaps in the send control.
    await tester.enterText(find.byType(TextField), 'hi');
    await tester.pump();
    expect(find.text('Grok 4.1'), findsNothing);
    expect(find.byIcon(Icons.bolt), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
  });
}
