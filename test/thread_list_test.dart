import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Widget _app(Widget child, LocalRuntime runtime) => AuiRuntimeProvider(
      runtime: runtime,
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('thread list runtime', () {
    test('starts with one thread and titles it from the first message', () async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);

      expect(runtime.state.threads.threadIds, hasLength(1));
      final String first = runtime.state.threads.mainThreadId;
      expect(runtime.state.threads.itemById(first)!.hasTitle, isFalse);

      await runtime.thread.send(content: <MessagePart>[const TextPart('Plan my week')]);
      expect(runtime.state.threads.itemById(first)!.title, 'Plan my week');

      await adapter.respondWith(<String>['ok']);
      await runtime.thread.settled;
    });

    test('creates, switches and keeps each conversation separate', () async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);

      final String a = runtime.state.threads.mainThreadId;
      await runtime.thread.send(content: <MessagePart>[const TextPart('thread A')]);
      await adapter.respondWith(<String>['A answer']);
      await runtime.thread.settled;
      expect(runtime.state.thread.messages, hasLength(2));

      final String b = await runtime.threads.create();
      expect(runtime.state.threads.mainThreadId, b);
      expect(runtime.state.thread.messages, isEmpty, reason: 'a fresh thread');

      await runtime.thread.send(content: <MessagePart>[const TextPart('thread B')]);
      await adapter.respondWith(<String>['B answer']);
      await runtime.thread.settled;

      await runtime.threads.switchToThread(a);
      expect(runtime.state.threads.mainThreadId, a);
      expect(runtime.state.thread.messages, hasLength(2));
      expect(runtime.state.thread.messages.first.text, 'thread A');

      expect(runtime.state.threads.threadIds, hasLength(2));
      expect(runtime.state.threads.threadIds.first, b,
          reason: 'the newest thread leads the list');
    });

    test('archives, unarchives and deletes conversations', () async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);
      final String a = runtime.state.threads.mainThreadId;
      final String b = await runtime.threads.create();

      await runtime.threads.archive(a);
      expect(runtime.state.threads.threadIds, <String>[b]);
      expect(runtime.state.threads.archivedThreadIds, <String>[a]);
      expect(runtime.state.threads.itemById(a)!.isArchived, isTrue);

      await runtime.threads.unarchive(a);
      expect(runtime.state.threads.archivedThreadIds, isEmpty);
      expect(runtime.state.threads.threadIds.first, a);

      await runtime.threads.delete(b);
      expect(runtime.state.threads.itemById(b), isNull);
      expect(runtime.state.threads.threadIds, <String>[a]);

      // Deleting the thread on screen falls back to another one.
      await runtime.threads.delete(a);
      expect(runtime.state.threads.threadIds, hasLength(1));
      expect(runtime.state.threads.mainThreadId, isNot(a));
      expect(runtime.state.thread.messages, isEmpty);
    });

    test('archiving the active thread moves to the next one', () async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);
      final String a = runtime.state.threads.mainThreadId;
      final String b = await runtime.threads.create();

      await runtime.threads.archive(b);
      expect(runtime.state.threads.mainThreadId, a);
      expect(runtime.state.threads.threadIds, <String>[a]);
    });

    test('rename updates the list item', () async {
      final LocalRuntime runtime = LocalRuntime(adapter: ManualAdapter());
      final String id = runtime.state.threads.mainThreadId;
      await runtime.threads.rename(id, 'Renamed thread');
      expect(runtime.state.threads.itemById(id)!.title, 'Renamed thread');
    });
  });

  group('thread list widgets', () {
    testWidgets('lists threads, switches on tap and creates new ones', (
      WidgetTester tester,
    ) async {
      final LocalRuntime runtime = LocalRuntime(adapter: ManualAdapter());
      await runtime.threads.create(title: 'Second thread');

      await tester.pumpWidget(_app(const AssistantThreadList(), runtime));
      await tester.pump();

      expect(find.text('New thread'), findsWidgets);
      expect(find.text('Second thread'), findsOneWidget);
      expect(find.text('New thread'), findsWidgets);

      // The untitled thread shows the placeholder.
      expect(find.byIcon(Icons.forum_outlined), findsNWidgets(2));

      await tester.tap(find.text('Second thread'));
      await tester.pump();
      expect(runtime.state.threads.mainThreadId,
          runtime.state.threads.threadIds.first);

      // Creating from the sidebar adds another row.
      await tester.tap(find.text('New thread').first);
      await tester.pump();
      expect(runtime.state.threads.threadIds, hasLength(3));
      expect(find.byIcon(Icons.forum_outlined), findsNWidgets(3));
    });

    testWidgets('search filters the rows', (WidgetTester tester) async {
      final LocalRuntime runtime = LocalRuntime(adapter: ManualAdapter());
      await runtime.threads.create(title: 'Weekly planning');
      await runtime.threads.create(title: 'Release notes');

      await tester.pumpWidget(_app(const AssistantThreadList(), runtime));
      await tester.pump();

      expect(find.text('Weekly planning'), findsOneWidget);
      expect(find.text('Release notes'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'weekly');
      await tester.pump();
      expect(find.text('Weekly planning'), findsOneWidget);
      expect(find.text('Release notes'), findsNothing);
    });

    testWidgets('the shell collapses and reopens the sidebar', (
      WidgetTester tester,
    ) async {
      final LocalRuntime runtime = LocalRuntime(adapter: ManualAdapter());
      await tester.pumpWidget(_app(
        const AssistantShell(child: Center(child: Text('content'))),
        runtime,
      ));
      await tester.pump();

      expect(find.text('Chats'), findsOneWidget);
      // Two matches: the create button and the untitled thread's placeholder.
      expect(find.text('New thread'), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.view_sidebar_outlined));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('New thread'), findsNothing);

      await tester.tap(find.byIcon(Icons.view_sidebar_outlined));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('New thread'), findsNWidgets(2));
    });

    testWidgets('dragging the edge resizes the sidebar', (
      WidgetTester tester,
    ) async {
      final LocalRuntime runtime = LocalRuntime(adapter: ManualAdapter());
      await tester.pumpWidget(_app(
        const AssistantShell(
          sidebarWidth: 260,
          child: Center(child: Text('content')),
        ),
        runtime,
      ));
      await tester.pump();

      final Finder handle = find.byWidgetPredicate(
        (Widget w) =>
            w is MouseRegion &&
            w.cursor == SystemMouseCursors.resizeLeftRight,
      );
      expect(handle, findsOneWidget);
      expect(tester.getSize(handle).width, 8);

      await tester.drag(handle, const Offset(60, 0));
      await tester.pump();
      expect(
        tester.getSize(find.byType(AssistantThreadList)).width,
        greaterThan(300),
      );

      // The clamp holds at the configured maximum.
      await tester.drag(handle, const Offset(400, 0));
      await tester.pump();
      expect(
        tester.getSize(find.byType(AssistantThreadList)).width,
        lessThanOrEqualTo(420),
      );
    });

    testWidgets('the copilot side puts the rail on the right', (
      WidgetTester tester,
    ) async {
      final LocalRuntime runtime = LocalRuntime(adapter: ManualAdapter());
      await tester.pumpWidget(_app(
        const AssistantShell(
          side: AssistantShellSide.right,
          child: Center(child: Text('content')),
        ),
        runtime,
      ));
      await tester.pump();

      final double railLeft = tester.getTopLeft(find.text('Chats')).dx;
      final double contentLeft = tester.getTopLeft(find.text('content')).dx;
      expect(railLeft, greaterThan(contentLeft));
    });
  });
}
