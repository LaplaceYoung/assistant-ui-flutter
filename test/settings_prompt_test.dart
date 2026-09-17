import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('settings panel', () {
    testWidgets('drives model, prompt, temperature and the switches', (
      WidgetTester tester,
    ) async {
      final List<String> models = <String>[];
      final List<double> temps = <double>[];
      final List<String> toggles = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantSettingsPanel(
          model: 'luna',
          models: const <String>['luna', 'opus'],
          systemPrompt: 'Be terse.',
          temperature: 0.7,
          onModelChange: models.add,
          onTemperatureChange: temps.add,
          onToggle: toggles.add,
          toggles: const <SettingToggle>[
            SettingToggle(
              key: 'tools',
              label: 'Tool calls',
              detail: 'let the model call tools',
              on: true,
            ),
          ],
        ),
      ));
      expect(find.text('0.7'), findsOneWidget);
      expect(find.text('Tool calls'), findsOneWidget);

      await tester.tap(find.text('opus'));
      await tester.pump();
      expect(models, <String>['opus']);

      await tester.drag(find.byType(Slider), const Offset(60, 0));
      await tester.pump();
      expect(temps, isNotEmpty);

      // The label is on both the row text and the switch, so target the switch.
      await tester.tap(
        find.descendant(
          of: find.byType(AssistantSettingsPanel),
          matching: find.byWidgetPredicate(
            (Widget widget) =>
                widget is Semantics && widget.properties.toggled != null,
          ),
        ),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(toggles, <String>['tools']);
    });

    testWidgets('an out-of-range temperature is clamped in the readout', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantSettingsPanel(
          model: 'luna',
          models: <String>['luna'],
          systemPrompt: '',
          temperature: 5,
        ),
      ));
      expect(find.text('2.0'), findsOneWidget);
    });
  });

  group('prompt library', () {
    const List<SavedPrompt> prompts = <SavedPrompt>[
      SavedPrompt(
        id: 'p1',
        name: 'Release notes',
        body: 'Draft notes for {version}.',
        variables: <String>['version'],
      ),
      SavedPrompt(id: 'p2', name: 'Bug triage', body: 'Sort these.'),
    ];

    testWidgets('filters, previews and reports selection', (
      WidgetTester tester,
    ) async {
      final List<String> selected = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantPromptLibrary(
          prompts: prompts,
          selectedId: 'p1',
          onSelect: selected.add,
        ),
      ));
      expect(find.text('Release notes'), findsOneWidget);
      expect(find.text('Draft notes for {version}.'), findsOneWidget);
      expect(find.text('{version}'), findsOneWidget);
      expect(find.text('1 vars'), findsOneWidget);

      await tester.tap(find.text('Bug triage'));
      await tester.pump();
      expect(selected, <String>['p2']);
    });

    testWidgets('explains an empty result set', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const AssistantPromptLibrary(prompts: prompts, query: 'zzz'),
      ));
      expect(find.text('Nothing matches “zzz”'), findsOneWidget);
    });

    testWidgets('enter inserts the selected prompt', (
      WidgetTester tester,
    ) async {
      final List<String> inserted = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantPromptLibrary(
          prompts: prompts,
          selectedId: 'p1',
          onInsert: inserted.add,
        ),
      ));
      await tester.enterText(find.byType(TextField), 'Release');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(inserted, <String>['p1']);
    });
  });
}
