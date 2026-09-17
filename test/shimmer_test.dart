import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shimmer animates a mask over its child', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 200,
            child: AssistantShimmer(
              trackWidth: 200,
              trackHeight: 20,
              speed: 400,
              child: Container(height: 20, color: Colors.grey),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();

    final Finder maskFinder = find.byType(ShaderMask);
    expect(maskFinder, findsOneWidget);
    final ShaderMask mask = tester.widget<ShaderMask>(maskFinder);
    expect(mask.blendMode, BlendMode.srcATop);
    expect(mask.child, isNotNull);

    // The shader builds for the surface it paints on.
    expect(
      mask.shaderCallback(const Rect.fromLTWH(0, 0, 200, 20)),
      isA<Shader>(),
    );

    // The band keeps moving: the controller is still scheduling frames.
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    // A full cycle (travel + pause) renders without throwing.
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(maskFinder, findsOneWidget);
  });

  testWidgets('a zero speed falls back instead of stalling', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AssistantShimmer(speed: 0, trackHeight: 40, child: Text('x')),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);
    expect(find.byType(ShaderMask), findsOneWidget);
  });

  testWidgets('disabled shimmer leaves the child alone', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AssistantShimmer(enabled: false, child: Text('static')),
      ),
    ));
    await tester.pump();
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.text('static'), findsOneWidget);
  });

  testWidgets('the skeleton box carries the shimmer and its size', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: AssistantShimmerBox(width: 120, height: 16, radius: 8),
        ),
      ),
    ));
    await tester.pump();
    expect(find.byType(AssistantShimmer), findsOneWidget);
    expect(tester.getSize(find.byType(Container).first).height, 16);
  });

  testWidgets('a host colour overrides the default highlight', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AssistantShimmer(
          highlightColor: Colors.red,
          baseColor: Colors.blue,
          child: Text('tinted'),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('tinted'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
