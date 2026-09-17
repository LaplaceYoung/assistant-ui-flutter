import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('math block', () {
    testWidgets('reveals steps and keeps their notes', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantMathBlock(
          label: 'Derivation',
          visibleSteps: 1,
          steps: <MathStep>[
            MathStep(
              expression: Text('x = 2'),
              note: 'divide both sides',
            ),
            MathStep(expression: Text('x + 1 = 3')),
          ],
        ),
      ));
      expect(find.text('Derivation'), findsOneWidget);
      expect(find.text('x = 2'), findsOneWidget);
      expect(find.text('divide both sides'), findsOneWidget);
      expect(find.text('x + 1 = 3'), findsNothing);
    });
  });

  group('artifact card', () {
    testWidgets('a live artifact counts words, a settled one shows meta', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantArtifactCard(
          title: 'release-notes.md',
          meta: '1.2 kb · markdown',
          generating: true,
          words: 412,
        ),
      ));
      expect(find.text('release-notes.md'), findsOneWidget);
      expect(find.text('Writing'), findsOneWidget);
      expect(find.text('412 words'), findsOneWidget);
      expect(find.text('1.2 kb · markdown'), findsNothing);

      await tester.pumpWidget(_wrap(
        const AssistantArtifactCard(
          title: 'release-notes.md',
          meta: '1.2 kb · markdown',
        ),
      ));
      expect(find.text('1.2 kb · markdown'), findsOneWidget);
      expect(find.text('Writing'), findsNothing);
    });
  });

  group('syntax highlighter', () {
    test('tokenizes comments, strings, numbers and keywords', () {
      final List<AuiCodeToken> tokens = tokenizeAuiCode(
        '// note\nfinal int count = 42;\nprint("hi");',
        'dart',
      );
      final List<AuiCodeToken> comments = tokens
          .where((AuiCodeToken token) => token.kind == AuiTokenKind.comment)
          .toList();
      expect(comments.single.text, '// note');
      expect(
        tokens.where((AuiCodeToken token) => token.kind == AuiTokenKind.keyword)
            .map((AuiCodeToken token) => token.text),
        contains('final'),
      );
      // `int` is a type in Dart, so it takes the type color.
      expect(
        tokens
            .where((AuiCodeToken token) => token.kind == AuiTokenKind.type)
            .map((AuiCodeToken token) => token.text),
        contains('int'),
      );
      expect(
        tokens.where((AuiCodeToken token) => token.kind == AuiTokenKind.number)
            .single
            .text,
        '42',
      );
      expect(
        tokens.where((AuiCodeToken token) => token.kind == AuiTokenKind.string)
            .single
            .text,
        '"hi"',
      );
    });

    test('python comments and triple-quoted strings stay one token', () {
      final List<AuiCodeToken> tokens = tokenizeAuiCode(
        '# c\ndef f():\n    return """a\nb"""',
        'python',
      );
      expect(
        tokens.where((AuiCodeToken token) => token.kind == AuiTokenKind.comment)
            .single
            .text,
        '# c',
      );
      expect(
        tokens.where((AuiCodeToken token) => token.kind == AuiTokenKind.string)
            .single
            .text,
        contains('a\nb'),
      );
    });

    testWidgets('renders the code inside a themed block', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantSyntaxHighlighter(
          code: 'void main() {}',
          language: 'dart',
        ),
      ));
      expect(find.byType(SelectableText), findsOneWidget);
    });
  });

  group('markdown fenced code', () {
    testWidgets('colors a fenced block with the highlighter palette', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantMarkdown(
          text: '```dart\nfinal count = 42; // note\n```',
        ),
      ));
      // The block is tokenized, not one plain run: some span holds several
      // children, each with its own color.
      // The block is tokenized: somewhere in the span tree sits a run of
      // several colored pieces rather than one plain string.
      bool hasTokenRun(InlineSpan span) {
        if (span is! TextSpan) return false;
        final List<InlineSpan>? children = span.children;
        if (children == null) return false;
        if (children.length > 1 &&
            children.every((InlineSpan child) =>
                child is TextSpan && child.text != null)) {
          return true;
        }
        return children.any(hasTokenRun);
      }

      final Iterable<Text> texts = tester.widgetList<Text>(find.byType(Text));
      expect(
        texts.any((Text text) {
          final InlineSpan? span = text.textSpan;
          return span != null && hasTokenRun(span);
        }),
        isTrue,
      );
      expect(find.text('dart'), findsOneWidget);
    });

    testWidgets('a fence without a language stays plain', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantMarkdown(text: '```\nplain text\n```'),
      ));
      expect(find.textContaining('plain text'), findsOneWidget);
    });
  });

  group('markdown math and mermaid', () {
    testWidgets('display math renders through the host renderer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        AssistantMarkdown(
          // Display math sits on its own line, as remark-math expects.
          text: 'The area:\n\n\$\$\\pi r^2\$\$',
          mathRenderer: (BuildContext context, String tex, bool display) =>
              Text('MATH($tex)'),
        ),
      ));
      expect(find.text(r'MATH(\pi r^2)'), findsOneWidget);
    });

    testWidgets('without a renderer math shows its TeX source', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantMarkdown(text: '\$\$a^2 + b^2 = c^2\$\$'),
      ));
      expect(find.text('a^2 + b^2 = c^2'), findsOneWidget);
    });

    testWidgets('inline math keeps the styled source', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantMarkdown(text: 'Euler: \$e^{i\\pi} + 1 = 0\$ it is.'),
      ));
      expect(find.textContaining('e^{i'), findsOneWidget);
    });

    testWidgets('a mermaid fence goes to the mermaid element', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantMarkdown(text: '```mermaid\ngraph TD; A-->B\n```'),
      ));
      // Without a host drawing the element shows its fallback, not a plain
      // code block.
      expect(find.text('diagram could not be rendered'), findsOneWidget);
      expect(find.text('graph TD; A-->B'), findsOneWidget);
    });

    testWidgets('a host drawing replaces the fallback', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        AssistantMarkdown(
          text: '```mermaid\ngraph TD; A-->B\n```',
          mermaidDiagram: (BuildContext context, String code) =>
              Text('DIAGRAM(${code.trim().length} chars)'),
        ),
      ));
      expect(find.textContaining('DIAGRAM('), findsOneWidget);
      expect(find.text('diagram could not be rendered'), findsNothing);
    });
  });

  group('file chips', () {
    test('the icon set follows the mime type', () {
      expect(attachmentIcon('image/png'), Icons.image_outlined);
      expect(attachmentIcon('audio/mpeg'), Icons.audiotrack_outlined);
      expect(attachmentIcon('video/mp4'), Icons.movie_outlined);
      expect(attachmentIcon('application/zip'), Icons.folder_zip_outlined);
      expect(attachmentIcon('application/pdf'), Icons.picture_as_pdf_outlined);
      expect(attachmentIcon('application/json'), Icons.data_object);
      expect(attachmentIcon('text/plain'), Icons.description_outlined);
      expect(attachmentIcon('application/octet-stream'), Icons.attach_file);
    });

    test('a base64 payload reports its byte size', () {
      // 12 bytes -> 16 base64 characters, no padding.
      expect(attachmentSizeLabel('JVBERi0xLjQK'), isNotNull);
      expect(attachmentSizeLabel('aGVsbG8='), '5 B'); // hello
      expect(attachmentSizeLabel('https://example.com/a.pdf'), isNull);
      expect(attachmentSizeLabel('data:application/pdf;base64,AAAA'), isNull);
      expect(attachmentSizeLabel(null), isNull);
      expect(attachmentSizeLabel(''), isNull);
      // 2048 bytes -> 2731 base64 characters with one '=' of padding.
      expect(
        attachmentSizeLabel('A' * 2730 + '=='),
        '2.0 KB',
      );
    });

    test('the type label is short and readable', () {
      expect(attachmentTypeLabel('application/json'), 'JSON');
      expect(attachmentTypeLabel('text/csv'), 'CSV');
      expect(attachmentTypeLabel('application/pdf'), 'PDF');
      expect(attachmentTypeLabel('text/plain'), 'TXT');
      expect(attachmentTypeLabel('image/png'), 'PNG');
    });

    testWidgets('a payload offers a download control', (
      WidgetTester tester,
    ) async {
      final List<FilePart> downloads = <FilePart>[];
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);
      await tester.pumpWidget(
        AuiRuntimeProvider(
          runtime: runtime,
          child: MaterialApp(
            home: Scaffold(
              body: AssistantThread(onDownloadFile: downloads.add),
            ),
          ),
        ),
      );
      await runtime.thread.send(content: <MessagePart>[const TextPart('go')]);
      await tester.pump();
      adapter.emit(<MessagePart>[
        const FilePart(
          mimeType: 'application/pdf',
          filename: 'brief.pdf',
          data: 'JVBERi0=',
        ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('brief.pdf'), findsOneWidget);
      // The payload is base64, so the chip shows its size rather than a type.
      expect(find.text('5 B'), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.download_outlined));
      await tester.pump();
      expect(downloads, hasLength(1));
      expect(downloads.single.filename, 'brief.pdf');
    });
  });

  group('quotes', () {
    test('a quote part survives the wire round trip', () {
      const QuotePart part = QuotePart(
        text: 'the failing assertion',
        messageId: 'm2',
        role: 'assistant',
      );
      final MessagePart back = MessagePart.fromJson(part.toJson());
      expect(back, isA<QuotePart>());
      final QuotePart quote = back as QuotePart;
      expect(quote.text, 'the failing assertion');
      expect(quote.messageId, 'm2');
      expect(quote.role, 'assistant');
    });

    testWidgets('a quoted passage shows in the message', (
      WidgetTester tester,
    ) async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);
      await tester.pumpWidget(
        AuiRuntimeProvider(
          runtime: runtime,
          child: const MaterialApp(home: Scaffold(body: AssistantThread())),
        ),
      );
      await runtime.thread.send(content: <MessagePart>[
        const QuotePart(text: 'the failing assertion', role: 'assistant'),
        const TextPart('why does this fail?'),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('the failing assertion'), findsOneWidget);
      expect(find.text('why does this fail?'), findsOneWidget);
      expect(find.byIcon(Icons.format_quote), findsOneWidget);
    });
  });

  group('composer slots', () {
    testWidgets('a model picker and a quote preview drop into the composer', (
      WidgetTester tester,
    ) async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);
      String? quoted = 'the failing assertion';
      await tester.pumpWidget(
        AuiRuntimeProvider(
          runtime: runtime,
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) =>
                    AssistantComposer(
                      leading: const AssistantModelPicker(
                        models: <PickableModel>[
                          PickableModel(
                            id: 'gpt-5.6-luna',
                            name: 'gpt-5.6-luna',
                            family: 'gpt',
                            context: '126k',
                            price: r'$3 / M',
                          ),
                        ],
                        selectedId: 'gpt-5.6-luna',
                      ),
                      footer: quoted == null
                          ? null
                          : AssistantComposerQuotePreview(
                              text: quoted!,
                              onDismiss: () => setState(() => quoted = null),
                            ),
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('gpt-5.6-luna'), findsOneWidget);
      expect(find.text('the failing assertion'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.text('the failing assertion'), findsNothing);
    });
  });

  group('generative ui', () {
    testWidgets('renders the markdown component from the default library', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AuiGenerativeUI(
          component: 'Markdown',
          properties: <String, Object?>{'value': '# Title'},
        ),
      ));
      expect(find.text('Title'), findsOneWidget);
    });

    testWidgets('an unknown component falls through to the host', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AuiGenerativeUI(
          component: 'Unknown',
          fallback: Text('not supported'),
        ),
      ));
      expect(find.text('not supported'), findsOneWidget);
    });
  });

  group('sources', () {
    testWidgets('the pill counts and the cards expand', (
      WidgetTester tester,
    ) async {
      final List<bool> reports = <bool>[];
      await tester.pumpWidget(_wrap(
        AssistantSources(
          sources: const <SourceRef>[
            SourceRef(domain: 'docs.flutter.dev', title: 'Layouts in Flutter'),
            SourceRef(domain: 'dart.dev', title: 'Effective Dart'),
          ],
          onOpenChange: reports.add,
        ),
      ));
      expect(find.text('Sources'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Layouts in Flutter'), findsNothing);

      await tester.tap(find.text('Sources'));
      await tester.pump();
      expect(reports, <bool>[true]);
      expect(find.text('Layouts in Flutter'), findsOneWidget);
      expect(find.text('docs.flutter.dev'), findsOneWidget);
      // Both domains start with a lowercase d, so both glyphs read `D`.
      expect(find.text('D'), findsNWidgets(2));
    });
  });

  group('file tree', () {
    testWidgets('counts files and shows per-file diffs', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantFileTree(
          visibleCount: 3,
          totalAdditions: 42,
          totalDeletions: 7,
          nodes: <FileTreeNode>[
            FileTreeNode.folder(path: 'lib', name: 'lib', depth: 0),
            FileTreeNode(
              path: 'lib/main.dart',
              name: 'main.dart',
              depth: 1,
              additions: 30,
              deletions: 4,
            ),
            FileTreeNode(
              path: 'lib/theme.dart',
              name: 'theme.dart',
              depth: 1,
              additions: 12,
              deletions: 3,
            ),
            FileTreeNode(
              path: 'hidden.dart',
              name: 'hidden.dart',
              depth: 0,
            ),
          ],
        ),
      ));
      expect(find.text('3 files changed'), findsOneWidget);
      expect(find.text('+42'), findsOneWidget);
      expect(find.text('−7'), findsOneWidget);
      expect(find.text('lib'), findsOneWidget);
      expect(find.text('main.dart'), findsOneWidget);
      expect(find.text('+30'), findsOneWidget);
      expect(find.text('hidden.dart'), findsNothing);
    });
  });
}
