import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('trace waterfall', () {
    testWidgets('renders each visible span with its duration', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantTraceWaterfall(
          totalMs: 1200,
          visibleCount: 3,
          spans: <TraceSpan>[
            TraceSpan(
              id: 'a',
              name: 'plan',
              depth: 0,
              startMs: 0,
              durationMs: 120,
              status: SpanStatus.completed,
            ),
            TraceSpan(
              id: 'b',
              name: 'retrieve',
              depth: 1,
              startMs: 120,
              durationMs: 480,
              status: SpanStatus.running,
            ),
            TraceSpan(
              id: 'c',
              name: 'write',
              depth: 1,
              startMs: 600,
              durationMs: 200,
              status: SpanStatus.failed,
            ),
            TraceSpan(
              id: 'd',
              name: 'hidden',
              depth: 0,
              startMs: 800,
              durationMs: 100,
              status: SpanStatus.completed,
            ),
          ],
        ),
      ));
      expect(find.text('Trace'), findsOneWidget);
      expect(find.text('1200ms'), findsOneWidget);
      expect(find.text('plan'), findsOneWidget);
      expect(find.text('retrieve'), findsOneWidget);
      expect(find.text('write'), findsOneWidget);
      expect(find.text('d'), findsNothing);
      expect(find.text('120'), findsOneWidget);
      expect(find.text('480'), findsOneWidget);
    });

    testWidgets('a zero timeline does not divide by zero', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantTraceWaterfall(
          totalMs: 0,
          visibleCount: 1,
          spans: <TraceSpan>[
            TraceSpan(
              id: 'a',
              name: 'plan',
              depth: 0,
              startMs: 0,
              durationMs: 0,
              status: SpanStatus.completed,
            ),
          ],
        ),
      ));
      expect(find.text('0ms'), findsOneWidget);
      expect(find.text('plan'), findsOneWidget);
    });
  });

  group('cost meter', () {
    testWidgets('shows the run, the session and each model line', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantCostMeter(
          runCost: r'$0.0042',
          sessionCost: r'$0.31',
          lines: <CostLine>[
            CostLine(
              model: 'gpt-5.6-luna',
              inputTokens: 1250,
              outputTokens: 340,
              cost: r'$0.0031',
              share: 0.74,
            ),
            CostLine(
              model: 'claude-opus-4.7',
              inputTokens: 800,
              outputTokens: 120,
              cost: r'$0.0011',
              share: 0.26,
            ),
          ],
        ),
      ));
      expect(find.text(r'$0.0042'), findsOneWidget);
      expect(find.text('this run'), findsOneWidget);
      expect(find.text(r'$0.31 session'), findsOneWidget);
      expect(find.text('gpt-5.6-luna'), findsOneWidget);
      // Tokens render in thousands with one decimal.
      expect(find.text('1.3k in · 0.3k out'), findsOneWidget);
      expect(find.text(r'$0.0011'), findsOneWidget);
      // The share bar carries the split for screen readers.
      expect(
        find.bySemanticsLabel('gpt-5.6-luna cost share'),
        findsOneWidget,
      );
    });

    testWidgets('a share of zero leaves the track empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantCostMeter(
          runCost: r'$0',
          sessionCost: r'$0',
          lines: <CostLine>[
            CostLine(
              model: 'gpt-5.6-luna',
              inputTokens: 0,
              outputTokens: 0,
              cost: r'$0',
              share: 0,
            ),
          ],
        ),
      ));
      expect(find.text('gpt-5.6-luna'), findsOneWidget);
      expect(find.text('0.0k in · 0.0k out'), findsOneWidget);
    });
  });

  group('context breakdown', () {
    testWidgets('lists the segments, the headroom and the pressure', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantContextBreakdown(
          limit: 128000,
          segments: <ContextSegment>[
            ContextSegment(
              label: 'System',
              tokens: 1200,
              tint: Color(0xFF888888),
            ),
            ContextSegment(
              label: 'Messages',
              tokens: 14800,
              tint: Color(0xFF3B82F6),
            ),
          ],
        ),
      ));
      expect(find.text('Context'), findsOneWidget);
      // Thousands separators, like the upstream `toLocaleString`.
      expect(find.text('16,000 / 128,000'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('1,200'), findsOneWidget);
      expect(find.text('14,800'), findsOneWidget);
      expect(find.text('Headroom'), findsOneWidget);
      expect(find.text('112,000'), findsOneWidget);
    });

    testWidgets('an unknown limit renders without pressure', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantContextBreakdown(
          limit: 0,
          segments: <ContextSegment>[
            ContextSegment(
              label: 'Messages',
              tokens: 900,
              tint: Color(0xFF3B82F6),
            ),
          ],
        ),
      ));
      expect(find.text('900 / 0'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });
  });

  group('activity and heat graphs', () {
    List<AuiHeatCell> week() {
      final DateTime start = DateTime.utc(2026, 9, 1);
      return <AuiHeatCell>[
        for (int day = 0; day < 21; day++)
          AuiHeatCell(
            date: start.add(Duration(days: day)),
            count: day % 5,
          ),
      ];
    }

    testWidgets('the activity graph labels its range and total', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        AssistantActivityGraph(
          data: week(),
          start: DateTime.utc(2026, 9, 1),
          end: DateTime.utc(2026, 9, 21),
          title: 'Runs this quarter',
          total: '412 runs',
        ),
      ));
      expect(find.text('Runs this quarter'), findsOneWidget);
      expect(find.text('412 runs'), findsOneWidget);
      expect(find.text('less'), findsOneWidget);
      expect(find.text('more'), findsOneWidget);
      // Day labels alternate, as upstream does.
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Mon'), findsNothing);
    });

    testWidgets('the heat graph adds month labels and tooltips', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        AssistantHeatGraph(
          data: week(),
          start: DateTime.utc(2026, 9, 1),
          end: DateTime.utc(2026, 9, 21),
        ),
      ));
      expect(find.byType(Tooltip), findsWidgets);
      expect(find.text('less'), findsOneWidget);
      final Tooltip tip = tester.widget<Tooltip>(find.byType(Tooltip).first);
      expect(tip.message, contains('contributions on'));
    });
  });

  group('confidence marker', () {
    testWidgets('underlines each claim and reports the hovered one', (
      WidgetTester tester,
    ) async {
      final List<String> hovered = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantConfidenceMarker(
          hoveredId: 'b',
          claims: const <ConfidenceClaim>[
            ConfidenceClaim(
              id: 'a',
              text: 'Revenue grew 12%',
              confidence: Confidence.grounded,
              basis: 'q3 report',
            ),
            ConfidenceClaim(
              id: 'b',
              text: 'Churn is flattening',
              confidence: Confidence.inferred,
              basis: 'from the last four weeks',
            ),
          ],
          onHover: hovered.add,
        ),
      ));
      expect(find.text('Revenue grew 12%'), findsOneWidget);
      expect(find.text('Churn is flattening'), findsOneWidget);
      // The hovered claim shows its basis pill.
      expect(find.text('inferred · from the last four weeks'), findsOneWidget);

      final TestGesture gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(find.text('Revenue grew 12%')));
      await tester.pump();
      expect(hovered.last, 'a');
      await gesture.removePointer();
    });

    testWidgets('no pill without a hovered claim', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantConfidenceMarker(
          claims: <ConfidenceClaim>[
            ConfidenceClaim(
              id: 'a',
              text: 'Revenue grew 12%',
              confidence: Confidence.grounded,
              basis: 'q3 report',
            ),
          ],
        ),
      ));
      expect(find.textContaining('from a source'), findsNothing);
    });
  });

  group('score breakdown', () {
    testWidgets('shows the verdict band, weights and notes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantScoreBreakdown(
          verdict: 'Strong',
          total: 82.5,
          outOf: 100,
          visibleCount: 2,
          criteria: <ScoreCriterion>[
            ScoreCriterion(
              label: 'Correctness',
              score: 45,
              weight: 50,
              note: 'All checks pass.',
            ),
            ScoreCriterion(label: 'Style', score: 37.5, weight: 50),
            ScoreCriterion(label: 'Hidden', score: 0, weight: 0),
          ],
        ),
      ));
      expect(find.text('82.5'), findsOneWidget);
      expect(find.text('/ 100'), findsOneWidget);
      expect(find.text('Strong'), findsOneWidget);
      expect(find.text('Correctness'), findsOneWidget);
      expect(find.text('×50'), findsNWidgets(2));
      expect(find.text('45.0'), findsOneWidget);
      expect(find.text('All checks pass.'), findsOneWidget);
      expect(find.text('Hidden'), findsNothing);
    });

    testWidgets('a weak ratio still renders a verdict', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantScoreBreakdown(
          verdict: 'Needs work',
          total: 30,
          outOf: 100,
          visibleCount: 1,
          criteria: <ScoreCriterion>[
            ScoreCriterion(label: 'Correctness', score: 20, weight: 100),
          ],
        ),
      ));
      expect(find.text('30.0'), findsOneWidget);
      expect(find.text('Needs work'), findsOneWidget);
    });
  });
}
