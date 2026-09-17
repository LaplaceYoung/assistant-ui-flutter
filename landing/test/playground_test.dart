import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:assistant_ui_landing/playground/playground_page.dart';

/// The playground as the live one is shaped: a preset list, a live preview, the
/// component and style controls, and the code they add up to.
void main() {
  Future<void> pumpPlayground(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: PlaygroundPage()));
    await tester.pump();
  }

  testWidgets('the preview starts empty, on the welcome the toggle governs', (
    WidgetTester tester,
  ) async {
    await pumpPlayground(tester);
    expect(find.text('How can I help you today?'), findsOneWidget);
    expect(find.text('Suggestions'), findsOneWidget);

    // A preset with the welcome off really drops it.
    await tester.tap(find.text('Minimal'));
    await tester.pump();
    expect(find.text('How can I help you today?'), findsNothing);

    // …and the Default preset brings it back.
    await tester.tap(find.text('Default'));
    await tester.pump();
    expect(find.text('How can I help you today?'), findsOneWidget);
  });

  testWidgets('a style control repaints the preview and the code', (
    WidgetTester tester,
  ) async {
    await pumpPlayground(tester);
    await tester.tap(find.text('Code'));
    await tester.pump();
    expect(find.textContaining('bubbleRadius: 16'), findsOneWidget);

    await tester.tap(find.text('Controls'));
    await tester.pump();
    await tester.tap(find.text('None'));
    await tester.pump();
    await tester.tap(find.text('Code'));
    await tester.pump();
    expect(find.textContaining('bubbleRadius: 0'), findsOneWidget);
  });

  testWidgets('the composer can be switched off and the thread keeps rendering', (
    WidgetTester tester,
  ) async {
    await pumpPlayground(tester);
    expect(find.text('Ask anything…'), findsOneWidget);
    await tester.tap(find.text('Composer'));
    await tester.pump();
    expect(find.text('Ask anything…'), findsNothing);
    expect(find.text('How can I help you today?'), findsOneWidget);
  });

  testWidgets('a shared link restores the configuration', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // What the Share button produces for the Copilot preset, minus the colours
    // the preset already carries.
    await tester.pumpWidget(
      const MaterialApp(home: PlaygroundPage()),
    );
    await tester.pump();
    await tester.tap(find.text('Copilot'));
    await tester.pump();
    expect(find.text('Group tool calls'), findsOneWidget);
    // The preset's own switches are on.
    final SwitchRow group = _row(tester, 'Group tool calls');
    expect(group.value, isTrue);
  });
}

class SwitchRow {
  const SwitchRow(this.value);

  final bool value;
}

/// Reads the switch state of a control row by its label.
SwitchRow _row(WidgetTester tester, String label) {
  final Finder row = find.ancestor(
    of: find.text(label),
    matching: find.byType(Row),
  );
  final AnimatedAlign align = tester.widget<AnimatedAlign>(
    find.descendant(of: row.first, matching: find.byType(AnimatedAlign)).last,
  );
  return SwitchRow(align.alignment == Alignment.centerRight);
}
