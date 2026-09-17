import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The sentence a reader wrote and never sent: the age is stated the way the
/// live card states it, and both actions report back.
void main() {
  test('the age reads in the units the live card uses', () {
    final DateTime now = DateTime(2026, 1, 1, 12);
    expect(
      AssistantDraftRestore.describe(now.subtract(const Duration(seconds: 20)),
          now: now),
      'just now',
    );
    expect(
      AssistantDraftRestore.describe(now.subtract(const Duration(minutes: 1)),
          now: now),
      '1 minute ago',
    );
    expect(
      AssistantDraftRestore.describe(now.subtract(const Duration(minutes: 2)),
          now: now),
      '2 minutes ago',
    );
    expect(
      AssistantDraftRestore.describe(now.subtract(const Duration(hours: 3)),
          now: now),
      '3 hours ago',
    );
    expect(
      AssistantDraftRestore.describe(now.subtract(const Duration(days: 2)),
          now: now),
      '2 days ago',
    );
  });

  testWidgets('the card shows the draft and reports both actions', (
    WidgetTester tester,
  ) async {
    int restores = 0;
    int dismissals = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssistantDraftRestore(
            text: 'Add a regression test for draft…',
            savedAt: DateTime.now().subtract(const Duration(minutes: 2)),
            onRestore: () => restores++,
            onDismiss: () => dismissals++,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Add a regression test for draft…'), findsOneWidget);
    expect(find.text('unsent draft · 2 minutes ago'), findsOneWidget);

    await tester.tap(find.text('Restore'));
    await tester.pump();
    expect(restores, 1);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(dismissals, 1);
  });
}
