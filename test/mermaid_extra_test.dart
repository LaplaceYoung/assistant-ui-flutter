import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two diagram types the built-in renderer grew: a pie and a sequence.
/// Until now both fell through to the source view.
void main() {
  test('a pie parses its slices, title and showData', () {
    final MermaidPie? pie = MermaidPie.parse('''
pie showData title Traffic sources
    "Direct" : 42
    "Search" : 31
    "Referral" : 27
''');
    expect(pie, isNotNull);
    expect(pie!.title, 'Traffic sources');
    expect(pie.showData, isTrue);
    expect(pie.segments.length, 3);
    expect(pie.segments.first.label, 'Direct');
    expect(pie.total, 100);
  });

  test('a pie without readable slices falls back', () {
    expect(MermaidPie.parse('graph TD\n  A --> B'), isNull);
    expect(MermaidPie.parse('pie\n  just words'), isNull);
  });

  test('a sequence reads participants, arrows and notes', () {
    final MermaidSequence? sequence = MermaidSequence.parse('''
sequenceDiagram
    participant U as User
    actor S as Server
    U->>S: GET /threads
    S-->>U: 200 OK
    Note over U,S: cached for a minute
    U-)S: fire and forget
''');
    expect(sequence, isNotNull);
    expect(sequence!.participants, <String>['User', 'Server']);
    expect(sequence.messages.length, 4);
    expect(sequence.messages[0].text, 'GET /threads');
    expect(sequence.messages[1].dashed, isTrue);
    expect(sequence.messages[2].note, isTrue);
    expect(sequence.messages[3].open, isTrue);
  });

  test('a sequence with control blocks still reads its messages', () {
    final MermaidSequence? sequence = MermaidSequence.parse('''
sequenceDiagram
    A->>B: hello
    loop every minute
        B->>A: ping
    end
''');
    expect(sequence, isNotNull);
    expect(sequence!.messages.length, 2);
  });

  test('anything else falls back', () {
    expect(MermaidSequence.parse('graph LR\n  A --> B'), isNull);
    expect(MermaidSequence.parse('sequenceDiagram\n  nonsense line'), isNull);
  });

  testWidgets('the diagram draws a pie and a sequence without falling back', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssistantMermaidDiagram(
            code: 'pie title Split\n  "A" : 60\n  "B" : 40',
            zoomable: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AssistantMermaidPie), findsOneWidget);
    expect(find.text('diagram could not be rendered'), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssistantMermaidDiagram(
            code: 'sequenceDiagram\n  U->>S: ping\n  S-->>U: pong',
            zoomable: false,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AssistantMermaidSequence), findsOneWidget);
    expect(find.text('diagram could not be rendered'), findsNothing);
  });
}
