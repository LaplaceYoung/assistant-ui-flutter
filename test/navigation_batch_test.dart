import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('thread list sidebar', () {
    testWidgets('frames the list and reports the two links', (
      WidgetTester tester,
    ) async {
      final List<String> calls = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantThreadListSidebar(
          onOpenSite: () => calls.add('site'),
          onOpenSource: () => calls.add('source'),
          threadList: const Text('thread list goes here'),
        ),
      ));
      expect(find.text('assistant-ui'), findsOneWidget);
      expect(find.text('thread list goes here'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
      expect(find.text('View Source'), findsOneWidget);

      await tester.tap(find.text('assistant-ui'));
      await tester.tap(find.text('GitHub'));
      await tester.pump();
      expect(calls, <String>['site', 'source']);
    });

    testWidgets('renders without a list', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const AssistantThreadListSidebar()));
      expect(find.text('assistant-ui'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('conversation map', () {
    const List<ConversationMapEntry> entries = <ConversationMapEntry>[
      ConversationMapEntry(
        id: 'm1',
        title: 'Why the rewrite?',
        preview: 'Tool calls needed a home.',
      ),
      ConversationMapEntry(id: 'm2', title: 'What about branches?'),
      ConversationMapEntry(id: 'm3', title: 'Ship it.'),
    ];

    testWidgets('marks the active tick and selects on tap', (
      WidgetTester tester,
    ) async {
      final List<String> selected = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantConversationMap(
          entries: entries,
          activeId: 'm2',
          visibleIds: const <String>['m1', 'm2'],
          onSelect: selected.add,
        ),
      ));
      expect(find.bySemanticsLabel('Why the rewrite?'), findsOneWidget);
      expect(find.bySemanticsLabel('Ship it.'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Ship it.'));
      await tester.pump();
      expect(selected, <String>['m3']);
    });

    testWidgets('the arrow keys step through the turns', (
      WidgetTester tester,
    ) async {
      final List<String> selected = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantConversationMap(
          entries: entries,
          activeId: 'm1',
          onSelect: selected.add,
        ),
      ));
      // The rail takes focus when the pointer is over it; hovering a tick also
      // parks the keyboard cursor on it, so the step starts from there.
      final TestGesture mouse =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(
        tester.getCenter(find.bySemanticsLabel('Why the rewrite?')),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(selected, <String>['m2']);
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pump();
      expect(selected.last, 'm3');
      await mouse.removePointer();
    });

    testWidgets('pointing at a tick shows its preview', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantConversationMap(
          entries: entries,
          activeId: 'm1',
          width: 240,
        ),
      ));
      expect(find.text('Why the rewrite?'), findsNothing);

      final TestGesture mouse =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.bySemanticsLabel('Why the rewrite?')));
      await tester.pump();
      expect(find.text('Why the rewrite?'), findsOneWidget);
      expect(find.text('Tool calls needed a home.'), findsOneWidget);
      await mouse.removePointer();
    });
  });
}
