import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every control a reader can press has to do the thing it looks like it does.
/// These are the elements whose affordances were added to the gallery last: tap
/// the control, assert the callback fired.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(
          body: SingleChildScrollView(child: child),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the regenerate menu reports the option picked', (
    WidgetTester tester,
  ) async {
    String? picked;
    await pump(
      tester,
      AssistantRegenerateMenu(
        open: true,
        currentId: 'same',
        onOpenChange: (_) {},
        onPick: (String id) => picked = id,
        options: const <RegenerateOption>[
          RegenerateOption(id: 'same', label: 'Same model', detail: 'as before'),
          RegenerateOption(id: 'luna', label: 'GPT-5.6 Luna', detail: 'faster'),
        ],
      ),
    );
    await tester.tap(find.text('GPT-5.6 Luna'));
    await tester.pump();
    expect(picked, 'luna');
  });

  testWidgets('the quote toolbar reports the action', (WidgetTester tester) async {
    String? action;
    await pump(
      tester,
      AssistantQuoteReply(
        before: 'the run ',
        selection: 'settles',
        after: ' when the tools finish',
        toolbarVisible: true,
        onAction: (String key) => action = key,
        actions: const <QuoteAction>[
          QuoteAction(key: 'reply', label: 'Reply', icon: Icons.reply),
        ],
      ),
    );
    await tester.tap(find.text('Reply'));
    await tester.pump();
    expect(action, 'reply');
  });

  testWidgets('the feedback dialog reports a reason and the submit', (
    WidgetTester tester,
  ) async {
    final List<String> toggled = <String>[];
    int submits = 0;
    await pump(
      tester,
      AssistantFeedbackDialog(
        reasons: const <String>['Too verbose', 'Off topic'],
        onToggleReason: toggled.add,
        onSubmit: () => submits++,
      ),
    );
    await tester.tap(find.text('Too verbose'));
    await tester.pump();
    expect(toggled, <String>['Too verbose']);

    await tester.tap(find.text('Send feedback'));
    await tester.pump();
    expect(submits, 1);
  });

  testWidgets('the permission request reports the scope granted', (
    WidgetTester tester,
  ) async {
    GrantScope? granted;
    await pump(
      tester,
      AssistantPermissionGrant(
        capability: 'Read the repository',
        requester: 'search_docs',
        reach: const <String>['src/**'],
        onGrant: (GrantScope scope) => granted = scope,
      ),
    );
    await tester.tap(find.text('Always'));
    await tester.pump();
    expect(granted, GrantScope.always);
  });

  testWidgets('the launcher bubble reports a prompt pick', (
    WidgetTester tester,
  ) async {
    String? picked;
    await pump(
      tester,
      AssistantLauncherBubble(
        open: true,
        greeting: 'Need a hand?',
        prompts: const <String>['Summarize'],
        onToggle: () {},
        onPick: (String prompt) => picked = prompt,
        onStart: () {},
      ),
    );
    await tester.tap(find.text('Summarize'));
    await tester.pump();
    expect(picked, 'Summarize');
  });

  testWidgets('the chat panel sends what was typed', (WidgetTester tester) async {
    int sends = 0;
    await pump(
      tester,
      AssistantChatPanel(
        composerPlaceholder: 'Reply…',
        onSend: () => sends++,
        messages: const <AssistantChatPanelMessage>[
          AssistantChatPanelMessage(text: 'hello'),
        ],
      ),
    );
    await tester.enterText(find.byType(TextField), 'ping');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Send'));
    await tester.pump();
    expect(sends, 1);
  });

  testWidgets('the artifact card reports a tap', (WidgetTester tester) async {
    int taps = 0;
    await pump(
      tester,
      AssistantArtifactCard(
        title: 'report.md',
        meta: '4 KB',
        onTap: () => taps++,
      ),
    );
    await tester.tap(find.text('report.md'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('the code runner reports the run', (WidgetTester tester) async {
    int runs = 0;
    await pump(
      tester,
      AssistantCodeRunner(
        language: 'dart',
        code: 'void main() {}',
        onRun: () => runs++,
      ),
    );
    await tester.tap(find.bySemanticsLabel('Run this snippet'));
    await tester.pump();
    expect(runs, 1);
  });

  testWidgets('the thread search reports the thread picked', (
    WidgetTester tester,
  ) async {
    String? picked;
    await pump(
      tester,
      AssistantThreadSearch(
        activeId: 't1',
        onSelect: (String id) => picked = id,
        onQueryChange: (_) {},
        threads: const <SearchableThread>[
          SearchableThread(
            id: 't1',
            title: 'Streaming notes',
            group: 'Today',
            preview: 'Parts arrive cumulatively…',
          ),
          SearchableThread(
            id: 't2',
            title: 'Tool continuations',
            group: 'Today',
            preview: 'A tool result re-enters the model…',
          ),
        ],
      ),
    );
    await tester.tap(find.text('Tool continuations'));
    await tester.pump();
    expect(picked, 't2');
  });

  testWidgets('the map rail reports the turn picked', (WidgetTester tester) async {
    String? picked;
    await pump(
      tester,
      SizedBox(
        height: 240,
        child: AssistantConversationMap(
          activeId: 'c1',
          onSelect: (String id) => picked = id,
          visibleIds: const <String>['c1', 'c2'],
          entries: const <ConversationMapEntry>[
            ConversationMapEntry(id: 'c1', title: 'Streaming notes'),
            ConversationMapEntry(id: 'c2', title: 'Tool continuations'),
          ],
        ),
      ),
    );
    await tester.tap(find.byType(AssistantConversationMap));
    await tester.pump();
    expect(picked, isNotNull);
  });

  testWidgets('the prompt library reports the prompt picked', (
    WidgetTester tester,
  ) async {
    String? picked;
    await pump(
      tester,
      AssistantPromptLibrary(
        selectedId: 'p1',
        onSelect: (String id) => picked = id,
        onQueryChange: (_) {},
        prompts: const <SavedPrompt>[
          SavedPrompt(id: 'p1', name: 'Review the diff', body: 'Review {diff}'),
          SavedPrompt(id: 'p2', name: 'Summarize', body: 'Summarize {count}'),
        ],
      ),
    );
    await tester.tap(find.text('Summarize'));
    await tester.pump();
    expect(picked, 'p2');
  });
}
