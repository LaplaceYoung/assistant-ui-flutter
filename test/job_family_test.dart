import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('task card', () {
    testWidgets('a transcript stays behind the disclosure', (
      WidgetTester tester,
    ) async {
      final List<bool> reports = <bool>[];
      await tester.pumpWidget(_wrap(
        AssistantTaskCard(
          label: 'Patch the parser',
          state: TaskCardState.working,
          meta: 'edit_file',
          elapsed: '8s',
          transcript: const Text('reading lib/parser.dart'),
          onOpenChange: reports.add,
        ),
      ));
      expect(find.text('Patch the parser'), findsOneWidget);
      expect(find.text('edit_file'), findsOneWidget);
      expect(find.text('8s'), findsOneWidget);
      expect(find.text('reading lib/parser.dart'), findsNothing);
      expect(find.byType(AuiSpinner), findsOneWidget);

      await tester.tap(find.text('Patch the parser'));
      await tester.pump();
      expect(reports, <bool>[true]);
      expect(find.text('reading lib/parser.dart'), findsOneWidget);
    });

    testWidgets('without a transcript the header is inert', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantTaskCard(
          label: 'Fetch the issue',
          state: TaskCardState.done,
        ),
      ));
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      await tester.tap(find.text('Fetch the issue'));
      await tester.pump();
      // Nothing to open, nothing to report.
      expect(tester.takeException(), isNull);
    });

    testWidgets('actions and result render in their own blocks', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantTaskCard(
          label: 'Run the suite',
          state: TaskCardState.failed,
          actions: Text('retry / skip'),
          result: Text('2 tests failed'),
        ),
      ));
      expect(find.text('retry / skip'), findsOneWidget);
      expect(find.text('2 tests failed'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('cancelled and waiting states have their own glyphs', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantTaskCard(
          label: 'Index the repo',
          state: TaskCardState.cancelled,
        ),
      ));
      expect(find.byIcon(Icons.block), findsOneWidget);

      await tester.pumpWidget(_wrap(
        const AssistantTaskCard(
          label: 'Wait for approval',
          state: TaskCardState.waiting,
        ),
      ));
      expect(find.byIcon(Icons.block), findsNothing);
      expect(find.byType(AuiSpinner), findsNothing);
    });
  });

  group('job progress', () {
    const List<JobStage> stages = <JobStage>[
      JobStage(name: 'fetch', weight: 1),
      JobStage(name: 'parse', weight: 3),
      JobStage(name: 'write', weight: 1),
    ];

    testWidgets('the bar is weighted by stage size', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantJobProgress(
          title: 'Reindex the workspace',
          stages: stages,
          stageIndex: 1,
          stageProgress: 0.5,
          eta: '~2 min left',
        ),
      ));
      expect(find.text('Reindex the workspace'), findsOneWidget);
      expect(find.text('~2 min left'), findsOneWidget);
      expect(find.text('fetch'), findsOneWidget);
      expect(find.text('write'), findsOneWidget);
      // 1 of 5 weight done plus half of the 3-weight stage = 2.5/5 = 50%.
      expect(find.bySemanticsLabel('Reindex the workspace progress'),
          findsOneWidget);
      expect(find.byType(AuiSpinner), findsOneWidget);
    });

    testWidgets('a finished job says done and offers no cancel', (
      WidgetTester tester,
    ) async {
      int cancels = 0;
      await tester.pumpWidget(_wrap(
        AssistantJobProgress(
          title: 'Reindex the workspace',
          stages: stages,
          stageIndex: 3,
          stageProgress: 1,
          eta: '~0 min left',
          onCancel: () => cancels++,
        ),
      ));
      expect(find.text('done'), findsOneWidget);
      expect(find.text('~0 min left'), findsNothing);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.bySemanticsLabel('Cancel the job'), findsNothing);
      expect(cancels, 0);
    });

    testWidgets('cancel is offered while the job runs', (
      WidgetTester tester,
    ) async {
      int cancels = 0;
      await tester.pumpWidget(_wrap(
        AssistantJobProgress(
          title: 'Reindex the workspace',
          stages: stages,
          stageIndex: 0,
          stageProgress: 0,
          eta: '~5 min left',
          onCancel: () => cancels++,
        ),
      ));
      await tester.tap(find.bySemanticsLabel('Cancel the job'));
      await tester.pump();
      expect(cancels, 1);
    });
  });

  group('schedule card', () {
    testWidgets('shows the cadence, the next run and the history', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantScheduleCard(
          name: 'nightly reindex',
          cadence: 'every weekday at 02:00',
          nextRun: 'Fri 02:00',
          enabled: true,
          history: <ScheduleRun>[
            ScheduleRun(id: 'r1', at: 'Thu 02:00', ok: true),
            ScheduleRun(id: 'r2', at: 'Wed 02:00', ok: false),
          ],
        ),
      ));
      expect(find.text('nightly reindex'), findsOneWidget);
      expect(find.text('every weekday at 02:00'), findsOneWidget);
      expect(find.text('Fri 02:00'), findsOneWidget);
      expect(find.text('recent runs'), findsOneWidget);
      expect(find.text('ok'), findsOneWidget);
      expect(find.text('failed'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('a paused schedule says so and can be resumed', (
      WidgetTester tester,
    ) async {
      int toggles = 0;
      await tester.pumpWidget(_wrap(
        AssistantScheduleCard(
          name: 'nightly reindex',
          cadence: 'daily at 02:00',
          nextRun: 'Fri 02:00',
          enabled: false,
          onToggle: () => toggles++,
        ),
      ));
      expect(find.text('paused'), findsOneWidget);
      expect(find.text('Fri 02:00'), findsNothing);
      await tester.tap(find.bySemanticsLabel('Resume nightly reindex'));
      await tester.pump();
      expect(toggles, 1);
    });
  });

  group('checkpoint history', () {
    const List<Checkpoint> checkpoints = <Checkpoint>[
      Checkpoint(id: 'c1', label: 'before the patch', at: '09:12', files: 3),
      Checkpoint(id: 'c2', label: 'after the patch', at: '09:18', files: 4),
      Checkpoint(id: 'c3', label: 'draft', at: '09:24', files: 5),
    ];

    testWidgets('marks the live checkpoint and restores another', (
      WidgetTester tester,
    ) async {
      final List<String> restored = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantCheckpointHistory(
          checkpoints: checkpoints,
          currentId: 'c2',
          onRestore: restored.add,
        ),
      ));
      expect(find.text('Checkpoints'), findsOneWidget);
      expect(find.text('before the patch'), findsOneWidget);
      expect(find.text('09:12 · 3 files'), findsOneWidget);
      expect(find.text('current'), findsOneWidget);
    });

    testWidgets('a checkpoint ahead of the current one stays inert', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantCheckpointHistory(
          checkpoints: checkpoints,
          currentId: 'c1',
        ),
      ));
      // Without a restore callback there are no controls at all.
      expect(find.text('Restore'), findsNothing);
      expect(find.text('current'), findsOneWidget);
    });
  });

  group('memory chips', () {
    testWidgets('counts what was newly remembered and forgets on demand', (
      WidgetTester tester,
    ) async {
      final List<String> forgotten = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantMemoryChips(
          chips: const <MemoryChip>[
            MemoryChip(
              id: 'm1',
              text: 'prefers tabs over spaces',
              change: MemoryChange.added,
            ),
            MemoryChip(
              id: 'm2',
              text: 'ships on Fridays',
              change: MemoryChange.updated,
            ),
            MemoryChip(
              id: 'm3',
              text: 'flutter 3.47',
              change: MemoryChange.existing,
            ),
          ],
          onForget: forgotten.add,
        ),
      ));
      expect(find.text('remembered 2'), findsOneWidget);
      expect(find.text('prefers tabs over spaces'), findsOneWidget);
      await tester.tap(
        find.bySemanticsLabel('Forget "ships on Fridays"'),
      );
      await tester.pump();
      expect(forgotten, <String>['m2']);
    });

    testWidgets('nothing fresh reads as plain memory, read only', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantMemoryChips(
          chips: <MemoryChip>[
            MemoryChip(
              id: 'm1',
              text: 'flutter 3.47',
              change: MemoryChange.existing,
            ),
          ],
        ),
      ));
      expect(find.text('memory'), findsOneWidget);
      expect(find.bySemanticsLabel('Forget "flutter 3.47"'), findsNothing);
    });
  });

  group('background inbox', () {
    testWidgets('counts ready runs and collects them', (
      WidgetTester tester,
    ) async {
      final List<String> collected = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantBackgroundInbox(
          runs: const <BackgroundRun>[
            BackgroundRun(
              id: 'r1',
              title: 'Reindex the workspace',
              state: BackgroundState.running,
              elapsed: '2m',
            ),
            BackgroundRun(
              id: 'r2',
              title: 'Summarize the docs',
              state: BackgroundState.ready,
              elapsed: '1m',
              summary: '18 pages',
            ),
            BackgroundRun(
              id: 'r3',
              title: 'Fetch the release notes',
              state: BackgroundState.failed,
              elapsed: '30s',
            ),
          ],
          onCollect: collected.add,
        ),
      ));
      expect(find.text('Running elsewhere'), findsOneWidget);
      expect(find.text('1 ready'), findsOneWidget);
      expect(find.text('18 pages'), findsOneWidget);

      await tester.tap(find.text('Summarize the docs'));
      await tester.pump();
      expect(collected, <String>['r2']);

      // A running row does not collect.
      await tester.tap(find.text('Reindex the workspace'));
      await tester.pump();
      expect(collected, <String>['r2']);
    });

    testWidgets('with nothing ready it reports what is in flight', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantBackgroundInbox(
          runs: <BackgroundRun>[
            BackgroundRun(
              id: 'r1',
              title: 'Reindex the workspace',
              state: BackgroundState.running,
              elapsed: '2m',
            ),
          ],
        ),
      ));
      expect(find.text('1 in flight'), findsOneWidget);
    });
  });
}
