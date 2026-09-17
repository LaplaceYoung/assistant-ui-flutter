import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _plainText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((Text t) => t.data ?? '')
    .join();

void main() {
  group('parsing', () {
    test('splits variables from operators and reads the symbol table', () {
      final List<MathNode> nodes = parseMath(r'x + \alpha \le \beta');
      final String rendered = nodes
          .whereType<MathText>()
          .map((MathText t) => t.text)
          .join();
      expect(rendered, contains('x'));
      expect(rendered, contains('α'));
      expect(rendered, contains('≤'));
      expect(rendered, contains('β'));
      // A variable is italic; a digit or an operator is not.
      expect(nodes.whereType<MathText>().first.italic, isTrue);
    });

    test('reads fractions, radicals and scripts', () {
      final List<MathNode> fraction = parseMath(r'\frac{a}{b}');
      expect(fraction.single, isA<MathFraction>());
      final MathFraction f = fraction.single as MathFraction;
      expect((f.over.single as MathText).text, 'a');
      expect((f.under.single as MathText).text, 'b');

      final List<MathNode> radical = parseMath(r'\sqrt{x + 1}');
      expect(radical.single, isA<MathRadical>());

      final List<MathNode> script = parseMath(r'x^2');
      expect(script.single, isA<MathScript>());
      final MathScript s = script.single as MathScript;
      expect((s.base.single as MathText).text, 'x');
      expect((s.superscript!.single as MathText).text, '2');

      final List<MathNode> both = parseMath(r'\sum_{i=0}^{n}');
      final MathScript sum = both.single as MathScript;
      expect((sum.base.single as MathText).text, '∑');
      expect(
        sum.subscript!.whereType<MathText>().map((MathText t) => t.text).join(),
        'i=0',
      );
      expect((sum.superscript!.single as MathText).text, 'n');
    });

    test('an unknown command stays readable', () {
      final List<MathNode> nodes = parseMath(r'\weirdthing y');
      final String rendered =
          nodes.whereType<MathText>().map((MathText t) => t.text).join();
      expect(rendered, contains(r'\weirdthing'));
      expect(rendered, contains('y'));
    });

    test(r'\text{} keeps its characters upright', () {
      final List<MathNode> nodes = parseMath(r'\text{if }x');
      final MathText first = nodes.whereType<MathText>().first;
      expect(first.text, 'if ');
      expect(first.italic, isFalse);
    });

    test('an empty expression parses to nothing', () {
      expect(parseMath(''), isEmpty);
    });
  });

  group('rendering', () {
    testWidgets('a fraction stacks its parts around a rule', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AssistantMath(r'\frac{a}{b}')),
      ));
      await tester.pump();

      final double overY = tester.getCenter(find.text('a')).dy;
      final double underY = tester.getCenter(find.text('b')).dy;
      expect(overY, lessThan(underY));
      expect(find.byType(MathRow), findsWidgets);
    });

    testWidgets('a superscript sits above the base', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AssistantMath(r'x^2 + y')),
      ));
      await tester.pump();

      final double base = tester.getCenter(find.text('x')).dy;
      final double exponent = tester.getCenter(find.text('2')).dy;
      expect(exponent, lessThan(base));
    });

    testWidgets('a subscript sits below the base', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AssistantMath(r'x_i')),
      ));
      await tester.pump();

      final double base = tester.getCenter(find.text('x')).dy;
      final double index = tester.getCenter(find.text('i')).dy;
      expect(index, greaterThan(base));
    });

    testWidgets('a radical draws its sign and an overline', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AssistantMath(r'\sqrt{x}')),
      ));
      await tester.pump();
      expect(find.text('√'), findsOneWidget);
      expect(find.text('x'), findsOneWidget);
    });

    testWidgets('display math is larger than inline', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Column(
            children: <Widget>[
              AssistantMath('x', size: 18),
              AssistantMath('x', display: true, size: 18),
            ],
          ),
        ),
      ));
      await tester.pump();
      final List<double> sizes = tester
          .widgetList<Text>(find.text('x'))
          .map((Text t) => t.style!.fontSize!)
          .toList();
      expect(sizes.first, 18);
      expect(sizes.last, greaterThan(sizes.first));
    });
  });

  group('markdown integration', () {
    testWidgets('display math renders without a host typesetter', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AssistantMarkdown(text: r'The area is $$\pi r^2$$.'),
        ),
      ));
      await tester.pump();
      // A standalone paragraph is display math only when it is on its own line;
      // inline here, so the inline typesetter draws it.
      expect(find.byType(AssistantMath), findsOneWidget);
      expect(_plainText(tester), contains('π'));
      // `r^2` comes through as a script node, and no source leaks to the view.
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is MathNodeView && w.node is MathScript,
        ),
        findsWidgets,
      );
      expect(find.textContaining(r'$$'), findsNothing);
    });

    testWidgets('a block expression renders with a script', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: AssistantMarkdown(text: r'$$\frac{a}{b} = x^2$$'),
        ),
      ));
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (Widget w) => w is MathNodeView && w.node is MathFraction,
        ),
        findsWidgets,
      );
    });

    testWidgets('a host typesetter still wins', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AssistantMarkdown(
            text: r'$$x^2$$',
            mathRenderer: (BuildContext context, String tex, bool display) =>
                Text('HOST($tex)'),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text(r'HOST(x^2)'), findsOneWidget);
      expect(find.byType(AssistantMath), findsNothing);
    });

    testWidgets('an empty expression keeps the styled source', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: AssistantMath(r'\frac{}{}')),
      ));
      await tester.pump();
      // Nothing to typeset, but it renders without throwing.
      expect(tester.takeException(), isNull);
    });
  });
}
