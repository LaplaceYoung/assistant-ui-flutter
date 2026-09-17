import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nodes', () {
    test('reserved keys are partitioned off the props', () {
      final GenerativeUiNode node = GenerativeUiNode.fromJson(<String, Object?>{
        r'$type': 'Button',
        r'$key': 'k1',
        r'$action': 'submit',
        'type': 'submit',
        'label': 'Send',
        'count': 3,
      })!;
      expect(node.type, 'Button');
      expect(node.key, 'k1');
      expect(node.action, 'submit');
      // A component's own `type` prop survives the discriminator.
      expect(node.props['type'], 'submit');
      expect(node.props['label'], 'Send');
      expect(node.props['count'], 3);
      expect(node.props.containsKey(r'$action'), isFalse);
    });

    test('children parse recursively and non-nodes are dropped', () {
      final List<GenerativeUiNode> nodes = parseGenerativeUi(<Object?>[
        <String, Object?>{
          r'$type': 'Card',
          'title': 'Hi',
          'children': <Object?>[
            <String, Object?>{r'$type': 'Text', 'text': 'hello'},
            'not a node',
            null,
            <String, Object?>{
              r'$type': 'Stack',
              'children': <Object?>[
                <String, Object?>{r'$type': 'Text', 'text': 'nested'},
              ],
            },
          ],
        },
      ]);
      expect(nodes.single.type, 'Card');
      expect(nodes.single.children.map((GenerativeUiNode n) => n.type),
          <String>['Text', 'Stack']);
      expect(nodes.single.children[1].children.single.type, 'Text');
    });

    test('the legacy component alias still reads', () {
      final GenerativeUiNode? node = GenerativeUiNode.fromJson(
        <String, Object?>{'component': 'Text', 'text': 'legacy'},
      );
      expect(node!.type, 'Text');
      expect(node.props.containsKey('component'), isFalse);
    });

    test('the depth bound stops a runaway tree', () {
      Object? build(int depth) => depth == 0
          ? <String, Object?>{r'$type': 'Text', 'text': 'deep'}
          : <String, Object?>{
              r'$type': 'Stack',
              'children': <Object?>[build(depth - 1)],
            };
      final List<GenerativeUiNode> nodes = parseGenerativeUi(build(80));
      int depth = 0;
      GenerativeUiNode? cursor = nodes.isEmpty ? null : nodes.single;
      while (cursor != null && cursor.children.isNotEmpty) {
        depth += 1;
        cursor = cursor.children.single;
      }
      expect(depth, lessThanOrEqualTo(generativeUiMaxDepth));
    });

    test('a data part carries the payload', () {
      const DataPart part = DataPart(
        name: generativeUiPartName,
        data: <String, Object?>{r'$type': 'Text', 'text': 'from a part'},
      );
      expect(generativeUiFromPart(part).single.type, 'Text');
      expect(
        generativeUiFromPart(const DataPart(name: 'other', data: null)),
        isEmpty,
      );
    });
  });

  group('jsx serializer', () {
    test('renders attributes, children and keys', () {
      expect(
        generativeUiToJsx(<String, Object?>{
          r'$type': 'Card',
          'title': 'Hi',
          'children': <Object?>[
            <String, Object?>{
              r'$type': 'Text',
              'children': <Object?>['hello'],
            },
          ],
        }),
        '<Card title="Hi"><Text>hello</Text></Card>',
      );
      expect(
        generativeUiToJsx(<String, Object?>{
          r'$type': 'Weather',
          r'$key': 'x',
        }),
        '<Weather key="x" />',
      );
      expect(
        generativeUiToJsx(<String, Object?>{
          r'$type': 'Toggle',
          'open': true,
          'count': 3,
        }),
        '<Toggle open count={3} />',
      );
    });

    test('quotes break out of the plain attribute form', () {
      expect(
        generativeUiToJsx(<String, Object?>{
          r'$type': 'Text',
          'text': 'say "hi"',
        }),
        '<Text text={"say \\"hi\\""} />',
      );
      // A prop is an attribute; only a text child renders between the tags.
      expect(
        generativeUiToJsx(<String, Object?>{
          r'$type': 'Text',
          'text': 'inline',
        }),
        '<Text text="inline" />',
      );
    });

    test('escapes unsafe text children when asked', () {
      expect(
        generativeUiToJsx(
          <String, Object?>{
            r'$type': 'Text',
            'children': <Object?>['a < b'],
          },
          escape: true,
        ),
        '<Text>{a < b}</Text>',
      );
      expect(
        generativeUiToJsx(<String, Object?>{
          r'$type': 'Text',
          'children': <Object?>['plain'],
        }),
        '<Text>plain</Text>',
      );
    });

    test('pretty printing puts element children on their own lines', () {
      final String jsx = generativeUiToJsx(
        <String, Object?>{
          r'$type': 'Card',
          'title': 'Hi',
          'children': <Object?>[
            <String, Object?>{r'$type': 'Text', 'text': 'one'},
            <String, Object?>{r'$type': 'Text', 'text': 'two'},
          ],
        },
        pretty: true,
      );
      expect(jsx, contains('\n  <Text text="one" />'));
      expect(jsx, contains('</Card>'));
    });

    test('non-renderable input serializes to nothing', () {
      expect(generativeUiToJsx(null), '');
      expect(generativeUiToJsx(true), '');
      expect(generativeUiToJsx(<String, Object?>{'text': 'no type'}), '');
      expect(generativeUiToJsx(<String, Object?>{r'$type': 42}), '');
    });
  });

  group('rendering', () {
    testWidgets('the standard vocabulary renders a tree', (
      WidgetTester tester,
    ) async {
      final List<GenerativeUiNode> nodes = parseGenerativeUi(<String, Object?>{
        r'$type': 'Card',
        'title': 'Weather',
        'children': <Object?>[
          <String, Object?>{r'$type': 'Text', 'text': '21C and clear', 'size': 'lg'},
          <String, Object?>{
            r'$type': 'Button',
            'label': 'Refresh',
            r'$action': 'refresh',
          },
        ],
      });
      String? fired;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GenerativeUi(
            node: nodes.single,
            registry: GenerativeUiRegistry.standard(),
            onAction: (String action, GenerativeUiNode node) => fired = action,
          ),
        ),
      ));

      expect(find.text('Weather'), findsOneWidget);
      expect(find.text('21C and clear'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);

      await tester.tap(find.text('Refresh'));
      await tester.pump();
      expect(fired, 'refresh');
    });

    testWidgets('an unregistered component shows its name', (
      WidgetTester tester,
    ) async {
      final List<GenerativeUiNode> nodes = parseGenerativeUi(
        <String, Object?>{r'$type': 'Sparkline', 'points': <Object?>[1, 2]},
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GenerativeUi(
            node: nodes.single,
            registry: const GenerativeUiRegistry(<String, GenerativeUiBuilder>{}),
          ),
        ),
      ));
      expect(find.text('Sparkline'), findsOneWidget);
    });

    testWidgets('a host registry extends the standard vocabulary', (
      WidgetTester tester,
    ) async {
      final GenerativeUiRegistry registry = GenerativeUiRegistry.standard().merge(
        const GenerativeUiRegistry(<String, GenerativeUiBuilder>{
          'Sparkline': _sparkline,
        }),
      );
      final List<GenerativeUiNode> nodes = parseGenerativeUi(
        <String, Object?>{r'$type': 'Sparkline', 'label': 'cpu'},
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GenerativeUi(node: nodes.single, registry: registry),
        ),
      ));
      expect(find.text('sparkline:cpu'), findsOneWidget);
    });

    testWidgets('an action on a button node fires the handler', (
      WidgetTester tester,
    ) async {
      final List<GenerativeUiNode> nodes = parseGenerativeUi(<String, Object?>{
        r'$type': 'Card',
        'title': 'Pick',
        'children': <Object?>[
          <String, Object?>{
            r'$type': 'Text',
            'text': 'Tap the card',
            r'$action': 'card-tap',
          },
        ],
      });
      final List<String> fired = <String>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: GenerativeUi(
            node: nodes.single,
            registry: GenerativeUiRegistry.standard(),
            onAction: (String action, GenerativeUiNode node) => fired.add(action),
          ),
        ),
      ));
      await tester.tap(find.text('Tap the card'));
      await tester.pump();
      expect(fired, <String>['card-tap']);
    });
  });
}

Widget _sparkline(
  BuildContext context,
  GenerativeUiNode node,
  GenerativeUiRenderContext render,
) =>
    Text('sparkline:${node.props['label']}');
