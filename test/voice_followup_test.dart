import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('follow-up suggestions', () {
    testWidgets('sends the prompt of the chip that was tapped', (
      WidgetTester tester,
    ) async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);
      // The row waits for a settled run, as upstream's condition does.
      await runtime.thread.send(content: <MessagePart>[const TextPart('go')]);
      await adapter.finish();
      runtime.thread.setSuggestions(const <ThreadSuggestion>[
        ThreadSuggestion(prompt: 'Explain the parser'),
        ThreadSuggestion(
          prompt: 'Show the diff',
          title: 'Diff',
          label: '⌘D',
        ),
      ]);

      await tester.pumpWidget(
        AuiRuntimeProvider(
          runtime: runtime,
          child: _wrap(const AssistantFollowUpSuggestions()),
        ),
      );
      await tester.pump();
      expect(find.text('Explain the parser'), findsOneWidget);
      expect(find.text('Diff'), findsOneWidget);
      expect(find.text('⌘D'), findsOneWidget);

      await tester.tap(find.text('Explain the parser'));
      await tester.pump();
      // The tap starts a second run with that prompt.
      expect(adapter.runs, hasLength(2));
      expect(
        runtime.state.thread.messages.first.content.first,
        isA<TextPart>(),
      );
    });

    testWidgets('renders nothing while a run is in flight', (
      WidgetTester tester,
    ) async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);
      runtime.thread.setSuggestions(
        const <ThreadSuggestion>[ThreadSuggestion(prompt: 'More')],
      );
      await runtime.thread.send(content: <MessagePart>[const TextPart('go')]);

      await tester.pumpWidget(
        AuiRuntimeProvider(
          runtime: runtime,
          child: _wrap(const AssistantFollowUpSuggestions()),
        ),
      );
      await tester.pump();
      expect(find.text('More'), findsNothing);

      await adapter.finish();
      await tester.pump();
      await tester.pump();
      expect(find.text('More'), findsOneWidget);
    });

    testWidgets('clearing the suggestions hides the row', (
      WidgetTester tester,
    ) async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);
      runtime.thread.setSuggestions(
        const <ThreadSuggestion>[ThreadSuggestion(prompt: 'More')],
      );
      await runtime.thread.send(content: <MessagePart>[const TextPart('go')]);
      await adapter.finish();
      await tester.pump();

      await tester.pumpWidget(
        AuiRuntimeProvider(
          runtime: runtime,
          child: _wrap(const AssistantFollowUpSuggestions()),
        ),
      );
      await tester.pump();
      expect(find.text('More'), findsOneWidget);

      runtime.thread.setSuggestions(const <ThreadSuggestion>[]);
      await tester.pump();
      expect(find.text('More'), findsNothing);
    });
  });

  group('voice conversation', () {
    const List<VoiceTurn> transcript = <VoiceTurn>[
      VoiceTurn(id: 'v1', role: 'user', text: 'Draft the notes'),
      VoiceTurn(id: 'v2', role: 'assistant', text: 'On it.'),
    ];

    testWidgets('names the mode and reports the controls', (
      WidgetTester tester,
    ) async {
      final List<String> calls = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantVoiceConversation(
          mode: VoiceMode.speaking,
          amplitude: 0.6,
          transcript: transcript,
          onInterrupt: () => calls.add('interrupt'),
          onToggleMute: () => calls.add('mute'),
          onEnd: () => calls.add('end'),
        ),
      ));
      expect(find.text('Speaking'), findsOneWidget);
      expect(find.text('Tap to interrupt'), findsOneWidget);
      expect(find.text('you'), findsOneWidget);
      expect(find.text('ai'), findsOneWidget);
      expect(find.text('On it.'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Interrupt the assistant'));
      await tester.tap(find.bySemanticsLabel('Turn the microphone off'));
      await tester.tap(find.bySemanticsLabel('End the call'));
      await tester.pump();
      expect(calls, <String>['interrupt', 'mute', 'end']);
    });

    testWidgets('a muted session says so', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const AssistantVoiceConversation(
          mode: VoiceMode.listening,
          muted: true,
        ),
      ));
      expect(find.text('Listening'), findsOneWidget);
      expect(find.text('Mic off'), findsOneWidget);
      expect(find.byIcon(Icons.mic_off), findsOneWidget);
    });

    testWidgets('each phase has its own hint', (WidgetTester tester) async {
      for (final (VoiceMode mode, String hint) in <(VoiceMode, String)>[
        (VoiceMode.connecting, 'Opening the mic'),
        (VoiceMode.listening, 'Listening for you'),
        (VoiceMode.thinking, 'Working on it'),
        (VoiceMode.speaking, 'Playing the reply'),
      ]) {
        await tester.pumpWidget(_wrap(
          AssistantVoiceConversation(mode: mode),
        ));
        await tester.pump();
        expect(find.text(hint), findsOneWidget, reason: '$mode');
      }
    });
  });
}
