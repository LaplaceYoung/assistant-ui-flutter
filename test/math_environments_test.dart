import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The environments the typesetter grew: the grids a chat answer actually
/// emits — a matrix, a bracketed one, `cases`, an `aligned` derivation — plus
/// the TeX spacing and dots commands that go with them.
void main() {
  Future<void> pump(WidgetTester tester, String tex) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: AssistantMath(tex, display: true)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('a matrix lays out its rows and cells', (WidgetTester tester) async {
    await pump(tester, r'\begin{matrix} a & b \\ c & d \end{matrix}');
    for (final String glyph in <String>['a', 'b', 'c', 'd']) {
      expect(find.text(glyph), findsOneWidget);
    }
  });

  testWidgets('a pmatrix and a bmatrix draw their delimiters', (
    WidgetTester tester,
  ) async {
    await pump(tester, r'\begin{pmatrix} 1 & 2 \\ 3 & 4 \end{pmatrix}');
    expect(find.text('('), findsOneWidget);
    expect(find.text(')'), findsOneWidget);

    await pump(tester, r'\begin{bmatrix} 1 & 2 \end{bmatrix}');
    expect(find.text('['), findsOneWidget);
    expect(find.text(']'), findsOneWidget);
  });

  testWidgets('cases draws one brace and keeps the conditions', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      r'|x| = \begin{cases} x & x \ge 0 \\ -x & x < 0 \end{cases}',
    );
    expect(find.text('{'), findsOneWidget);
    expect(find.text(')'), findsNothing);
    // The condition cells are typeset, not swallowed.
    expect(find.textContaining('≥'), findsOneWidget);
    expect(find.textContaining('<'), findsWidgets);
  });

  testWidgets('aligned stacks the derivation without delimiters', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      r'\begin{aligned} S &= \pi r^2 \\ &= 3.14 \cdot 4 \end{aligned}',
    );
    expect(find.text('('), findsNothing);
    expect(find.text('['), findsNothing);
    expect(find.textContaining('π'), findsOneWidget);
    expect(find.textContaining('·'), findsOneWidget);
  });

  testWidgets('an unknown environment keeps its source', (WidgetTester tester) async {
    // Kept short: display math lays out on one line, so a long block would
    // overflow the row the same way a long expression always does.
    await pump(tester, r'\begin{chem} H2O \end{chem}');
    expect(find.textContaining('chem'), findsOneWidget);
    expect(find.textContaining('H2O'), findsOneWidget);
  });

  testWidgets('an accent rides on the last glyph', (WidgetTester tester) async {
    await pump(tester, r'\hat{x} + \vec{v}');
    // The combining marks are there, over the letters they belong to.
    expect(find.textContaining('\u0302'), findsOneWidget);
    expect(find.textContaining('\u20D7'), findsOneWidget);
  });

  testWidgets('the alphabets render, and other letters are left alone', (
    WidgetTester tester,
  ) async {
    await pump(tester, r'\mathbb{R}^n');
    expect(find.textContaining('\u211D'), findsOneWidget);

    await pump(tester, r'\mathbf{F} = m\mathbf{a}');
    expect(find.textContaining('F'), findsWidgets);
  });

  testWidgets('the spacing and dots commands exist', (WidgetTester tester) async {
    await pump(tester, r'a \quad b \cdots c');
    expect(find.textContaining('\u2003'), findsWidgets);
    expect(find.textContaining('\u22ef'), findsOneWidget);
  });
}
