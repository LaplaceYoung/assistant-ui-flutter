import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const List<AssistantMention> _people = <AssistantMention>[
  AssistantMention(id: 'ann', name: 'Ann Lee', description: 'Design'),
  AssistantMention(id: 'bob', name: 'Bob Ray', description: 'Platform'),
  AssistantMention(id: 'ana', name: 'Ana Diaz', description: 'Research'),
];

List<String> _ranCommands = <String>[];

Widget _composerApp(LocalRuntime runtime) => AuiRuntimeProvider(
      runtime: runtime,
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 520,
            child: AuiComposerTriggerRoot(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Push the composer to the bottom, the way a real
                    // composer sits, so the popover has room above it.
                    const Spacer(),
                    const AuiComposerInput(
                      placeholder: 'Type @ to mention, / for commands',
                      maxLines: 3,
                    ),
                    AssistantMentionPopover(people: _people),
                    AssistantSlashCommandMenu(
                      commands: <AssistantSlashCommand>[
                        AssistantSlashCommand(
                          name: 'summarize',
                          label: 'Summarize',
                          description: 'Summarize the thread',
                          icon: Icons.summarize_outlined,
                          onRun: () async => _ranCommands.add('summarize'),
                        ),
                        AssistantSlashCommand(
                          name: 'translate',
                          label: 'Translate',
                          description: 'Translate the last message',
                          icon: Icons.translate,
                          onRun: () async => _ranCommands.add('translate'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  setUp(() => _ranCommands = <String>[]);

  group('trigger adapters', () {
    test('mentions filter by name and insert a directive', () async {
      final AssistantMentionAdapter adapter = AssistantMentionAdapter(_people);
      expect(adapter.triggerChar, '@');

      final List<TriggerItem> all = await adapter.search('');
      expect(all, hasLength(3));

      final List<TriggerItem> filtered = await adapter.search('an');
      expect(filtered.map((TriggerItem i) => i.id), <String>['ann', 'ana']);

      expect(adapter.insertText(all.first), '@[Ann Lee](ann) ');
    });

    test('slash commands match by name and run on select', () async {
      final AssistantSlashCommandAdapter adapter = AssistantSlashCommandAdapter(
        <AssistantSlashCommand>[
          AssistantSlashCommand(
            name: 'summarize',
            label: 'Summarize',
            onRun: () async => _ranCommands.add('summarize'),
          ),
        ],
      );
      expect(adapter.triggerChar, '/');
      expect(adapter.insertText(const TriggerItem(id: 'x', label: 'X')), isNull,
          reason: 'commands consume the token');

      final List<TriggerItem> items = await adapter.search('sum');
      expect(items, hasLength(1));
      await adapter.onSelect(items.single);
      expect(_ranCommands, <String>['summarize']);
    });
  });

  group('mention popover', () {
    testWidgets('opens on @, filters and inserts the directive', (
      WidgetTester tester,
    ) async {
      final LocalRuntime runtime = LocalRuntime(adapter: ManualAdapter());
      await tester.pumpWidget(_composerApp(runtime));
      await tester.pump();

      expect(find.text('Ann Lee'), findsNothing);

      await tester.enterText(find.byType(TextField), '@');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.text('Ann Lee'), findsOneWidget);
      expect(find.text('Bob Ray'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '@an');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.text('Ann Lee'), findsOneWidget);
      expect(find.text('Bob Ray'), findsNothing);

      await tester.tap(find.text('Ann Lee'));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(runtime.state.composer.text, '@[Ann Lee](ann) ');
      expect(find.text('Ann Lee'), findsNothing, reason: 'the popover closes');
    });

    testWidgets('keyboard drives the list and escape closes it', (
      WidgetTester tester,
    ) async {
      final LocalRuntime runtime = LocalRuntime(adapter: ManualAdapter());
      await tester.pumpWidget(_composerApp(runtime));
      await tester.pump();

      await tester.showKeyboard(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '@');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      // Down moves to the second entry, Enter picks it.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(runtime.state.composer.text, '@[Bob Ray](bob) ');

      // Escape closes without inserting.
      await tester.enterText(find.byType(TextField), '@an');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.text('Ann Lee'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.text('Ann Lee'), findsNothing);
      expect(runtime.state.composer.text, '@an');

      // Enter submits again once the popover is closed.
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(runtime.state.thread.messages, hasLength(2));
    });

    testWidgets('an email address does not open the popover', (
      WidgetTester tester,
    ) async {
      final LocalRuntime runtime = LocalRuntime(adapter: ManualAdapter());
      await tester.pumpWidget(_composerApp(runtime));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'mail me at bob@ray.dev');
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Bob Ray'), findsNothing);
    });
  });

  group('slash commands', () {
    testWidgets('run the command and clear the token', (
      WidgetTester tester,
    ) async {
      final LocalRuntime runtime = LocalRuntime(adapter: ManualAdapter());
      await tester.pumpWidget(_composerApp(runtime));
      await tester.pump();

      await tester.enterText(find.byType(TextField), '/sum');
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();
      expect(find.text('Summarize'), findsOneWidget);
      expect(find.text('Translate'), findsNothing);

      await tester.tap(find.text('Summarize'));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump();

      expect(_ranCommands, <String>['summarize']);
      expect(runtime.state.composer.text, '');
    });
  });

  group('directive text', () {
    testWidgets('renders mention directives as chips', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AssistantDirectiveText(
              text: 'Ask @[Ann Lee](ann) about the @[Beta](beta) plan',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('@Ann Lee'), findsOneWidget);
      expect(find.text('@Beta'), findsOneWidget);
      expect(find.textContaining('about the'), findsOneWidget);
    });
  });
}
