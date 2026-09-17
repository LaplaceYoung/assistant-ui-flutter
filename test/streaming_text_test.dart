import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Upstream's streaming text: the words that just arrived are tinted, and they
/// settle into the body colour once the run moves on.
void main() {
  const Color fresh = Color(0xFF3B82F6);

  Future<void> pump(WidgetTester tester, String text, {required bool streaming}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssistantStreamingMarkdown(text: text, streaming: streaming),
        ),
      ),
    );
  }

  /// The colours of every glyph run on screen, nested spans included.
  List<Color?> colours(WidgetTester tester) {
    final List<Color?> found = <Color?>[];
    void walk(InlineSpan span) {
      if (span is TextSpan) {
        if (span.text != null && span.text!.isNotEmpty) {
          found.add(span.style?.color);
        }
        for (final InlineSpan child in span.children ?? const <InlineSpan>[]) {
          walk(child);
        }
      }
    }

    for (final Text widget in tester.widgetList<Text>(find.byType(Text))) {
      final InlineSpan? span = widget.textSpan;
      if (span != null) walk(span);
    }
    return found;
  }

  testWidgets('the tail is drawn in the tint, the rest in ink', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssistantMarkdown(
            text: 'The thread settles',
            freshFrom: 11,
            freshColor: fresh,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(colours(tester), contains(fresh));
    expect(find.textContaining('settles', findRichText: true), findsOneWidget);
  });

  testWidgets('a streaming part opts into the treatment, a settled one does not', (
    WidgetTester tester,
  ) async {
    bool streamingFlag() => tester
        .widgetList<AssistantStreamingMarkdown>(
          find.byType(AssistantStreamingMarkdown),
        )
        .any((AssistantStreamingMarkdown w) => w.streaming);

    await pump(tester, 'The thread settles', streaming: true);
    await tester.pump();
    expect(streamingFlag(), isTrue);

    await pump(tester, 'The thread settles', streaming: false);
    await tester.pump();
    expect(streamingFlag(), isFalse);
  });
}
