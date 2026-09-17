import 'package:assistant_ui_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app a reader lands on: the default thread, with the composer wired the
/// way the package documents — empty it offers no send, filled it sends.
void main() {
  testWidgets('the default page greets and takes a message', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1100, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    expect(find.text('assistant_ui'), findsOneWidget);
    expect(find.text('How can I help you today?'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    // Nothing typed yet, so there is nothing to send.
    expect(find.byIcon(Icons.arrow_upward), findsNothing);

    await tester.enterText(find.byType(TextField), 'What can you do?');
    await tester.pump();
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    expect(find.text('What can you do?'), findsOneWidget);
    // The empty state gives way to the conversation.
    expect(find.text('How can I help you today?'), findsNothing);

    // Let the scripted adapter finish so no timer outlives the test.
    for (int i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  });
}
