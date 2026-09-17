import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('approval card', () {
    testWidgets('offers the three ways out and reports them', (
      WidgetTester tester,
    ) async {
      final List<String> calls = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantApprovalCard(
          state: ApprovalState.request,
          command: 'rm -rf build',
          title: 'Run a command?',
          subtitle: 'write access to the project folder',
          onAllowOnce: () => calls.add('once'),
          onAlwaysAllow: () => calls.add('always'),
          onDeny: () => calls.add('deny'),
        ),
      ));
      expect(find.text('Run a command?'), findsOneWidget);
      expect(find.text('write access to the project folder'), findsOneWidget);
      expect(find.text('rm -rf build'), findsOneWidget);

      await tester.tap(find.text('Allow once'));
      await tester.tap(find.text('Always allow'));
      await tester.tap(find.text('Deny'));
      await tester.pump();
      expect(calls, <String>['once', 'always', 'deny']);
    });

    testWidgets('hides the actions the host does not supply', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        AssistantApprovalCard(
          state: ApprovalState.request,
          command: 'ls',
          title: 'Run?',
          subtitle: 'read only',
          onAllowOnce: () {},
          onDeny: () {},
        ),
      ));
      expect(find.text('Always allow'), findsNothing);
      expect(find.text('Allow once'), findsOneWidget);
      expect(find.text('Deny'), findsOneWidget);
    });

    testWidgets('every settled state reports what happened', (
      WidgetTester tester,
    ) async {
      for (final (ApprovalState state, String label) in <(ApprovalState, String)>[
        (ApprovalState.running, 'Approved, running'),
        (ApprovalState.done, 'Finished with exit 0'),
        (ApprovalState.denied, 'Denied'),
      ]) {
        await tester.pumpWidget(_wrap(
          AssistantApprovalCard(
            state: state,
            command: 'ls',
            title: 'Run?',
            subtitle: 'read only',
            onAllowOnce: () {},
            onDeny: () {},
          ),
        ));
        await tester.pump();
        expect(find.text(label), findsOneWidget, reason: '$state');
        expect(find.text('Allow once'), findsNothing);
        expect(find.text('Deny'), findsNothing);
      }
    });
  });

  group('elicitation form', () {
    List<ElicitationField> fields() => <ElicitationField>[
          const ElicitationField(
            name: 'folder',
            label: 'folder',
            value: '/notes',
            required: true,
          ),
          const ElicitationField(
            name: 'scope',
            label: 'scope',
            value: 'workspace',
            kind: ElicitationFieldKind.choice,
            options: <String>['file', 'workspace'],
          ),
          const ElicitationField(
            name: 'watch',
            label: 'watch',
            value: 'false',
            kind: ElicitationFieldKind.toggle,
          ),
        ];

    testWidgets('renders the request and one control per field kind', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        AssistantElicitationForm(
          server: 'filesystem',
          message: 'Grant access to a folder.',
          fields: fields(),
          state: ElicitationState.request,
          onAccept: () {},
          onDecline: () {},
        ),
      ));
      expect(find.text('filesystem'), findsOneWidget);
      expect(find.text('needs input'), findsOneWidget);
      expect(find.text('Grant access to a folder.'), findsOneWidget);
      expect(find.text('/notes'), findsOneWidget);
      expect(find.text('folder'), findsOneWidget);
      expect(find.text(' *'), findsOneWidget);
      expect(find.text('file'), findsOneWidget);
      expect(find.text('workspace'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      expect(find.text('Send'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    });

    testWidgets('reports answers for the choice and toggle fields', (
      WidgetTester tester,
    ) async {
      final List<String> changes = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantElicitationForm(
          server: 'filesystem',
          message: 'Grant access.',
          fields: fields(),
          state: ElicitationState.request,
          selected: const <String, String>{'scope': 'file'},
          onFieldChanged: (String name, String value) =>
              changes.add('$name=$value'),
          onAccept: () {},
        ),
      ));
      await tester.tap(find.text('workspace'));
      await tester.tap(find.text('Off'));
      await tester.pump();
      expect(changes, <String>['scope=workspace', 'watch=true']);
    });

    testWidgets('a selection from the host wins over the field value', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        AssistantElicitationForm(
          server: 'filesystem',
          message: 'Grant access.',
          fields: fields(),
          state: ElicitationState.request,
          selected: const <String, String>{'scope': 'file', 'watch': 'true'},
          onFieldChanged: (String name, String value) {},
        ),
      ));
      expect(find.text('On'), findsOneWidget);
      final Container chip = tester.widget<Container>(
        find
            .ancestor(
              of: find.text('file'),
              matching: find.byType(Container),
            )
            .first,
      );
      // The selected chip is the ink-filled one.
      expect(chip.decoration, isNotNull);
    });

    testWidgets('fields are display only without a handler', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        AssistantElicitationForm(
          server: 'filesystem',
          message: 'Grant access.',
          fields: fields(),
          state: ElicitationState.request,
        ),
      ));
      // No exception, no state change: tapping a choice does nothing.
      await tester.tap(find.text('workspace'));
      await tester.pump();
      expect(find.text('Off'), findsOneWidget);
    });

    testWidgets('reports acceptance and decline', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        AssistantElicitationForm(
          server: 'filesystem',
          message: 'Grant access.',
          fields: fields(),
          state: ElicitationState.accepted,
        ),
      ));
      expect(find.text('Sent to filesystem'), findsOneWidget);
      expect(find.text('Send'), findsNothing);

      await tester.pumpWidget(_wrap(
        AssistantElicitationForm(
          server: 'filesystem',
          message: 'Grant access.',
          fields: fields(),
          state: ElicitationState.declined,
        ),
      ));
      expect(find.text('Declined'), findsOneWidget);
    });
  });
}
