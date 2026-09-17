import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('reasoning panel', () {
    testWidgets('streams steps behind the trigger', (
      WidgetTester tester,
    ) async {
      final List<bool> reports = <bool>[];
      await tester.pumpWidget(_wrap(
        AssistantReasoningPanel(
          visibleSteps: 1,
          restingLabel: 'Thought for 12s',
          streaming: true,
          elapsed: '4s',
          onOpenChange: reports.add,
          steps: const <ReasoningStep>[
            ReasoningStep(title: 'Read the test', body: 'parser_test fails'),
            ReasoningStep(title: 'Patch', body: 'not shown yet'),
          ],
        ),
      ));
      expect(find.text('Thinking'), findsOneWidget);
      expect(find.text('4s'), findsOneWidget);
      expect(find.text('Read the test'), findsNothing);

      await tester.tap(find.text('Thinking'));
      await tester.pump();
      expect(reports, <bool>[true]);
      expect(find.text('Read the test'), findsOneWidget);
      expect(find.text('parser_test fails'), findsOneWidget);
      expect(find.text('Patch'), findsNothing);
    });

    testWidgets('a settled panel shows the resting label', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantReasoningPanel(
          visibleSteps: 1,
          restingLabel: 'Thought for 12s',
          initiallyOpen: true,
          steps: <ReasoningStep>[
            ReasoningStep(title: 'Read the test', body: 'parser_test fails'),
          ],
        ),
      ));
      expect(find.text('Thought for 12s'), findsOneWidget);
      expect(find.text('Thinking'), findsNothing);
      expect(find.text('Read the test'), findsOneWidget);
    });
  });

  group('reasoning effort', () {
    testWidgets('shows the budget and reports a level change', (
      WidgetTester tester,
    ) async {
      final List<String> picked = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantReasoningEffort(
          spent: 2400,
          selectedKey: 'medium',
          onSelect: picked.add,
          levels: const <EffortLevel>[
            EffortLevel(key: 'low', label: 'Low', budget: 1000),
            EffortLevel(key: 'medium', label: 'Medium', budget: 8000),
            EffortLevel(key: 'high', label: 'High', budget: 32000),
          ],
        ),
      ));
      expect(find.text('Thinking'), findsOneWidget);
      expect(find.text('2,400 / 8,000'), findsOneWidget);
      await tester.tap(find.text('High'));
      await tester.pump();
      expect(picked, <String>['high']);
    });
  });

  group('read aloud', () {
    testWidgets('tracks the spoken word and the transport', (
      WidgetTester tester,
    ) async {
      final List<String> calls = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantReadAloud(
          words: const <String>['Optimistic', 'updates', 'keep', 'it', 'snappy'],
          spokenIndex: 2,
          elapsed: '0:04',
          duration: '0:12',
          playing: true,
          rate: 1.5,
          onToggle: () => calls.add('toggle'),
          onRateChange: () => calls.add('rate'),
        ),
      ));
      expect(find.text('0:04 / 0:12'), findsOneWidget);
      expect(find.text('1.5×'), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Pause'));
      await tester.tap(
        find.bySemanticsLabel(
          RegExp('^Playback speed, currently 1.5 times'),
        ),
      );
      await tester.pump();
      expect(calls, <String>['toggle', 'rate']);
      expect(find.bySemanticsLabel('Read aloud progress'), findsOneWidget);
    });
  });

  group('quota banner', () {
    testWidgets('reports what is left and offers the upgrade', (
      WidgetTester tester,
    ) async {
      int upgrades = 0;
      await tester.pumpWidget(_wrap(
        AssistantQuotaBanner(
          used: 950,
          limit: 1000,
          unit: 'messages',
          resetsIn: '3h 12m',
          upgradeLabel: 'Upgrade',
          onUpgrade: () => upgrades++,
        ),
      ));
      expect(find.text('50 messages left'), findsOneWidget);
      expect(find.text('resets in 3h 12m'), findsOneWidget);
      expect(find.text('950 of 1000 used'), findsOneWidget);
      await tester.tap(find.text('Upgrade'));
      await tester.pump();
      expect(upgrades, 1);
    });

    testWidgets('an exhausted quota floors at zero left', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantQuotaBanner(
          used: 1200,
          limit: 1000,
          unit: 'messages',
          resetsIn: '1h',
          upgradeLabel: 'Upgrade',
        ),
      ));
      expect(find.text('0 messages left'), findsOneWidget);
    });
  });
}
