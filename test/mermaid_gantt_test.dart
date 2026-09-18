import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The gantt engine: sections, dated and undated tasks, durations, and the
/// dispatch that draws it instead of the source.
void main() {
  test('a gantt reads sections, dates, durations and the cursor', () {
    final MermaidGantt? gantt = MermaidGantt.parse(
      'gantt\n'
      '    title Shipping plan\n'
      '    dateFormat YYYY-MM-DD\n'
      '    section Design\n'
      '    Spec :done, 2026-01-01, 5d\n'
      '    Review :2026-01-06, 3d\n'
      '    section Build\n'
      '    Port :a1, 2w\n',
    );
    expect(gantt, isNotNull);
    expect(gantt!.title, 'Shipping plan');
    expect(gantt.sections.length, 2);
    expect(gantt.sections.first.name, 'Design');
    expect(gantt.sections.first.tasks.length, 2);

    // Dates and durations resolve to spans.
    final MermaidGanttTask spec = gantt.sections.first.tasks.first;
    expect(spec.start, DateTime(2026, 1, 1));
    expect(spec.end, DateTime(2026, 1, 6));
    expect(spec.days, 5);

    // An undated task follows the cursor, and `2w` is fourteen days.
    final MermaidGanttTask port = gantt.sections.last.tasks.single;
    expect(port.start, DateTime(2026, 1, 9));
    expect(port.days, 14);

    expect(gantt.start, DateTime(2026, 1, 1));
    expect(gantt.end, DateTime(2026, 1, 23));
  });

  test('a gantt without tasks or with unreadable rows falls back', () {
    expect(MermaidGantt.parse('graph TD\n  A --> B'), isNull);
    expect(MermaidGantt.parse('gantt\n    section Empty'), isNull);
    expect(MermaidGantt.parse('gantt\n    A task without a colon'), isNull);
  });

  testWidgets('the diagram draws a gantt end to end', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssistantMermaidDiagram(
            zoomable: false,
            code: 'gantt\n  title Plan\n  section One\n  Task :2026-01-01, 4d',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AssistantMermaidGantt), findsOneWidget);
    expect(find.text('diagram could not be rendered'), findsNothing);
  });
}
