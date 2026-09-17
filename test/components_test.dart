import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Records ratings for the feedback test.
class RecordingFeedbackAdapter extends FeedbackAdapter {
  final List<FeedbackRequest> requests = <FeedbackRequest>[];

  @override
  Future<void> submit(FeedbackRequest request) async => requests.add(request);
}

/// Speaks nothing, but reports that it was asked to.
class RecordingSpeechAdapter extends SpeechSynthesisAdapter {
  int speakCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> speak(String text) async => speakCalls++;

  @override
  Future<void> stop() async => stopCalls++;
}

Widget _app(Widget child, {LocalRuntime? runtime}) {
  final Widget body = Scaffold(body: Center(child: child));
  if (runtime == null) return MaterialApp(home: body);
  return AuiRuntimeProvider(runtime: runtime, child: MaterialApp(home: body));
}

ThreadMessage _assistantMessage({
  List<MessagePart> parts = const <MessagePart>[TextPart('hello')],
  MessageTiming? timing,
}) =>
    ThreadMessage.single(
      id: 'a1',
      role: MessageRole.assistant,
      content: parts,
      createdAt: DateTime(2024),
      metadata: MessageMetadata(timing: timing),
    );

void main() {
  testWidgets('tooltip icon button honours enabled and disabled states', (
    WidgetTester tester,
  ) async {
    int taps = 0;
    await tester.pumpWidget(_app(
      Column(
        children: <Widget>[
          AssistantTooltipIconButton(
            icon: Icons.copy,
            tooltip: 'Copy',
            onPressed: () => taps++,
          ),
          const AssistantTooltipIconButton(
            icon: Icons.check,
            tooltip: 'Disabled',
          ),
        ],
      ),
    ));

    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump();
    expect(taps, 1);

    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    expect(taps, 1, reason: 'a null onPressed disables the control');
  });

  testWidgets('menu opens and reports the selection', (
    WidgetTester tester,
  ) async {
    String? picked;
    await tester.pumpWidget(_app(
      AssistantMenuButton(
        items: <AssistantMenuItem>[
          AssistantMenuItem(
            label: 'Fast',
            description: 'Answers in a blink',
            selected: true,
            onSelected: () => picked = 'fast',
          ),
          AssistantMenuItem(
            label: 'Thinking',
            description: 'Reasons before answering',
            onSelected: () => picked = 'thinking',
          ),
          const AssistantMenuItem.separator(),
          const AssistantMenuItem(label: 'Disabled', enabled: false),
        ],
        child: const Text('Model'),
      ),
    ));

    await tester.tap(find.text('Model'));
    await tester.pumpAndSettle();

    expect(find.text('Fast'), findsOneWidget);
    expect(find.text('Answers in a blink'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget,
        reason: 'the selected model is checked');

    await tester.tap(find.text('Thinking'));
    await tester.pumpAndSettle();
    expect(picked, 'thinking');
  });

  testWidgets('attachment card shows a file and removes it', (
    WidgetTester tester,
  ) async {
    int removed = 0;
    await tester.pumpWidget(_app(
      AssistantAttachmentCard(
        attachment: const DocumentAttachment(
          id: 'a1',
          filename: 'notes.txt',
          mimeType: 'text/plain',
        ),
        onRemove: () => removed++,
      ),
    ));

    expect(find.text('notes.txt'), findsOneWidget);
    expect(find.text('text/plain'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(removed, 1);
  });

  testWidgets('message timing renders the recorded duration', (
    WidgetTester tester,
  ) async {
    final LocalRuntime runtime = LocalRuntime(
      adapter: ManualAdapter(),
      initialMessages: <ThreadMessage>[
        _assistantMessage(
          timing: const MessageTiming(
            firstTokenTime: 320,
            totalStreamTime: 2400,
            tokensPerSecond: 42.5,
            totalChunks: 64,
            tokenCount: 96,
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      _app(
        AuiMessage(message: _assistantMessage(), child: const AssistantMessageTiming()),
        runtime: runtime,
      ),
    );

    expect(find.text('2.4s'), findsOneWidget);
  });

  testWidgets('typing indicator draws three dots', (WidgetTester tester) async {
    await tester.pumpWidget(_app(const AssistantTypingIndicator()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(Opacity), findsNWidgets(3));
  });

  testWidgets('markdown renders a pipe table', (WidgetTester tester) async {
    await tester.pumpWidget(_app(
      const AssistantMarkdown(
        text: '| Model | Speed |\n|---|---|\n| Fast | 1.2s |\n| Think | 4.8s |',
      ),
    ));
    await tester.pump();

    expect(find.text('Model'), findsOneWidget);
    expect(find.text('Speed'), findsOneWidget);
    expect(find.text('Fast'), findsOneWidget);
    expect(find.text('1.2s'), findsOneWidget);
    expect(find.text('Think'), findsOneWidget);
  });

  testWidgets('speak is disabled without an adapter and speaks with one', (
    WidgetTester tester,
  ) async {
    final RecordingSpeechAdapter speech = RecordingSpeechAdapter();
    final LocalRuntime runtime = LocalRuntime(
      adapter: ManualAdapter(),
      initialMessages: <ThreadMessage>[_assistantMessage()],
      options: LocalRuntimeOptions(speech: speech),
    );

    await tester.pumpWidget(_app(
      AuiMessage(
        message: _assistantMessage(),
        child: AuiActionBarSpeak(
          builder: (BuildContext context, bool enabled, bool speaking) =>
              Text(enabled ? 'speak' : 'speak-off'),
        ),
      ),
      runtime: runtime,
    ));

    expect(find.text('speak'), findsOneWidget);
    await tester.tap(find.text('speak'));
    await tester.pump();
    await tester.pump();
    expect(speech.speakCalls, 1);
  });

  testWidgets('feedback submits through the adapter', (
    WidgetTester tester,
  ) async {
    final RecordingFeedbackAdapter feedback = RecordingFeedbackAdapter();
    final LocalRuntime runtime = LocalRuntime(
      adapter: ManualAdapter(),
      initialMessages: <ThreadMessage>[_assistantMessage()],
      options: LocalRuntimeOptions(feedback: feedback),
    );

    await tester.pumpWidget(_app(
      AuiMessage(
        message: _assistantMessage(),
        child: AuiActionBarFeedback(
          type: FeedbackType.positive,
          builder: (BuildContext context, bool enabled, bool submitted) =>
              Text(submitted ? 'submitted' : 'rate'),
        ),
      ),
      runtime: runtime,
    ));

    await tester.tap(find.text('rate'));
    await tester.pumpAndSettle();

    expect(feedback.requests, hasLength(1));
    expect(feedback.requests.single.type, FeedbackType.positive);
    expect(find.text('submitted'), findsOneWidget);
  });

  testWidgets('primary action walks the four states', (
    WidgetTester tester,
  ) async {
    final ManualAdapter adapter = ManualAdapter();
    final LocalRuntime runtime = LocalRuntime(adapter: adapter);

    await tester.pumpWidget(_app(const AssistantPrimaryAction(), runtime: runtime));

    // Idle and empty: disabled send.
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    runtime.composer.setText('hi');
    await tester.pump();
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    await runtime.composer.send();
    await tester.pump();
    expect(find.byIcon(Icons.stop), findsOneWidget,
        reason: 'running swaps send for stop');

    runtime.thread.cancelRun();
    await runtime.thread.settled;
    await tester.pump();
    expect(find.byIcon(Icons.stop), findsNothing);
  });
}
