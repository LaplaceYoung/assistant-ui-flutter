import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('guardrail notice', () {
    testWidgets('names the policy and offers alternatives', (
      WidgetTester tester,
    ) async {
      final List<String> picked = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantGuardrailNotice(
          title: 'That request was blocked',
          explanation: 'The policy forbids writing exploit code.',
          policy: 'safety.malware',
          alternatives: const <String>['Explain the vulnerability'],
          onPick: picked.add,
        ),
      ));
      expect(find.text('That request was blocked'), findsOneWidget);
      expect(find.text('safety.malware'), findsOneWidget);
      expect(find.text('try instead'), findsOneWidget);

      await tester.tap(find.text('Explain the vulnerability'));
      await tester.pump();
      expect(picked, <String>['Explain the vulnerability']);
    });

    testWidgets('without alternatives there is nothing to try', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantGuardrailNotice(
          title: 'Blocked',
          explanation: 'No.',
          policy: 'safety.x',
        ),
      ));
      expect(find.text('try instead'), findsNothing);
    });
  });

  group('quote reply', () {
    testWidgets('marks the selection, runs an action and shows the quote', (
      WidgetTester tester,
    ) async {
      final List<String> actions = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantQuoteReply(
          before: 'The rule is ',
          selection: 'never block the UI',
          after: ' in this app.',
          quoted: 'The rule is never block the UI in this app.',
          toolbarVisible: true,
          onAction: actions.add,
          actions: const <QuoteAction>[
            QuoteAction(
              key: 'quote',
              label: 'Quote',
              icon: Icons.format_quote,
            ),
            QuoteAction(
              key: 'explain',
              label: 'Explain',
              icon: Icons.auto_awesome,
            ),
          ],
        ),
      ));
      // The sentence and the quoted reply both carry the phrase.
      expect(find.textContaining('never block the UI'), findsNWidgets(2));
      expect(find.text('replying to'), findsOneWidget);

      await tester.tap(find.text('Explain'));
      await tester.pump();
      expect(actions, <String>['explain']);
    });

    testWidgets('the toolbar stays hidden without a handler', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantQuoteReply(
          before: 'a ',
          selection: 'b',
          after: ' c',
          toolbarVisible: true,
          actions: <QuoteAction>[
            QuoteAction(key: 'quote', label: 'Quote', icon: Icons.format_quote),
          ],
        ),
      ));
      expect(find.text('Quote'), findsNothing);
    });
  });

  group('permission grant', () {
    testWidgets('offers the three scopes while pending', (
      WidgetTester tester,
    ) async {
      final List<GrantScope> granted = <GrantScope>[];
      await tester.pumpWidget(_wrap(
        AssistantPermissionGrant(
          capability: 'Read your calendar',
          requester: 'calendar-mcp',
          reach: const <String>['today and the next 7 days'],
          onGrant: granted.add,
        ),
      ));
      expect(find.text('Read your calendar'), findsOneWidget);
      expect(find.text('requested by calendar-mcp'), findsOneWidget);
      expect(find.text('this grants'), findsOneWidget);

      await tester.tap(find.text('This session'));
      await tester.tap(find.text('Always'));
      await tester.tap(find.text('Deny'));
      await tester.pump();
      expect(granted, <GrantScope>[
        GrantScope.session,
        GrantScope.always,
        GrantScope.denied,
      ]);
    });

    testWidgets('a settled request reports its scope and hides the buttons', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantPermissionGrant(
          capability: 'Read your calendar',
          requester: 'calendar-mcp',
          scope: GrantScope.always,
        ),
      ));
      expect(find.text('granted · always'), findsOneWidget);
      expect(find.text('Always'), findsNothing);

      await tester.pumpWidget(_wrap(
        const AssistantPermissionGrant(
          capability: 'Read your calendar',
          requester: 'calendar-mcp',
          scope: GrantScope.denied,
        ),
      ));
      expect(find.text('denied'), findsOneWidget);
    });
  });

  group('feedback dialog', () {
    testWidgets('toggles reasons, edits the note and sends', (
      WidgetTester tester,
    ) async {
      final List<String> toggled = <String>[];
      final List<String> notes = <String>[];
      int sends = 0;
      await tester.pumpWidget(_wrap(
        AssistantFeedbackDialog(
          reasons: const <String>['Wrong facts', 'Too long'],
          selected: const <String>['Too long'],
          onToggleReason: toggled.add,
          onNoteChange: notes.add,
          onSubmit: () => sends++,
        ),
      ));
      expect(find.text('What went wrong?'), findsOneWidget);

      await tester.tap(find.text('Wrong facts'));
      await tester.pump();
      expect(toggled, <String>['Wrong facts']);

      await tester.enterText(find.byType(TextField), 'missed the date');
      await tester.pump();
      expect(notes, <String>['missed the date']);

      await tester.tap(find.text('Send feedback'));
      await tester.pump();
      expect(sends, 1);
    });

    testWidgets('a sent dialog thanks the reader', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const AssistantFeedbackDialog(sent: true),
      ));
      expect(
        find.text('Thanks. That helps us tune the model.'),
        findsOneWidget,
      );
      expect(find.text('What went wrong?'), findsNothing);
    });
  });

  group('code diff', () {
    testWidgets('marks the lines and the counts', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const AssistantCodeDiff(
          filename: 'lib/parser.dart',
          additions: 2,
          deletions: 1,
          lines: <DiffLine>[
            DiffLine(kind: DiffKind.context, text: 'final a = 1;'),
            DiffLine(kind: DiffKind.removed, text: 'final b = 2;'),
            DiffLine(kind: DiffKind.added, text: 'final b = 3;'),
            DiffLine(kind: DiffKind.added, text: 'final c = 4;'),
          ],
        ),
      ));
      expect(find.text('lib/parser.dart'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
      expect(find.text('−1'), findsOneWidget);
      expect(find.text('−'), findsOneWidget);
      expect(find.text('+'), findsNWidgets(2));
      expect(find.text('final b = 3;'), findsOneWidget);
    });
  });

  group('terminal block', () {
    testWidgets('streams output and reports the exit', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantTerminalBlock(
          command: 'flutter test',
          lines: <String>['00:01 +1 loading', '00:02 +40', 'All tests passed!'],
          visibleCount: 2,
        ),
      ));
      expect(find.text('flutter test'), findsOneWidget);
      expect(find.text('00:02 +40'), findsOneWidget);
      expect(find.text('All tests passed!'), findsNothing);
      expect(find.byType(AuiSpinner), findsOneWidget);

      await tester.pumpWidget(_wrap(
        const AssistantTerminalBlock(
          command: 'flutter test',
          lines: <String>['All tests passed!'],
          visibleCount: 1,
          done: true,
        ),
      ));
      expect(find.text('exit 0'), findsOneWidget);
      expect(find.byType(AuiSpinner), findsNothing);
    });
  });

  group('code runner', () {
    testWidgets('runs on demand and shows the output', (
      WidgetTester tester,
    ) async {
      int runs = 0;
      await tester.pumpWidget(_wrap(
        AssistantCodeRunner(
          language: 'dart',
          code: 'void main() {}',
          state: RunState.idle,
          onRun: () => runs++,
        ),
      ));
      expect(find.text('dart'), findsOneWidget);
      expect(find.text('output'), findsNothing);

      await tester.tap(find.bySemanticsLabel('Run this snippet'));
      await tester.pump();
      expect(runs, 1);

      await tester.pumpWidget(_wrap(
        const AssistantCodeRunner(
          language: 'dart',
          code: 'void main() {}',
          state: RunState.ok,
          durationMs: 240,
          output: <String>['hello'],
        ),
      ));
      expect(find.text('240ms'), findsOneWidget);
      expect(find.text('output'), findsOneWidget);
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('a failed run paints its output red', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantCodeRunner(
          language: 'python',
          code: 'raise SystemExit(1)',
          state: RunState.error,
          output: <String>['Traceback (most recent call last)'],
        ),
      ));
      final Text line = tester.widget<Text>(
        find.text('Traceback (most recent call last)'),
      );
      expect(line.style!.color, isNotNull);
      expect(find.byType(AuiSpinner), findsNothing);
    });
  });

  group('quote', () {
    testWidgets('shows the quoted text, the action and the dismiss', (
      WidgetTester tester,
    ) async {
      final List<String> calls = <String>[];
      await tester.pumpWidget(_wrap(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const AssistantQuoteBlock(text: 'never block the UI'),
            AssistantSelectionToolbar(onQuote: () => calls.add('quote')),
            AssistantComposerQuotePreview(
              text: 'never block the UI',
              onDismiss: () => calls.add('dismiss'),
            ),
          ],
        ),
      ));
      expect(find.text('never block the UI'), findsNWidgets(2));
      await tester.tap(find.text('Quote'));
      await tester.tap(find.bySemanticsLabel('Dismiss quote'));
      await tester.pump();
      expect(calls, <String>['quote', 'dismiss']);
    });
  });

  group('reviewable diff', () {
    const List<DiffHunk> hunks = <DiffHunk>[
      DiffHunk(
        id: 'h1',
        range: '@@ -1,2 +1,2 @@',
        decision: HunkDecision.kept,
        lines: <DiffLine>[
          DiffLine(kind: DiffKind.context, text: 'final a = 1;'),
          DiffLine(kind: DiffKind.added, text: 'final b = 2;'),
        ],
      ),
      DiffHunk(
        id: 'h2',
        range: '@@ -8,2 +8,2 @@',
        lines: <DiffLine>[
          DiffLine(kind: DiffKind.removed, text: 'final c = 3;'),
        ],
      ),
    ];

    testWidgets('keeps a hunk and blocks apply until all are reviewed', (
      WidgetTester tester,
    ) async {
      final List<String> kept = <String>[];
      int applies = 0;
      await tester.pumpWidget(_wrap(
        AssistantReviewableDiff(
          filename: 'lib/parser.dart',
          hunks: hunks,
          onKeep: kept.add,
          onDiscard: (String id) {},
          onApply: () => applies++,
        ),
      ));
      expect(find.text('1 of 2 kept'), findsOneWidget);
      expect(find.text('1 left to review'), findsOneWidget);

      await tester.tap(find.text('Keep'));
      await tester.pump();
      expect(kept, <String>['h2']);

      // Still pending, so applying reports nothing.
      await tester.tap(find.text('Apply 1'));
      await tester.pump();
      expect(applies, 0);

      await tester.pumpWidget(_wrap(
        AssistantReviewableDiff(
          filename: 'lib/parser.dart',
          hunks: <DiffHunk>[
            hunks.first,
            DiffHunk(
              id: 'h2',
              range: hunks.last.range,
              decision: HunkDecision.discarded,
              lines: hunks.last.lines,
            ),
          ],
          onApply: () => applies++,
        ),
      ));
      expect(find.text('All reviewed'), findsOneWidget);
      await tester.tap(find.text('Apply 1'));
      await tester.pump();
      expect(applies, 1);
    });
  });

  group('model picker', () {
    testWidgets('groups the families and marks the current model', (
      WidgetTester tester,
    ) async {
      final List<String> picked = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantModelPicker(
          selectedId: 'luna',
          onSelect: picked.add,
          models: const <PickableModel>[
            PickableModel(
              id: 'luna',
              name: 'Luna',
              family: 'OpenAI',
              context: '128k',
              price: r'$0.31/M',
              capabilities: <String>['tools', 'vision'],
            ),
            PickableModel(
              id: 'opus',
              name: 'Opus',
              family: 'Anthropic',
              context: '200k',
              price: r'$0.90/M',
            ),
          ],
        ),
      ));
      expect(find.text('OpenAI'), findsOneWidget);
      expect(find.text('Anthropic'), findsOneWidget);
      expect(find.text('tools'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.text('Opus'));
      await tester.pump();
      expect(picked, <String>['opus']);
    });
  });

  group('mobile composer', () {
    testWidgets('sends, stops and reports the quick actions', (
      WidgetTester tester,
    ) async {
      final List<String> calls = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantMobileComposer(
          value: 'Hello',
          actions: const <String>['Summarize'],
          onAction: calls.add,
          onAttach: () => calls.add('attach'),
          onSend: () => calls.add('send'),
        ),
      ));
      expect(find.text('Summarize'), findsOneWidget);
      await tester.tap(find.text('Summarize'));
      await tester.tap(find.bySemanticsLabel('Add an attachment'));
      await tester.tap(find.bySemanticsLabel('Send'));
      await tester.pump();
      expect(calls, <String>['Summarize', 'attach', 'send']);
    });

    testWidgets('while running the control stops and actions give way', (
      WidgetTester tester,
    ) async {
      final List<String> calls = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantMobileComposer(
          running: true,
          keyboardOpen: true,
          value: 'streaming',
          actions: const <String>['Summarize'],
          onStop: () => calls.add('stop'),
        ),
      ));
      expect(find.text('Summarize'), findsNothing);
      expect(find.text('return to send'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Stop'));
      await tester.pump();
      expect(calls, <String>['stop']);
    });

    testWidgets('an empty field cannot send', (WidgetTester tester) async {
      final List<String> calls = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantMobileComposer(
          onSend: () => calls.add('send'),
        ),
      ));
      await tester.tap(find.bySemanticsLabel('Send'));
      await tester.pump();
      expect(calls, isEmpty);
    });
  });

  group('message attachments', () {
    testWidgets('renders image and document rows and opens them', (
      WidgetTester tester,
    ) async {
      final List<String> opened = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantMessageAttachmentList(
          onOpen: opened.add,
          attachments: const <MessageAttachmentItem>[
            MessageAttachmentItem(
              id: 'a1',
              name: 'screenshot.png',
              size: '240 KB',
              kind: AttachmentKind.image,
            ),
            MessageAttachmentItem(
              id: 'a2',
              name: 'q3-report.pdf',
              size: '1.2 MB',
              kind: AttachmentKind.document,
              pages: 24,
            ),
            MessageAttachmentItem(
              id: 'a3',
              name: 'notes.txt',
              size: '2 KB',
            ),
          ],
        ),
      ));
      expect(find.text('screenshot.png'), findsOneWidget);
      expect(find.text('q3-report.pdf'), findsOneWidget);
      expect(find.text('1.2 MB · 24 pages'), findsOneWidget);
      expect(find.text('notes.txt'), findsOneWidget);
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);

      await tester.tap(find.text('q3-report.pdf'));
      await tester.pump();
      expect(opened, <String>['a2']);
    });

    testWidgets('the runtime wrapper renders through the same list', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantMessageAttachments(
          attachments: <AuiAttachment>[
            DocumentAttachment(
              id: 'd1',
              filename: 'brief.pdf',
              mimeType: 'application/pdf',
            ),
          ],
        ),
      ));
      expect(find.text('brief.pdf'), findsOneWidget);
      expect(find.text('application/pdf'), findsOneWidget);
    });
  });
}
