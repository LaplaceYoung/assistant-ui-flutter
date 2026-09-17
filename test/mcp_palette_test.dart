import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

const List<McpServer> _servers = <McpServer>[
  McpServer(
    id: 'fs',
    name: 'filesystem',
    transport: 'stdio',
    status: McpServerStatus.connected,
    tools: <String>['read_file', 'write_file'],
  ),
  McpServer(
    id: 'ws',
    name: 'workspace-index',
    transport: 'http://127.0.0.1:7331/mcp',
    status: McpServerStatus.needsAuth,
    tools: <String>['search_code'],
  ),
  McpServer(
    id: 'pup',
    name: 'playwright',
    transport: 'sse',
    status: McpServerStatus.failed,
    tools: <String>['navigate'],
  ),
];

const List<PaletteCommand> _commands = <PaletteCommand>[
  PaletteCommand(
    id: 'new-thread',
    label: 'New thread',
    group: 'Thread',
    keys: <String>['⌘', 'N'],
  ),
  PaletteCommand(id: 'branch', label: 'Switch branch', group: 'Thread'),
  PaletteCommand(id: 'model', label: 'Pick a model', group: 'Runtime'),
  PaletteCommand(id: 'theme', label: 'Toggle theme', group: 'View'),
];

/// Whether any box on screen is filled with [color] — the status dots are the
/// only 6px circles in this panel.
bool _hasDot(WidgetTester tester, Color color) {
  return tester.widgetList<Container>(find.byType(Container)).any(
        (Container container) =>
            container.decoration is BoxDecoration &&
            (container.decoration! as BoxDecoration).color == color,
      );
}

void main() {
  group('mcp server panel', () {
    testWidgets('counts what is connected', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(
        const AssistantMcpServerPanel(servers: _servers),
      ));
      expect(find.text('Servers'), findsOneWidget);
      expect(find.text('1 of 3 connected'), findsOneWidget);
      expect(find.text('filesystem'), findsOneWidget);
      expect(find.text('2 tools'), findsOneWidget);
    });

    testWidgets('carries the status in a dot and in semantics', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(_wrap(
        const AssistantMcpServerPanel(servers: _servers),
      ));
      const AssistantTheme light = AssistantTheme.light;
      expect(_hasDot(tester, light.success), isTrue);
      expect(_hasDot(tester, const Color(0xFFF59E0B)), isTrue);
      expect(_hasDot(tester, light.destructive), isTrue);
      // The dot is decorative, so the status word has to be announced.
      expect(find.bySemanticsLabel('needs auth'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('tapping a row reports it and expands its detail', (
      WidgetTester tester,
    ) async {
      final List<String> toggles = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantMcpServerPanel(
          servers: _servers,
          onToggle: toggles.add,
        ),
      ));
      expect(find.text('stdio'), findsNothing);

      await tester.tap(find.text('filesystem'));
      await tester.pump();
      expect(toggles, <String>['fs']);
    });

    testWidgets('an expanded server shows its transport and tools', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantMcpServerPanel(servers: _servers, expandedId: 'fs'),
      ));
      expect(find.text('stdio'), findsOneWidget);
      expect(find.text(' · connected'), findsOneWidget);
      expect(find.text('read_file'), findsOneWidget);
      expect(find.text('write_file'), findsOneWidget);
      // The other servers stay closed.
      expect(find.text('search_code'), findsNothing);
    });

    testWidgets('authorize is offered only for a server that needs it', (
      WidgetTester tester,
    ) async {
      final List<String> authorized = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantMcpServerPanel(
          servers: _servers,
          expandedId: 'ws',
          onToggle: (String id) {},
          onAuthorize: authorized.add,
        ),
      ));
      expect(find.text('Authorize'), findsOneWidget);
      await tester.tap(find.text('Authorize'));
      await tester.pump();
      expect(authorized, <String>['ws']);

      await tester.pumpWidget(_wrap(
        const AssistantMcpServerPanel(servers: _servers, expandedId: 'fs'),
      ));
      expect(find.text('Authorize'), findsNothing);
    });
  });

  group('command palette', () {
    testWidgets('filters as the query changes and explains a miss', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantCommandPalette(commands: _commands, onRun: _noop),
      ));
      expect(find.text('Thread'), findsOneWidget);
      expect(find.text('Runtime'), findsOneWidget);
      expect(find.text('New thread'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'the');
      await tester.pump();
      expect(find.text('New thread'), findsNothing);
      expect(find.text('Switch branch'), findsNothing);
      expect(find.text('Toggle theme'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No command matches “zzz”'), findsOneWidget);
    });

    testWidgets('lists a group once even when matches are split', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantCommandPalette(commands: _commands, onRun: _noop),
      ));
      await tester.enterText(find.byType(TextField), 'e');
      await tester.pump();
      // Thread (two matches) still renders one header.
      expect(find.text('Thread'), findsOneWidget);
    });

    testWidgets('arrows walk the list and enter runs the highlight', (
      WidgetTester tester,
    ) async {
      final List<String> ran = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantCommandPalette(
          commands: _commands,
          onRun: ran.add,
          autoFocus: true,
        ),
      ));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      // starts on New thread, down -> branch, down -> model.
      expect(ran, <String>['model']);
    });

    testWidgets('arrows wrap around the filtered list', (
      WidgetTester tester,
    ) async {
      final List<String> active = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantCommandPalette(
          commands: _commands,
          onRun: _noop,
          onActiveChange: active.add,
          autoFocus: true,
        ),
      ));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      // Up from the first entry lands on the last.
      expect(active.last, 'theme');
    });

    testWidgets('a tap runs the command and the caps are drawn', (
      WidgetTester tester,
    ) async {
      final List<String> ran = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantCommandPalette(commands: _commands, onRun: ran.add),
      ));
      expect(find.text('⌘'), findsOneWidget);
      expect(find.text('N'), findsOneWidget);

      await tester.tap(find.text('Pick a model'));
      await tester.pump();
      expect(ran, <String>['model']);
    });

    testWidgets('a bound query drives the field', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantCommandPalette(
          commands: _commands,
          query: 'model',
          onRun: _noop,
        ),
      ));
      expect(find.text('Pick a model'), findsOneWidget);
      expect(find.text('New thread'), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'model',
      );
    });
  });
}

void _noop(String id) {}
