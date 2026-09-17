import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The row actions a reader expects to work: hover to reveal them, click to
/// archive, unarchive or delete the conversation they belong to.
void main() {
  /// Fills the list and returns the id behind each title.
  Future<(LocalRuntime, Map<String, String>)> pumpList(
    WidgetTester tester,
  ) async {
    final LocalRuntime runtime = LocalRuntime(adapter: ManualAdapter());
    final Map<String, String> byTitle = <String, String>{};
    for (int i = 0; i < 2; i++) {
      final String id = await runtime.threads.create();
      await runtime.threads.rename(id, 'Chat $i');
      byTitle['Chat $i'] = id;
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AuiRuntimeProvider(
            runtime: runtime,
            child: const SizedBox(height: 400, child: AssistantThreadList()),
          ),
        ),
      ),
    );
    await tester.pump();
    return (runtime, byTitle);
  }

  testWidgets('archiving a row archives that conversation', (
    WidgetTester tester,
  ) async {
    final (LocalRuntime runtime, Map<String, String> byTitle) =
        await pumpList(tester);
    final String target = byTitle['Chat 0']!;
    final int before = runtime.threads.state.threadIds.length;

    // The actions appear on hover, as the row hides them until then.
    final TestGesture mouse =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();
    await mouse.moveTo(tester.getCenter(find.text('Chat 0')));
    await tester.pump();

    await tester.tap(find.byTooltip('Archive'));
    await tester.pump();

    expect(
      runtime.threads.state.threadIds.length,
      before - 1,
      reason: 'the row was archived',
    );
    expect(runtime.threads.state.archivedThreadIds, contains(target));
  });

  testWidgets('deleting a row removes that conversation', (
    WidgetTester tester,
  ) async {
    final (LocalRuntime runtime, Map<String, String> byTitle) =
        await pumpList(tester);
    final String target = byTitle['Chat 0']!;
    final int before = runtime.threads.state.threadIds.length;

    final TestGesture mouse =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await tester.pump();
    await mouse.moveTo(tester.getCenter(find.text('Chat 0')));
    await tester.pump();

    await tester.tap(find.byTooltip('Delete'));
    await tester.pump();

    expect(runtime.threads.state.threadIds.length, before - 1);
    expect(runtime.threads.state.threadIds, isNot(contains(target)));
  });
}
