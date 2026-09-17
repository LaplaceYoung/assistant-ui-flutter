import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Widget _app(LocalRuntime runtime, Widget child) => AuiRuntimeProvider(
      runtime: runtime,
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  group('drafts', () {
    test('unsent text survives a thread switch', () async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);
      final String a = runtime.state.threads.mainThreadId;

      await runtime.thread.send(content: <MessagePart>[const TextPart('first')]);
      await adapter.respondWith(<String>['ok']);
      await runtime.thread.settled;

      runtime.composer.setText('half-written draft');
      final String b = await runtime.threads.create();
      expect(runtime.state.composer.text, '', reason: 'a new thread starts clean');

      await runtime.threads.switchToThread(a);
      expect(runtime.state.composer.text, 'half-written draft');

      await runtime.threads.switchToThread(b);
      expect(runtime.state.composer.text, '');
    });
  });

  group('message queue', () {
    test('a turn typed during a run is queued and then sent', () async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);

      await runtime.thread.send(content: <MessagePart>[const TextPart('run one')]);
      expect(runtime.state.thread.isRunning, isTrue);

      runtime.composer.setText('queued while busy');
      await runtime.composer.send();

      expect(runtime.state.composer.queue, hasLength(1));
      expect(runtime.state.composer.queue.single.text, 'queued while busy');
      expect(runtime.state.composer.text, '', reason: 'the composer clears');
      expect(runtime.state.thread.messages, hasLength(2),
          reason: 'the queued turn waits for the current run');

      await adapter.respondWith(<String>['answer one']);
      // The queue drains on its own: a second run starts.
      await waitUntil(() => adapter.runs.length == 2,
          reason: 'the queued turn starts a new run');
      expect(runtime.state.composer.queue, isEmpty);

      await adapter.respondWith(<String>['answer two']);
      await runtime.thread.settled;

      expect(runtime.state.thread.messages, hasLength(4));
      expect(runtime.state.thread.messages[2].text, 'queued while busy');
      expect(runtime.state.thread.messages.last.text, 'answer two');
    });

    testWidgets('queue chips render and can be removed', (
      WidgetTester tester,
    ) async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);

      await runtime.thread.send(content: <MessagePart>[const TextPart('busy')]);
      runtime.composer.setText('second thought');
      await runtime.composer.send();
      runtime.composer.setText('third thought');
      await runtime.composer.send();
      expect(runtime.state.composer.queue, hasLength(2));

      await tester.pumpWidget(_app(runtime, const AssistantMessageQueue()));
      await tester.pump();

      expect(find.text('QUEUED'), findsOneWidget);
      expect(find.text('second thought'), findsOneWidget);
      expect(find.text('third thought'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pump();
      expect(runtime.state.composer.queue, hasLength(1));
      expect(find.text('second thought'), findsNothing);

      runtime.composer.clearQueued();
      await tester.pump();
      expect(find.text('QUEUED'), findsNothing);
    });
  });

  group('context usage', () {
    test('thread state reports usage against the window', () async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(
        adapter: adapter,
        options: const LocalRuntimeOptions(contextWindowTokens: 1000),
      );

      await runtime.thread.send(
        content: <MessagePart>[TextPart('x' * 400)],
      );
      final ContextUsage usage = runtime.state.thread.contextUsage;
      expect(usage.maxTokens, 1000);
      expect(usage.usedTokens, greaterThan(90));
      expect(usage.ratio, lessThan(0.5));

      await adapter.respondWith(<String>['ok']);
      await runtime.thread.settled;
    });

    test('usage is hidden when the window is unknown', () {
      final LocalRuntime runtime = LocalRuntime(
        adapter: ManualAdapter(),
        options: const LocalRuntimeOptions(contextWindowTokens: 0),
      );
      expect(runtime.state.thread.contextUsage.maxTokens, 0);
      expect(runtime.state.thread.contextUsage.ratio, 0);
    });

    testWidgets('the ring renders and hides without a window', (
      WidgetTester tester,
    ) async {
      final LocalRuntime runtime = LocalRuntime(
        adapter: ManualAdapter(),
        options: const LocalRuntimeOptions(contextWindowTokens: 1000),
      );
      await runtime.thread.send(content: <MessagePart>[const TextPart('hello')]);

      await tester.pumpWidget(_app(runtime, const AssistantContextRing(showLabel: true)));
      await tester.pump();
      expect(find.byType(CustomPaint), findsWidgets);

      final LocalRuntime hidden = LocalRuntime(
        adapter: ManualAdapter(),
        options: const LocalRuntimeOptions(contextWindowTokens: 0),
      );
      await tester.pumpWidget(_app(hidden, const AssistantContextRing()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CustomPaint), findsWidgets,
          reason: 'other painters exist; the ring is simply not drawn');
    });
  });

  group('voice', () {
    testWidgets('the mic starts a session, transcripts land in the composer', (
      WidgetTester tester,
    ) async {
      final FakeDictationAdapter dictation = FakeDictationAdapter();
      final LocalRuntime runtime = LocalRuntime(
        adapter: ManualAdapter(),
        options: LocalRuntimeOptions(dictation: dictation),
      );

      await tester.pumpWidget(_app(runtime, const AssistantComposerVoice()));
      await tester.pump();

      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pump();
      await tester.pump();

      expect(runtime.state.composer.dictation, isNotNull);
      expect(find.byIcon(Icons.stop), findsOneWidget,
          reason: 'listening swaps the mic for a stop control');

      dictation.emit('hello from speech');
      await tester.pump();
      expect(runtime.state.composer.text, 'hello from speech');

      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();
      await tester.pump();
      expect(dictation.stopped, isTrue);
      expect(runtime.state.composer.dictation, isNull);
      expect(runtime.state.composer.text, 'hello from speech');
    });

    testWidgets('the mic is disabled without a dictation adapter', (
      WidgetTester tester,
    ) async {
      final LocalRuntime runtime = LocalRuntime(adapter: ManualAdapter());
      await tester.pumpWidget(_app(runtime, const AssistantComposerVoice()));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.mic_none));
      await tester.pump();
      expect(runtime.state.composer.dictation, isNull);
    });
  });
}
