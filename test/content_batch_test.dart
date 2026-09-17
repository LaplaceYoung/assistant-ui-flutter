import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('inline citation', () {
    testWidgets('numbers the chips and opens the source preview', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantInlineCitation(
          segments: <String>['Streaming', ' keeps the thread responsive', '.'],
          sources: <SourceRef>[
            SourceRef(
              domain: 'ai-sdk.dev',
              title: 'Data stream protocol',
              snippet: 'The v1 frames keep a tool call in one message.',
            ),
            SourceRef(domain: 'dart.dev', title: 'Streams'),
          ],
        ),
      ));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.textContaining('keeps the thread responsive'), findsOneWidget);
      // The preview only exists while a citation is open.
      expect(find.text('Data stream protocol'), findsNothing);

      await tester.pumpWidget(_wrap(
        const AssistantInlineCitation(
          openIndex: 0,
          segments: <String>['Streaming', ' keeps the thread responsive', '.'],
          sources: <SourceRef>[
            SourceRef(
              domain: 'ai-sdk.dev',
              title: 'Data stream protocol',
              snippet: 'The v1 frames keep a tool call in one message.',
            ),
          ],
        ),
      ));
      await tester.pump();
      expect(find.text('Data stream protocol'), findsOneWidget);
    });
  });

  group('retrieval chunks', () {
    testWidgets('shows the query, the count and each passage', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantRetrievalChunks(
          query: 'streaming protocol',
          visibleCount: 2,
          chunks: <RetrievalChunk>[
            RetrievalChunk(
              id: 'c1',
              source: 'ai-sdk.dev',
              locator: 'p. 4',
              score: 0.91,
              text: 'The data stream keeps tool calls inline.',
            ),
            RetrievalChunk(
              id: 'c2',
              source: 'notes.md',
              locator: 'lib/chat.dart:40',
              score: 0.62,
              text: 'Chunks are cumulative.',
            ),
            RetrievalChunk(
              id: 'c3',
              source: 'hidden',
              locator: 'p. 9',
              score: 0.5,
              text: 'not revealed yet',
            ),
          ],
        ),
      ));
      expect(find.text('streaming protocol'), findsOneWidget);
      expect(find.text('3 passages above threshold'), findsOneWidget);
      expect(find.text('ai-sdk.dev'), findsOneWidget);
      expect(find.text('0.91'), findsOneWidget);
      expect(find.text('hidden'), findsNothing);
      expect(
        find.bySemanticsLabel('ai-sdk.dev relevance score'),
        findsOneWidget,
      );
    });

    testWidgets('while searching it says so instead of counting', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantRetrievalChunks(
          query: 'x',
          visibleCount: 0,
          searching: true,
          chunks: <RetrievalChunk>[],
        ),
      ));
      expect(find.text('Retrieving'), findsOneWidget);
      expect(find.textContaining('passages above threshold'), findsNothing);
    });
  });

  group('web search', () {
    testWidgets('lists what it read and how many', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantWebSearch(
          query: 'flutter 3.47 release notes',
          visibleResults: 2,
          results: <WebSearchResult>[
            WebSearchResult(
              title: 'Flutter 3.47',
              domain: 'docs.flutter.dev',
            ),
            WebSearchResult(title: 'Release notes', domain: 'medium.com'),
            WebSearchResult(title: 'hidden', domain: 'example.com'),
          ],
        ),
      ));
      expect(find.text('Read 3 sources'), findsOneWidget);
      expect(find.text('Flutter 3.47'), findsOneWidget);
      expect(find.text('medium.com'), findsOneWidget);
      expect(find.text('hidden'), findsNothing);
    });
  });

  group('research report', () {
    testWidgets('counts finished sections and shows previews', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantResearchReport(
          title: 'State of streaming',
          sourcesRead: 12,
          sections: <ReportSection>[
            ReportSection(
              id: 's1',
              heading: 'Protocol',
              state: SectionState.done,
              sources: 4,
              preview: 'Frames are cumulative.',
            ),
            ReportSection(
              id: 's2',
              heading: 'Tooling',
              state: SectionState.writing,
              sources: 2,
            ),
            ReportSection(
              id: 's3',
              heading: 'Outlook',
              state: SectionState.pending,
            ),
          ],
        ),
      ));
      expect(find.text('1/3 sections · 12 sources read'), findsOneWidget);
      expect(find.text('Protocol'), findsOneWidget);
      expect(find.text('4 src'), findsOneWidget);
      expect(find.text('Frames are cumulative.'), findsOneWidget);
      expect(find.byType(AuiSpinner), findsOneWidget);
    });
  });

  group('speaker identity', () {
    testWidgets('names each speaker and marks the kind', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantSpeakerIdentity(
          turns: <SpeakerTurn>[
            SpeakerTurn(
              id: 't1',
              kind: SpeakerKind.user,
              name: 'You',
              text: 'Draft the release notes',
            ),
            SpeakerTurn(
              id: 't2',
              kind: SpeakerKind.agent,
              name: 'Luna',
              detail: 'gpt-5.6-luna',
              text: 'On it.',
            ),
            SpeakerTurn(
              id: 't3',
              kind: SpeakerKind.tool,
              name: 'read_file',
              detail: 'lib/main.dart',
              text: '412 lines',
            ),
          ],
        ),
      ));
      expect(find.text('You'), findsOneWidget);
      expect(find.text('gpt-5.6-luna'), findsOneWidget);
      expect(find.text('read_file'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
      expect(find.byIcon(Icons.build_outlined), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    });
  });

  group('conversation search', () {
    testWidgets('steps through hits and marks them on the rail', (
      WidgetTester tester,
    ) async {
      final List<int> steps = <int>[];
      await tester.pumpWidget(_wrap(
        AssistantConversationSearch(
          query: 'stream',
          activeIndex: 1,
          onStep: steps.add,
          hits: const <SearchHit>[
            SearchHit(
              id: 'h1',
              before: 'the ',
              match: 'stream',
              after: ' runs',
              position: 12,
            ),
            SearchHit(
              id: 'h2',
              before: 'a ',
              match: 'stream',
              after: ' of chunks',
              position: 68,
            ),
          ],
        ),
      ));
      expect(find.text('2/2'), findsOneWidget);
      expect(find.text('stream'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Previous match'));
      await tester.pump();
      expect(steps, <int>[-1]);
    });

    testWidgets('an empty query reports zero hits', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantConversationSearch(hits: <SearchHit>[]),
      ));
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Find in conversation'), findsOneWidget);
    });
  });

  group('thread search', () {
    const List<SearchableThread> threads = <SearchableThread>[
      SearchableThread(
        id: 't1',
        title: 'Release notes',
        group: 'Today',
        preview: 'Drafted the notes',
        pinned: true,
      ),
      SearchableThread(
        id: 't2',
        title: 'Parser work',
        group: 'Yesterday',
        preview: 'Patched the tokenizer',
      ),
    ];

    testWidgets('keeps pinned threads on top and filters the rest', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantThreadSearch(threads: threads, query: 'parser'),
      ));
      expect(find.text('pinned'), findsNothing);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Parser work'), findsOneWidget);
      expect(find.text('Release notes'), findsNothing);
    });

    testWidgets('arrows step the selection and report it', (
      WidgetTester tester,
    ) async {
      final List<String> selected = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantThreadSearch(
          threads: threads,
          query: 'e',
          activeId: 't1',
          onSelect: selected.add,
        ),
      ));
      await tester.enterText(find.byType(TextField), 'e');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      // Pinned first, so the next thread is the yesterday one.
      expect(selected, <String>['t2']);
    });
  });

  group('map answer', () {
    testWidgets('renders the pins, the list and reports selection', (
      WidgetTester tester,
    ) async {
      final List<String> picks = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantMapAnswer(
          activeId: 'p2',
          route: true,
          onSelect: picks.add,
          pins: const <MapPin>[
            MapPin(id: 'p1', label: 'Bakery', detail: '0.4 km', x: 20, y: 30),
            MapPin(id: 'p2', label: 'Office', detail: '1.2 km', x: 60, y: 70),
          ],
        ),
      ));
      expect(find.text('Bakery'), findsOneWidget);
      expect(find.text('1.2 km'), findsOneWidget);
      await tester.tap(find.text('Office'));
      await tester.pump();
      expect(picks, <String>['p2']);
    });
  });

  group('document reference', () {
    testWidgets('lists the anchors and jumps on tap', (
      WidgetTester tester,
    ) async {
      final List<int> jumps = <int>[];
      await tester.pumpWidget(_wrap(
        AssistantDocumentReference(
          title: 'q3-report.pdf',
          pages: 24,
          activePage: 12,
          onJump: jumps.add,
          anchors: const <DocumentAnchor>[
            DocumentAnchor(page: 4, quote: 'Revenue grew 12%.'),
            DocumentAnchor(page: 12, quote: 'Churn is flattening.'),
          ],
        ),
      ));
      expect(find.text('24 pages · 2 cited'), findsOneWidget);
      expect(find.text('p. 12'), findsOneWidget);
      expect(find.text('Churn is flattening.'), findsOneWidget);
      await tester.tap(find.text('Revenue grew 12%.'));
      await tester.pump();
      expect(jumps, <int>[4]);
    });
  });

  group('diagram', () {
    testWidgets('drives the zoom controls', (WidgetTester tester) async {
      final List<String> calls = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantDiagram(
          title: 'Request flow',
          zoom: 1.5,
          onZoomIn: () => calls.add('in'),
          onZoomOut: () => calls.add('out'),
          onReset: () => calls.add('reset'),
          child: const Text('graph'),
        ),
      ));
      expect(find.text('Request flow'), findsOneWidget);
      expect(find.text('150%'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Zoom in'));
      await tester.tap(find.bySemanticsLabel('Reset the view'));
      await tester.pump();
      expect(calls, <String>['in', 'reset']);
      // Without a handler the expand control is inert.
      expect(
        tester
            .widget<AuiIconAction>(
              find.byWidgetPredicate((Widget widget) =>
                  widget is AuiIconAction && widget.label == 'Open full screen'),
            )
            .onPressed,
        isNull,
      );
    });
  });

  group('mermaid diagram', () {
    testWidgets('streams a skeleton, then the diagram, and falls back', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantMermaidDiagram(code: 'graph TD; A-->B', streaming: true),
      ));
      expect(find.byType(AssistantMermaidSkeleton), findsOneWidget);

      await tester.pumpWidget(_wrap(
        const AssistantMermaidDiagram(
          code: 'graph TD; A-->B',
          diagram: Text('rendered'),
        ),
      ));
      expect(find.text('rendered'), findsOneWidget);
      expect(find.byType(AssistantMermaidSkeleton), findsNothing);

      await tester.pumpWidget(_wrap(
        const AssistantMermaidDiagram(code: 'graph TD; A-->B'),
      ));
      expect(find.text('diagram could not be rendered'), findsOneWidget);
      expect(find.text('graph TD; A-->B'), findsOneWidget);
    });
  });

  group('image', () {
    testWidgets('renders each state with its own message', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantImage(state: AuiImageState.loading),
      ));
      expect(find.byType(AuiSpinner), findsOneWidget);

      await tester.pumpWidget(_wrap(
        const AssistantImage(state: AuiImageState.failed),
      ));
      expect(find.text('Image could not be displayed'), findsOneWidget);

      await tester.pumpWidget(_wrap(
        const AssistantImage(state: AuiImageState.blocked),
      ));
      expect(find.text('Image blocked by policy'), findsOneWidget);
    });

    testWidgets('the controls appear only when the host wires them', (
      WidgetTester tester,
    ) async {
      int downloads = 0;
      await tester.pumpWidget(_wrap(
        AssistantImage(
          state: AuiImageState.ready,
          image: const ColoredBox(
            color: Color(0xFF333333),
            child: SizedBox(width: 64, height: 64),
          ),
          onDownload: () => downloads++,
        ),
      ));
      // The controls only appear on hover, so bring the pointer over the card.
      final TestGesture mouse =
          await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.byType(AssistantImage)));
      // Opacity 0 drops semantics, so let the fade finish before tapping.
      await tester.pump(const Duration(milliseconds: 200));
      // The control is a real widget whether or not the fade has finished.
      await tester.tap(find.byIcon(Icons.download_outlined));
      await tester.pump();
      expect(downloads, 1);
      expect(find.byIcon(Icons.copy), findsNothing);
      await mouse.removePointer();
    });
  });

  group('image generation', () {
    testWidgets('shows the size while generating and the prompt after', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantImageGeneration(prompt: 'a green valley'),
      ));
      expect(find.text('1024 × 1024'), findsOneWidget);
      expect(find.text('Generating'), findsOneWidget);

      await tester.pumpWidget(_wrap(
        const AssistantImageGeneration(
          prompt: 'a green valley',
          generating: false,
        ),
      ));
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.text('a green valley'), findsOneWidget);
      expect(find.bySemanticsLabel('Regenerate image'), findsOneWidget);
    });
  });
}
