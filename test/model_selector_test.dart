import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

const List<ModelOption> _models = <ModelOption>[
  ModelOption(
    id: 'luna',
    name: 'Luna',
    description: 'balanced',
    keywords: <String>['fast'],
    usesDefaultEfforts: true,
  ),
  ModelOption(id: 'opus', name: 'Opus', description: 'deepest', disabled: true),
  ModelOption(
    id: 'mini',
    name: 'Luna mini',
    efforts: <ModelSelectorEffortOption>[
      ModelSelectorEffortOption(id: 'quick', name: 'Quick'),
    ],
  ),
];

void main() {
  group('model selector', () {
    testWidgets('shows the current model and effort on the trigger', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantModelSelector(
          models: _models,
          defaultValue: 'luna',
          defaultEffort: 'high',
        ),
      ));
      expect(find.text('Luna'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Select model'), findsNothing);
    });

    testWidgets('opens on a tap and picks a model', (
      WidgetTester tester,
    ) async {
      final List<String> picked = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantModelSelector(
          models: _models,
          defaultValue: 'luna',
          onValueChange: picked.add,
        ),
      ));
      expect(find.text('balanced'), findsNothing);

      await tester.tap(find.text('Luna'));
      await tester.pump();
      await tester.pump();
      expect(find.text('balanced'), findsOneWidget);
      expect(find.text('deepest'), findsOneWidget);

      await tester.tap(find.text('Luna mini'));
      await tester.pump();
      expect(picked, <String>['mini']);
    });

    testWidgets('the arrows open the list from the trigger', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantModelSelector(models: _models, defaultValue: 'luna'),
      ));
      // Focusing the trigger is a tap; the arrows then open the listbox.
      // `.first` is the trigger — the list copy only exists while open.
      await tester.tap(find.text('Luna').first);
      await tester.pump();
      await tester.pump();
      await tester.tap(find.text('Luna').first);
      await tester.pump();
      await tester.pump();
      expect(find.text('balanced'), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.pump();
      expect(find.text('balanced'), findsOneWidget);
    });

    testWidgets('the search matches keywords and explains a miss', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantModelSelector(
          models: _models,
          defaultValue: 'luna',
          defaultOpen: true,
        ),
      ));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'fast');
      await tester.pump();
      expect(find.text('Luna'), findsWidgets);
      expect(find.text('Opus'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No models found.'), findsOneWidget);
    });

    testWidgets('a disabled model cannot be picked', (
      WidgetTester tester,
    ) async {
      final List<String> picked = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantModelSelector(
          models: _models,
          defaultValue: 'luna',
          defaultOpen: true,
          onValueChange: picked.add,
        ),
      ));
      await tester.pump();
      await tester.tap(find.text('Opus'));
      await tester.pump();
      expect(picked, isEmpty);
    });

    testWidgets('the effort row only appears for a model that has levels', (
      WidgetTester tester,
    ) async {
      final List<String> efforts = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantModelSelector(
          models: _models,
          defaultValue: 'luna',
          defaultOpen: true,
          onEffortChange: efforts.add,
        ),
      ));
      await tester.pump();
      expect(find.text('Reasoning effort'), findsOneWidget);
      await tester.tap(find.text('Med'));
      await tester.pump();
      expect(efforts, <String>['medium']);

      // A fresh instance, because `defaultValue` only seeds the first build.
      await tester.pumpWidget(_wrap(
        const AssistantModelSelector(
          key: ValueKey<String>('second'),
          models: _models,
          defaultValue: 'mini',
          defaultOpen: true,
        ),
      ));
      await tester.pump();
      // A custom effort list, so the default levels are not offered.
      expect(find.text('Quick'), findsOneWidget);
      expect(find.text('Low'), findsNothing);
    });

    test('effort is sticky but resolves against the model', () {
      final List<ModelOption> models = <ModelOption>[
        const ModelOption(id: 'a', name: 'A', usesDefaultEfforts: true),
        const ModelOption(id: 'b', name: 'B'),
      ];
      expect(auiResolveModelEffort(models, 'a', 'high'), 'high');
      // B has no levels, so the sticky effort does not apply.
      expect(auiResolveModelEffort(models, 'b', 'high'), isNull);
      expect(auiResolveModelEffort(models, 'a', null), isNull);
    });

    testWidgets('the placeholder shows when no model is selected', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantModelSelector(models: <ModelOption>[]),
      ));
      expect(find.text('Select model'), findsOneWidget);
    });
  });
}
