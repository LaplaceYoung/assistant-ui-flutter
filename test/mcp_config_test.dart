import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('mcp config', () {
    List<McpServerConfig> servers() => <McpServerConfig>[
          const McpServerConfig(
            id: 'fs',
            name: 'filesystem',
            command: 'npx -y @modelcontextprotocol/server-filesystem',
            status: McpConfigStatus.connected,
          ),
          const McpServerConfig(
            id: 'git',
            name: 'github',
            transport: 'sse',
            url: 'https://mcp.github.example/sse',
            status: McpConfigStatus.authRequired,
          ),
        ];

    testWidgets('lists connectors with their status and auth control', (
      WidgetTester tester,
    ) async {
      final List<String> authorized = <String>[];
      await tester.pumpWidget(_wrap(
        AssistantMcpConfig(
          servers: servers(),
          onAuthorize: authorized.add,
        ),
      ));
      expect(find.text('MCP servers'), findsOneWidget);
      expect(find.text('CONNECTORS'), findsOneWidget);
      expect(find.text('filesystem'), findsOneWidget);
      expect(find.text('Connected'), findsOneWidget);
      expect(find.text('Auth required'), findsOneWidget);
      // Connectors are app-defined, so they offer no remove control.
      expect(find.bySemanticsLabel('Remove filesystem'), findsNothing);

      await tester.tap(find.text('Authorize'));
      await tester.pump();
      expect(authorized, <String>['git']);
    });

    testWidgets('adds a custom server through the form', (
      WidgetTester tester,
    ) async {
      List<McpServerConfig>? latest;
      await tester.pumpWidget(_wrap(
        AssistantMcpConfig(
          servers: servers(),
          onChange: (List<McpServerConfig> next) => latest = next,
        ),
      ));
      expect(find.text('CUSTOM SERVERS'), findsOneWidget);
      expect(find.text('Add server'), findsOneWidget);

      await tester.tap(find.text('Add server'));
      await tester.pump();
      expect(find.text('name'), findsOneWidget);
      expect(find.text('transport'), findsOneWidget);

      // A stdio server without a command is refused.
      await tester.enterText(find.byType(TextField).first, 'notes');
      await tester.ensureVisible(find.text('Add'));
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(find.text('A stdio server needs a command.'), findsOneWidget);
      expect(latest, isNull);

      await tester.enterText(
        find.byType(TextField).last,
        'npx -y notes-mcp',
      );
      await tester.ensureVisible(find.text('Add'));
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(latest, isNotNull);
      expect(latest!.length, 3);
      expect(latest!.last.name, 'notes');
      expect(latest!.last.custom, isTrue);
      expect(latest!.last.status, McpConfigStatus.connecting);
    });

    testWidgets('a remote transport asks for an endpoint', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantMcpConfig(servers: <McpServerConfig>[]),
      ));
      await tester.tap(find.text('Add server'));
      await tester.pump();
      await tester.tap(find.text('http'));
      await tester.pump();
      expect(find.text('endpoint'), findsOneWidget);
      expect(find.text('command'), findsNothing);

      await tester.enterText(find.byType(TextField).first, 'remote');
      await tester.ensureVisible(find.text('Add'));
      await tester.tap(find.text('Add'));
      await tester.pump();
      expect(find.text('A remote server needs an endpoint.'), findsOneWidget);
    });

    testWidgets('a custom server can be removed', (
      WidgetTester tester,
    ) async {
      List<McpServerConfig>? latest;
      await tester.pumpWidget(_wrap(
        AssistantMcpConfig(
          onChange: (List<McpServerConfig> next) => latest = next,
          servers: <McpServerConfig>[
            const McpServerConfig(
              id: 'custom-1',
              name: 'notes',
              custom: true,
              command: 'npx -y notes-mcp',
            ),
          ],
        ),
      ));
      await tester.tap(find.bySemanticsLabel('Remove notes'));
      await tester.pump();
      expect(latest, isNotNull);
      expect(latest, isEmpty);
    });

    testWidgets('a failing server shows its error line', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrap(
        const AssistantMcpConfig(
          servers: <McpServerConfig>[
            McpServerConfig(
              id: 'broken',
              name: 'playwright',
              transport: 'sse',
              url: 'https://mcp.example/sse',
              status: McpConfigStatus.error,
            ),
          ],
        ),
      ));
      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Could not reach the server.'), findsOneWidget);
    });
  });
}
