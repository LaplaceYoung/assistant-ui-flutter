import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The context display's three presentations, as the live element offers them.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    final LocalRuntime runtime = LocalRuntime(
      adapter: ManualAdapter(),
      initialMessages: <ThreadMessage>[
        ThreadMessage.single(
          id: 'm1',
          role: MessageRole.user,
          createdAt: DateTime(2026, 1, 1),
          content: const <MessagePart>[TextPart('hello there')],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuiRuntimeProvider(
            runtime: runtime,
            child: child,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the ring draws the composer rail ring', (WidgetTester tester) async {
    await pump(tester, const AssistantContextRing());
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('the bar draws a filled track', (WidgetTester tester) async {
    await pump(tester, const AssistantContextBar());
    // The bar is a track with a fractional fill, not a Material indicator.
    expect(find.byType(FractionallySizedBox), findsOneWidget);
  });

  testWidgets('the text form writes the counts out', (WidgetTester tester) async {
    await pump(tester, const AssistantContextText());
    expect(find.textContaining(' / '), findsOneWidget);
  });
}
