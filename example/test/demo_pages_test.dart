import 'package:assistant_ui/assistant_ui.dart';
import 'package:assistant_ui_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two showcase pages render the elements no other surface shows, so a
/// reader can see them running and a regression in one of them fails here.
void main() {
  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1200, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // `Scaffold` supplies the `Material` the composer's text field needs.
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: page),
      ),
    );
    await tester.pump();
  }

  testWidgets('the states page shows the run states and the indicators', (
    WidgetTester tester,
  ) async {
    await pump(tester, const StatesDemo());
    expect(find.byType(AssistantEmptyState), findsOneWidget);
    expect(find.byType(AssistantLoadingState), findsOneWidget);
    expect(find.byType(AssistantTypingIndicator), findsOneWidget);
    expect(find.byType(AssistantErrorState), findsWidgets);
    expect(find.byType(AssistantFollowUpSuggestions), findsOneWidget);
    expect(find.byType(AssistantMessageTiming), findsOneWidget);
  });

  testWidgets('the pieces page shows the pickers and the message pieces', (
    WidgetTester tester,
  ) async {
    // Tall enough that the list builds every section, so no scrolling is needed.
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: PiecesDemo()),
      ),
    );
    await tester.pump();

    expect(find.byType(AssistantMobileComposer), findsOneWidget);
    expect(find.byType(AssistantModelPicker), findsOneWidget);
    expect(find.byType(AssistantRegenerateMenu), findsOneWidget);
    expect(find.byType(AssistantQuoteReply), findsWidgets);
    expect(find.byType(AssistantMessageAttachmentList), findsOneWidget);

    // Picking a model reports back, which is what the footer prints.
    await tester.tap(
      find.descendant(
        of: find.byType(AssistantModelPicker),
        matching: find.text('GPT-5.6 Luna'),
      ),
    );
    await tester.pump();
    expect(find.textContaining('model: gpt-5.6-luna'), findsOneWidget);
  });

  testWidgets('the messages page opens on the pieces a message carries', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: MessagesDemo()),
      ),
    );
    await tester.pump();

    // The page is a lazy list, so this asserts the sections a reader sees on
    // arrival; each piece further down carries its own tests in the package.
    expect(find.byType(AssistantInlineCitation), findsOneWidget);
    expect(find.byType(AssistantRetrievalChunks), findsOneWidget);
    expect(find.text('Inline citation'), findsOneWidget);
    expect(find.text('Retrieval chunks'), findsOneWidget);
  });

  testWidgets('the navigation page opens on search, and lists the rest', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: NavigationDemo()),
      ),
    );
    await tester.pump();

    expect(find.byType(AssistantConversationSearch), findsOneWidget);
    expect(find.byType(AssistantThreadSearch), findsOneWidget);
    expect(find.text('Conversation search'), findsOneWidget);
  });

  testWidgets('the rendering page opens on markdown and mermaid', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(body: RenderingDemo()),
      ),
    );
    await tester.pump();

    expect(find.byType(AssistantMarkdown), findsOneWidget);
    expect(find.byType(AssistantMermaidDiagram), findsOneWidget);
    expect(find.text('Streaming'), findsOneWidget);
  });
}
