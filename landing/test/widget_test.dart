import 'package:assistant_ui_landing/landing_theme.dart';
import 'package:assistant_ui_landing/widgets.dart';
import 'package:assistant_ui_landing/main.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('landing page renders the hero, nav and demo', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LandingApp());
    await tester.pump();

    expect(find.text('The frontend library for AI agents.'), findsOneWidget);
    expect(find.text('Read the docs'), findsOneWidget);
    expect(find.text('npx assistant-ui init'), findsOneWidget);
    expect(find.text('Cloud'), findsOneWidget);

    // The demo panel sits below the hero; scroll it into view.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pump();
    expect(find.text('How can I help you today?'), findsOneWidget);
    expect(find.text('New thread'), findsOneWidget);
  });

  testWidgets('the nav menus carry the live groups', (
    WidgetTester tester,
  ) async {
    // The nav only shows its links on a desktop-width surface.
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const LandingApp());
    await tester.pump();

    final TestGesture mouse =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);

    await mouse.moveTo(tester.getCenter(find.text('Products')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // The menus point at what this repository ships, not at upstream's pages.
    expect(find.text('THIS REPOSITORY'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('COVERAGE'), findsOneWidget);
    expect(find.text('Elements'), findsOneWidget);
    expect(find.text('Parity'), findsOneWidget);

    await mouse.moveTo(tester.getCenter(find.text('Resources')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('README'), findsOneWidget);
    expect(find.text('Port plan'), findsOneWidget);
    expect(find.text('Issues'), findsOneWidget);
    expect(find.text('License'), findsOneWidget);
  });

  testWidgets('the setup tabs swap the runtime sample', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LandingApp());
    await tester.pump();

    // The setup section sits below the demo; scroll it into view.
    await tester.scrollUntilVisible(
      find.text('LANGGRAPH'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    // The rendered samples, in page order.
    Iterable<String> samples() => tester
        .widgetList<CodeBlock>(find.byType(CodeBlock))
        .map((CodeBlock block) => block.code);

    expect(samples().any((String c) => c.contains('useChatRuntime')), isTrue);
    expect(find.text('Your route runs the model. The transport streams it back.'),
        findsOneWidget);

    await tester.tap(find.text('LANGGRAPH'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      samples().any((String c) => c.contains('useLangGraphRuntime')),
      isTrue,
    );
    expect(samples().any((String c) => c.contains('useChatRuntime')), isFalse);
    expect(
      find.text('Point stream at your graph. Threads and interrupts included.'),
      findsOneWidget,
    );

    await tester.tap(find.text('CUSTOM'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      samples().any((String c) => c.contains('useExternalStoreRuntime')),
      isTrue,
    );
    expect(
      find.text('No adapter at all. Your store, your transport, any backend.'),
      findsOneWidget,
    );
  });

  testWidgets('the runtime showcase renders a live element per act', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LandingApp());
    await tester.pump();

    // Bring the act row itself into view so the pointer can reach it.
    await tester.scrollUntilVisible(
      find.text('Approval'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The first act is streaming, so the live slot shows streamed text.
    expect(find.text('LIVE'), findsOneWidget);
    // The act label, plus the same word under the streaming pixel matrix.
    expect(find.text('Streaming'), findsWidgets);

    // Pointing at another act swaps the element in the slot.
    final TestGesture mouse =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.text('Approval')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Clean the build directory'), findsOneWidget);
    expect(find.text('rm -rf build/'), findsOneWidget);

    // Branching runs its own runtime seed and lands on three branches.
    await mouse.moveTo(tester.getCenter(find.text('Branching')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('3/3'), findsOneWidget);
  });

  testWidgets('the primitives anatomy lights a part and captions it', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LandingApp());
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('<ComposerPrimitive.Root>'),
      320,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The capture starts on Root and carries its caption.
    expect(
      find.text('Owns the runtime context. Everything composes inside.'),
      findsOneWidget,
    );

    // Pointing at the composer line holds that part.
    await tester.tap(find.text('<ComposerPrimitive.Root>'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Input, attachments, dictation, send.'), findsOneWidget);
  });

  testWidgets('the footer toggle switches the palette', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LandingApp());
    await tester.pump();

    Color background() => tester
        .widget<Scaffold>(find.byType(Scaffold))
        .backgroundColor!;

    expect(background(), LandingColors.dark.background);

    // The toggle lives in the footer, so scroll to it first.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -9000));
    await tester.pump();
    await tester.tap(find.byKey(const Key('landing-theme-toggle')));
    // MaterialApp animates the theme swap and brightness flips at its
    // midpoint; the page also runs looping animations, so settle is not an
    // option — pump past the transition instead.
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.light_mode_outlined), findsOneWidget,
        reason: 'the control flips to the light-mode icon');

    final MaterialApp app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light, reason: 'the toggle flipped the mode');
    expect(background(), LandingColors.light.background);
  });
}
