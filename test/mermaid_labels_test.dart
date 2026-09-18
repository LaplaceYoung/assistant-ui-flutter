import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mermaid writes a node's shape in its syntax and its label inside it. The
/// label is what a reader sees, so the markers must not survive into it — the
/// live diagram reads `adapter`, never `[adapter]`.
void main() {
  test('node labels lose their shape markers', () {
    final MermaidFlowchart? chart = MermaidFlowchart.parse(
      'graph TD\n'
      '  A[adapter] --> B{tools?}\n'
      '  B --> C([thread])\n'
      '  C --> D((start))\n'
      '  D --> E[[store]]\n'
      '  E --> F(round)\n',
    );
    expect(chart, isNotNull);
    final Map<String, String> labels = <String, String>{
      for (final MermaidNode node in chart!.nodes) node.id: node.label,
    };
    expect(labels['A'], 'adapter');
    expect(labels['B'], 'tools?');
    expect(labels['C'], 'thread');
    expect(labels['D'], 'start');
    expect(labels['E'], 'store');
    expect(labels['F'], 'round');

    // The shapes still follow the syntax.
    MermaidNode node(String id) =>
        chart.nodes.firstWhere((MermaidNode n) => n.id == id);
    expect(node('B').shape, MermaidShape.decision);
    expect(node('C').shape, MermaidShape.stadium);
    expect(node('A').shape, MermaidShape.box);
    expect(node('F').shape, MermaidShape.rounded);
  });

  test('an edge label keeps its pipes out of the label', () {
    final MermaidFlowchart? chart =
        MermaidFlowchart.parse('graph LR\n  A -->|yes| B\n');
    expect(chart!.edges.single.label, 'yes');
  });
}
