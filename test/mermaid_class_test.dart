import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The class-diagram engine: boxes with their members, and the arrows with the
/// meaning their symbols carry.
void main() {
  test('a class diagram reads classes, members and relations', () {
    final MermaidClassDiagram? diagram = MermaidClassDiagram.parse(
      'classDiagram\n'
      '    class Animal {\n'
      '        +String name\n'
      '        +move() void\n'
      '    }\n'
      '    class Dog\n'
      '    Animal <|-- Dog : inherits\n'
      '    Dog --> Collar : wears\n'
      '    Dog *-- Tail\n'
      '    Kennel o-- Dog\n'
      '    Dog ..> Vet\n',
    );
    expect(diagram, isNotNull);
    expect(
      diagram!.classes.map((MermaidClass k) => k.name),
      containsAll(<String>['Animal', 'Dog', 'Collar', 'Tail', 'Kennel', 'Vet']),
    );
    final MermaidClass animal =
        diagram.classes.firstWhere((MermaidClass k) => k.name == 'Animal');
    expect(animal.members, <String>['+String name', '+move() void']);

    MermaidRelation relation(String from, String to) => diagram.relations
        .firstWhere((MermaidRelation r) => r.from == from && r.to == to);
    expect(relation('Animal', 'Dog').kind, MermaidRelationKind.inheritance);
    expect(relation('Animal', 'Dog').label, 'inherits');
    expect(relation('Dog', 'Collar').kind, MermaidRelationKind.association);
    expect(relation('Dog', 'Tail').kind, MermaidRelationKind.composition);
    expect(relation('Kennel', 'Dog').kind, MermaidRelationKind.aggregation);
    expect(relation('Dog', 'Vet').kind, MermaidRelationKind.dependency);
  });

  test('a class diagram with unreadable lines falls back', () {
    expect(MermaidClassDiagram.parse('graph TD\n  A --> B'), isNull);
    expect(MermaidClassDiagram.parse('classDiagram\n  this is not a line'), isNull);
  });

  testWidgets('the diagram draws a class diagram end to end', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssistantMermaidDiagram(
            zoomable: false,
            code: 'classDiagram\n  class A {\n    +int n\n  }\n  A <|-- B',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AssistantMermaidClassDiagram), findsOneWidget);
    expect(find.text('diagram could not be rendered'), findsNothing);
  });
}
