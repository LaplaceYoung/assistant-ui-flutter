import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the chrome shows the origin and wires its controls', (
    WidgetTester tester,
  ) async {
    int reloads = 0;
    int opened = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AssistantWebPreview(
          origin: 'https://example.com',
          onReload: () => reloads++,
          onOpenExternal: () => opened++,
          child: const Text('FRAME'),
        ),
      ),
    ));
    await tester.pump();

    expect(find.text('https://example.com'), findsOneWidget);
    expect(find.text('FRAME'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.open_in_new));
    await tester.pump();
    expect(reloads, 1);
    expect(opened, 1);
  });

  testWidgets('loading replaces the frame and animates', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: AssistantWebPreview(
          origin: 'https://example.com',
          loading: true,
          child: Text('FRAME'),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Loading the preview…'), findsOneWidget);
    expect(find.text('FRAME'), findsNothing);
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });

  testWidgets('without a frame the platform note shows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AssistantWebPreview(origin: 'https://example.com')),
    ));
    await tester.pump();
    expect(find.text('No frame supplied for this platform'), findsOneWidget);
  });

  test('the frame surface reports its platform', () {
    // The test host is the VM: no iframe surface here, so the caller renders
    // its own frame and this returns null. On web the same call registers an
    // iframe platform view.
    expect(webPreviewSupported, isFalse);
    expect(
      webPreviewFrame(url: 'https://example.com', sandbox: 'allow-scripts'),
      isNull,
    );
  });
}
