import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The web preview draws the chrome on every platform; without a frame it says
/// what it is and how to give it one, rather than showing an empty box.
void main() {
  testWidgets('the default body names the origin and the escape hatch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssistantWebPreview(origin: 'assistant-ui.com/docs'),
        ),
      ),
    );
    await tester.pump();

    // Once in the URL bar, once in the default body.
    expect(find.text('assistant-ui.com/docs'), findsNWidgets(2));
    expect(find.textContaining('pass one as'), findsOneWidget);
    expect(find.textContaining('HtmlElementView'), findsOneWidget);
  });

  testWidgets('a supplied frame replaces the default body', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssistantWebPreview(
            origin: 'assistant-ui.com/docs',
            child: SizedBox(key: ValueKey<String>('frame'), width: 100),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey<String>('frame')), findsOneWidget);
    expect(find.textContaining('pass one as'), findsNothing);
  });
}
