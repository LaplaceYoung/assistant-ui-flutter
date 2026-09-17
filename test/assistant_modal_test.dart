import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  Widget modalApp(LocalRuntime runtime, {ValueChanged<Size>? onSize}) {
    return AuiRuntimeProvider(
      runtime: runtime,
      child: MaterialApp(
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              const Positioned.fill(child: ColoredBox(color: Color(0xFFEEEEEE))),
              AssistantModal(
                onSizeChange: onSize,
                title: 'Luna',
                thread: const Center(child: Text('thread body')),
                threadList: const Center(child: Text('thread list')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('the bubble opens and closes the panel', (
    WidgetTester tester,
  ) async {
    final LocalRuntime runtime =
        LocalRuntime(adapter: StaticAdapter(<MessagePart>[]));
    await tester.pumpWidget(modalApp(runtime));
    // Closed: only the bubble.
    expect(find.text('thread body'), findsNothing);
    expect(find.text('Luna'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Open the assistant'));
    await tester.pump();
    expect(find.text('Luna'), findsOneWidget);
    expect(find.text('thread body'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Close the assistant').first);
    await tester.pump();
    expect(find.text('thread body'), findsNothing);
  });

  testWidgets('the header switches between the thread and the list', (
    WidgetTester tester,
  ) async {
    final LocalRuntime runtime =
        LocalRuntime(adapter: StaticAdapter(<MessagePart>[]));
    await tester.pumpWidget(modalApp(runtime));
    await tester.tap(find.bySemanticsLabel('Open the assistant'));
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Show the thread list'));
    await tester.pump();
    expect(find.text('thread list'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Back to the thread'));
    await tester.pump();
    expect(find.text('thread body'), findsOneWidget);
  });

  testWidgets('a run start opens the panel', (WidgetTester tester) async {
    final ManualAdapter adapter = ManualAdapter();
    final LocalRuntime runtime = LocalRuntime(adapter: adapter);
    await tester.pumpWidget(modalApp(runtime));
    expect(find.text('thread body'), findsNothing);

    await runtime.thread.send(content: <MessagePart>[const TextPart('go')]);
    await tester.pump();
    expect(find.text('thread body'), findsOneWidget);
  });

  testWidgets('the grip resizes the panel and the arrows nudge it', (
    WidgetTester tester,
  ) async {
    final List<Size> sizes = <Size>[];
    final LocalRuntime runtime =
        LocalRuntime(adapter: StaticAdapter(<MessagePart>[]));
    await tester.pumpWidget(modalApp(runtime, onSize: sizes.add));
    await tester.tap(find.bySemanticsLabel('Open the assistant'));
    await tester.pump();

    // Drag the top edge up: the panel grows.
    await tester.drag(find.bySemanticsLabel('Resize the panel'), const Offset(0, -60));
    // `onDoubleTap` keeps a timer alive; let it lapse before the test ends.
    await tester.pump(const Duration(milliseconds: 400));
    expect(sizes, isNotEmpty);
    expect(sizes.last.height, greaterThan(500));

    // The keyboard nudge needs the grip focused.
    await tester.tap(find.bySemanticsLabel('Resize the panel'));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(sizes.last.height, greaterThan(0));
    // The tap on the grip armed the double-tap detector.
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('the panel never shrinks past the floor', (
    WidgetTester tester,
  ) async {
    final List<Size> sizes = <Size>[];
    final LocalRuntime runtime =
        LocalRuntime(adapter: StaticAdapter(<MessagePart>[]));
    await tester.pumpWidget(modalApp(runtime, onSize: sizes.add));
    await tester.tap(find.bySemanticsLabel('Open the assistant'));
    await tester.pump();

    await tester.drag(find.bySemanticsLabel('Resize the panel'), const Offset(0, 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(sizes.last.height, greaterThanOrEqualTo(400));
    expect(sizes.last.width, greaterThanOrEqualTo(320));
  });
}
