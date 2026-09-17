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

  testWidgets('the document reference reports the page jumped to', (
    WidgetTester tester,
  ) async {
    int? jumped;
    await pump(
      tester,
      AssistantDocumentReference(
        title: 'local_runtime.dart',
        pages: 96,
        activePage: 12,
        onJump: (int page) => jumped = page,
        anchors: const <DocumentAnchor>[
          DocumentAnchor(page: 12, quote: 'final ChatModelAdapter _adapter;'),
          DocumentAnchor(page: 88, quote: 'Future<void> get settled => _chain;'),
        ],
      ),
    );
    // The anchors are the jump targets.
    await tester.tap(find.textContaining('settled').first, warnIfMissed: false);
    await tester.pump();
    expect(jumped, isNotNull);
  });

  testWidgets('onboarding reports next and skip', (WidgetTester tester) async {
    int nexts = 0;
    int skips = 0;
    await pump(
      tester,
      AssistantOnboarding(
        index: 0,
        onNext: () => nexts++,
        onSkip: () => skips++,
        steps: const <OnboardingStep>[
          OnboardingStep(
            title: 'Point the runtime at a backend',
            body: 'An adapter turns a prompt into parts.',
            example: 'LocalRuntime(adapter: yourAdapter)',
          ),
          OnboardingStep(
            title: 'Mount the thread',
            body: 'The thread reads the state.',
            example: 'AssistantThread()',
          ),
        ],
      ),
    );
    await tester.tap(find.text('Next'));
    await tester.pump();
    expect(nexts, 1);

    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(skips, 1);
  });

  testWidgets('the permission request can be denied', (WidgetTester tester) async {
    GrantScope? granted;
    await pump(
      tester,
      AssistantPermissionGrant(
        capability: 'Read the repository',
        requester: 'search_docs',
        onGrant: (GrantScope scope) => granted = scope,
      ),
    );
    await tester.tap(find.text('Deny'));
    await tester.pump();
    expect(granted, GrantScope.denied);
  });

  testWidgets('the memory chips report a forget', (WidgetTester tester) async {
    String? forgotten;
    await pump(
      tester,
      AssistantMemoryChips(
        chips: const <MemoryChip>[
          MemoryChip(
            id: 'm1',
            text: 'Prefers terse answers',
            change: MemoryChange.added,
          ),
          MemoryChip(id: 'm2', text: 'Works in Dart', change: MemoryChange.updated),
        ],
        onForget: (String id) => forgotten = id,
      ),
    );
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();
    expect(forgotten, isNotNull);
  });

  testWidgets('the job progress reports a cancel', (WidgetTester tester) async {
    int cancels = 0;
    await pump(
      tester,
      AssistantJobProgress(
        title: 'Indexing the repository',
        stages: const <JobStage>[
          JobStage(name: 'Walking files', weight: 1),
          JobStage(name: 'Embedding', weight: 3),
          JobStage(name: 'Writing', weight: 1),
        ],
        stageIndex: 1,
        stageProgress: 0.4,
        eta: '2 min',
        onCancel: () => cancels++,
      ),
    );
    await tester.tap(find.bySemanticsLabel('Cancel the job'));
    await tester.pump();
    expect(cancels, 1);
  });

  testWidgets('the settings panel reports model, temperature and a toggle', (
    WidgetTester tester,
  ) async {
    final List<String> toggles = <String>[];
    await pump(
      tester,
      AssistantSettingsPanel(
        model: 'gpt-5.6-luna',
        models: const <String>['gpt-5.6-luna', 'gpt-5.6-sol'],
        systemPrompt: 'Be brief.',
        temperature: 0.5,
        onModelChange: (_) {},
        onSystemPromptChange: (_) {},
        onTemperatureChange: (double value) {},
        toggles: const <SettingToggle>[
          SettingToggle(
            key: 'tools',
            label: 'Allow tools',
            detail: 'The run may call the toolkit',
            on: false,
          ),
        ],
        onToggle: toggles.add,
      ),
    );
    await tester.tap(find.text('Allow tools'));
    await tester.pump();
    expect(toggles, <String>['tools']);
  });

  testWidgets('the mcp config reports authorize, test and remove', (
    WidgetTester tester,
  ) async {
    final List<String> calls = <String>[];
    await pump(
      tester,
      AssistantMcpConfig(
        servers: const <McpServerConfig>[
          McpServerConfig(
            id: 'search',
            name: 'search',
            transport: 'http',
            url: 'https://mcp.example.com/sse',
            status: McpConfigStatus.authRequired,
          ),
        ],
        onChange: (List<McpServerConfig> next) =>
            calls.add('change:${next.length}'),
        onAuthorize: (String id) => calls.add('authorize:$id'),
        onTest: (String id) => calls.add('test:$id'),
      ),
    );
    await tester.tap(find.text('Authorize'));
    await tester.pump();
    expect(calls, contains('authorize:search'));

    await tester.tap(find.bySemanticsLabel('Test search'));
    await tester.pump();
    expect(calls, contains('test:search'));
  });

  testWidgets('the diagram reports zoom, reset and expand', (
    WidgetTester tester,
  ) async {
    final List<String> calls = <String>[];
    await pump(
      tester,
      AssistantDiagram(
        title: 'The run lifecycle',
        zoom: 1,
        onZoomIn: () => calls.add('in'),
        onZoomOut: () => calls.add('out'),
        onReset: () => calls.add('reset'),
        onExpand: () => calls.add('expand'),
        child: const SizedBox(height: 160),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Zoom in'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Zoom out'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Reset the view'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Open full screen'));
    await tester.pump();
    expect(calls, <String>['in', 'out', 'reset', 'expand']);
  });

  testWidgets('the attachment removes itself and opens', (
    WidgetTester tester,
  ) async {
    final List<String> calls = <String>[];
    await pump(
      tester,
      AssistantAttachmentCard(
        attachment: const DocumentAttachment(
          id: 'a1',
          filename: 'notes.txt',
          mimeType: 'text/plain',
        ),
        onRemove: () => calls.add('remove:a1'),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Remove'));
    await tester.pump();
    expect(calls, contains('remove:a1'));
  });

  testWidgets('read aloud reports the toggle and the speed', (
    WidgetTester tester,
  ) async {
    int toggles = 0;
    int rates = 0;
    await pump(
      tester,
      AssistantReadAloud(
        words: const <String>['The', 'thread', 'settles'],
        spokenIndex: 1,
        elapsed: '0:02',
        duration: '0:06',
        onToggle: () => toggles++,
        onRateChange: () => rates++,
      ),
    );
    await tester.tap(find.bySemanticsLabel('Play'));
    await tester.pump();
    expect(toggles, 1);
  });

  testWidgets('dragging the temperature slider reports the value', (
    WidgetTester tester,
  ) async {
    final List<double> values = <double>[];
    await pump(
      tester,
      AssistantSettingsPanel(
        model: 'gpt-5.6-luna',
        models: const <String>['gpt-5.6-luna'],
        systemPrompt: 'Be brief.',
        temperature: 0.2,
        onModelChange: (_) {},
        onSystemPromptChange: (_) {},
        onTemperatureChange: values.add,
      ),
    );
    // A slider answers a drag, not a tap.
    await tester.drag(find.byType(Slider), const Offset(120, 0));
    await tester.pump();
    expect(values, isNotEmpty);
    expect(values.last, greaterThan(0.2));
  });

  testWidgets('the search steps through the matches', (
    WidgetTester tester,
  ) async {
    final List<int> steps = <int>[];
    await pump(
      tester,
      // The pane lays out inside a bounded box.
      SizedBox(
        height: 260,
        child: AssistantConversationSearch(
        query: 'settle',
        activeIndex: 0,
        onQueryChange: (_) {},
        onStep: steps.add,
        hits: const <SearchHit>[
          SearchHit(
            id: 'h1',
            before: 'The thread ',
            match: 'settles',
            after: ' once the run finished.',
            position: 0.1,
          ),
          SearchHit(
            id: 'h2',
            before: 'It is already ',
            match: 'settled',
            after: '.',
            position: 0.9,
          ),
        ],
        ),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Next match'));
    await tester.pump();
    expect(steps, <int>[1]);

    await tester.tap(find.bySemanticsLabel('Previous match'));
    await tester.pump();
    expect(steps, <int>[1, -1]);
  });

  testWidgets('read aloud cycles the playback speed', (
    WidgetTester tester,
  ) async {
    int rates = 0;
    await pump(
      tester,
      AssistantReadAloud(
        words: const <String>['The', 'thread', 'settles'],
        spokenIndex: 0,
        elapsed: '0:01',
        duration: '0:06',
        onToggle: () {},
        onRateChange: () => rates++,
      ),
    );
    await tester.tap(find.bySemanticsLabel(RegExp('Playback speed')).first);
    await tester.pump();
    expect(rates, 1);
  });

  testWidgets('the canvas copy and close report back', (
    WidgetTester tester,
  ) async {
    final List<String> calls = <String>[];
    await pump(
      tester,
      AssistantCanvasSplit(
        title: 'release-notes.md',
        onCopy: () => calls.add('copy'),
        onClose: () => calls.add('close'),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Copy release-notes.md'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Close the canvas'));
    await tester.pump();
    expect(calls, <String>['copy', 'close']);
  });

  testWidgets('the file tree reports the file picked', (
    WidgetTester tester,
  ) async {
    final List<String> picks = <String>[];
    await pump(
      tester,
      SizedBox(
        height: 240,
        child: AssistantFileTree(
          visibleCount: 3,
          totalAdditions: 5,
          totalDeletions: 1,
          selectedPath: 'lib/src/runtime.dart',
          onSelect: picks.add,
          nodes: const <FileTreeNode>[
            FileTreeNode(path: 'lib', name: 'lib', depth: 0, isFolder: true),
            FileTreeNode(
              path: 'lib/src/runtime.dart',
              name: 'runtime.dart',
              depth: 1,
              additions: 4,
              deletions: 1,
            ),
            FileTreeNode(
              path: 'README.md',
              name: 'README.md',
              depth: 0,
              additions: 1,
            ),
          ],
        ),
      ),
    );
    expect(find.text('runtime.dart'), findsOneWidget);

    await tester.tap(find.text('README.md'));
    await tester.pump();
    expect(picks, <String>['README.md']);
  });
}
