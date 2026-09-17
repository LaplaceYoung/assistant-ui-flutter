import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('onboarding', () {
    const List<OnboardingStep> steps = <OnboardingStep>[
      OnboardingStep(
        title: 'Ask anything',
        body: 'The thread keeps its context.',
        example: 'Summarize this repo',
      ),
      OnboardingStep(
        title: 'Bring your tools',
        body: 'Tools appear as cards.',
        example: 'Check the weather',
      ),
    ];

    testWidgets('walks the steps and reports next and skip', (
      WidgetTester tester,
    ) async {
      final List<String> calls = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantOnboarding(
          steps: steps,
          index: 0,
          onNext: () => calls.add('next'),
          onSkip: () => calls.add('skip'),
        ),
      ));
      expect(find.text('1 of 2'), findsOneWidget);
      expect(find.text('Ask anything'), findsOneWidget);
      expect(find.text('Summarize this repo'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);

      await tester.tap(find.text('Next'));
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(calls, <String>['next', 'skip']);
    });

    testWidgets('the last step offers Start', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const AssistantOnboarding(steps: steps, index: 1),
      ));
      expect(find.text('2 of 2'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('an out-of-range index clamps to the last step', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantOnboarding(steps: steps, index: 9),
      ));
      expect(find.text('2 of 2'), findsOneWidget);
    });
  });

  group('logos', () {
    test('parses the vendor path data into a shape', () {
      final Path claude = parseAuiSvgPath(AuiBrandLogos.claudePath);
      final Path gemini = parseAuiSvgPath(AuiBrandLogos.geminiPath);
      expect(claude.getBounds().isEmpty, isFalse);
      expect(gemini.getBounds().isEmpty, isFalse);
      // The Claude mark is drawn inside its 256 viewBox.
      expect(claude.getBounds().right, lessThanOrEqualTo(256));
      expect(gemini.getBounds().right, lessThanOrEqualTo(24));
    });

    testWidgets('draws the marks and falls back for the arc-based one', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const Row(
          children: <Widget>[
            AuiLogoMark(mark: AuiBrandMark.claude),
            AuiLogoMark(mark: AuiBrandMark.gemini),
            AuiLogoMark(mark: AuiBrandMark.openai),
          ],
        ),
      ));
      expect(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is CustomPaint && widget.painter is AuiLogoPainter,
        ),
        findsNWidgets(2),
      );
      // The OpenAI mark needs arcs, so it renders as a wordmark instead.
      expect(find.text('OpenAI'), findsOneWidget);
    });
  });

  group('launcher bubble', () {
    testWidgets('opens the panel, counts unread and picks a prompt', (
      WidgetTester tester,
    ) async {
      final List<String> picked = <String>[];
      int toggles = 0;
      int starts = 0;
      await tester.pumpWidget(_wrap(
        AssistantLauncherBubble(
          open: true,
          unread: 3,
          greeting: 'Hi — want a hand?',
          prompts: const <String>['Summarize this page'],
          onToggle: () => toggles++,
          onPick: picked.add,
          onStart: () => starts++,
        ),
      ));
      expect(find.text('Hi — want a hand?'), findsOneWidget);
      expect(find.text('typically replies in a minute'), findsOneWidget);
      // The badge is hidden while the panel is open.
      expect(find.text('3'), findsNothing);

      await tester.tap(find.text('Summarize this page'));
      await tester.tap(find.text('Start a conversation'));
      await tester.tap(find.bySemanticsLabel('Close the assistant'));
      await tester.pump();
      expect(picked, <String>['Summarize this page']);
      expect(starts, 1);
      expect(toggles, 1);
    });

    testWidgets('a closed bubble badges the unread count', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantLauncherBubble(
          unread: 2,
          greeting: 'Hi',
        ),
      ));
      expect(find.text('2'), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
    });
  });

  group('chat panel', () {
    testWidgets('renders the transcript, the typing row and the composer', (
      WidgetTester tester,
    ) async {
      int sends = 0;
      await tester.pumpWidget(_wrap(
        AssistantChatPanel(
          typing: true,
          composerPlaceholder: 'Ask about this page…',
          onSend: () => sends++,
          messages: const <AssistantChatPanelMessage>[
            AssistantChatPanelMessage(
              text: 'What does this page do?',
              fromUser: true,
            ),
            AssistantChatPanelMessage(text: 'It renders a thread.'),
          ],
        ),
      ));
      expect(find.text('What does this page do?'), findsOneWidget);
      expect(find.text('It renders a thread.'), findsOneWidget);
      // A host that sends gets a field to type in, with the placeholder as its
      // hint.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byType(AssistantTypingIndicator), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'ping');
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Send'));
      await tester.pump();
      expect(sends, 1);
    });

    testWidgets('hides the composer when none is configured', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantChatPanel(
          messages: <AssistantChatPanelMessage>[
            AssistantChatPanelMessage(text: 'Only a message'),
          ],
        ),
      ));
      expect(find.bySemanticsLabel('Send'), findsNothing);
    });
  });
}
