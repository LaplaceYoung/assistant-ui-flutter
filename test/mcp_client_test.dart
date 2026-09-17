import 'dart:convert';
import 'dart:io';

import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// A scripted MCP server over real HTTP: one POST per JSON-RPC message.
Future<(HttpServer, List<Map<String, Object?>>)> _serve(
  Map<String, Object?> Function(Map<String, Object?> message) handler, {
  bool sse = false,
}) async {
  final HttpServer server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final List<Map<String, Object?>> seen = <Map<String, Object?>>[];
  server.listen((HttpRequest request) async {
    final String body = await utf8.decoder.bind(request).join();
    final Map<String, Object?> message =
        jsonDecode(body) as Map<String, Object?>;
    seen.add(message);
    final Map<String, Object?> reply = handler(message);
    request.response.headers.set('mcp-session-id', 'session-1');
    if (sse) {
      request.response.headers
          .set(HttpHeaders.contentTypeHeader, 'text/event-stream');
      request.response.write('event: message\ndata: ${jsonEncode(reply)}\n\n');
    } else {
      request.response.headers
          .set(HttpHeaders.contentTypeHeader, 'application/json');
      request.response.write(jsonEncode(reply));
    }
    await request.response.close();
  });
  return (server, seen);
}

Map<String, Object?> _ok(Map<String, Object?> message, Object? result) =>
    <String, Object?>{'jsonrpc': '2.0', 'id': message['id'], 'result': result};

void main() {
  test('initialize negotiates and records the server info', () async {
    final (HttpServer server, List<Map<String, Object?>> seen) = await _serve(
      (Map<String, Object?> message) => message['method'] == 'initialize'
          ? _ok(message, <String, Object?>{
              'protocolVersion': '2025-06-18',
              'serverInfo': <String, Object?>{'name': 'demo', 'version': '2.1'},
            })
          : _ok(message, <String, Object?>{}),
    );
    addTearDown(() => server.close(force: true));

    final McpClient client = McpClient(
      transport: McpHttpTransport(
        url: 'http://127.0.0.1:${server.port}/mcp',
      ),
    );
    await client.initialize();

    expect(client.protocolVersion, '2025-06-18');
    expect(client.serverInfo!['name'], 'demo');
    expect(seen.first['method'], 'initialize');
    // The spec's ready notification follows the handshake.
    expect(seen.last['method'], 'notifications/initialized');
  });

  test('listTools follows pagination and keeps the schemas', () async {
    int calls = 0;
    final (HttpServer server, _) = await _serve((Map<String, Object?> m) {
      if (m['method'] == 'initialize') {
        return _ok(m, <String, Object?>{'protocolVersion': '2025-06-18'});
      }
      if (m['method'] == 'tools/list') {
        calls += 1;
        if (calls == 1) {
          return _ok(m, <String, Object?>{
            'tools': <Object?>[
              <String, Object?>{
                'name': 'search',
                'description': 'Search the docs',
                'inputSchema': <String, Object?>{
                  'type': 'object',
                  'properties': <String, Object?>{
                    'q': <String, Object?>{'type': 'string'},
                  },
                },
              },
            ],
            'nextCursor': 'page-2',
          });
        }
        return _ok(m, <String, Object?>{
          'tools': <Object?>[
            <String, Object?>{'name': 'fetch', 'description': 'Fetch a page'},
          ],
        });
      }
      return _ok(m, <String, Object?>{});
    });
    addTearDown(() => server.close(force: true));

    final McpClient client = McpClient(
      transport: McpHttpTransport(url: 'http://127.0.0.1:${server.port}/mcp'),
    );
    final List<McpTool> tools = await client.listTools(server: 'docs');

    expect(tools.map((McpTool t) => t.qualifiedName), <String>['docs__search', 'docs__fetch']);
    expect(tools.first.parameters['type'], 'object');
    expect(tools.first.description, 'Search the docs');
  });

  test('callTool flattens text blocks and surfaces isError', () async {
    final (HttpServer server, _) = await _serve((Map<String, Object?> m) {
      if (m['method'] == 'initialize') {
        return _ok(m, <String, Object?>{'protocolVersion': '2025-06-18'});
      }
      if (m['method'] == 'tools/call') {
        final Map<String, Object?> params =
            m['params']! as Map<String, Object?>;
        if (params['name'] == 'boom') {
          return _ok(m, <String, Object?>{
            'isError': true,
            'content': <Object?>[
              <String, Object?>{'type': 'text', 'text': 'disk full'},
            ],
          });
        }
        return _ok(m, <String, Object?>{
          'content': <Object?>[
            <String, Object?>{'type': 'text', 'text': 'first line'},
            <String, Object?>{'type': 'text', 'text': 'second line'},
          ],
        });
      }
      return _ok(m, <String, Object?>{});
    });
    addTearDown(() => server.close(force: true));

    final McpClient client = McpClient(
      transport: McpHttpTransport(url: 'http://127.0.0.1:${server.port}/mcp'),
    );
    expect(
      await client.callTool('search', args: <String, Object?>{'q': 'hooks'}),
      'first line\nsecond line',
    );
    await expectLater(
      client.callTool('boom'),
      throwsA(isA<McpException>().having(
        (McpException e) => e.message,
        'message',
        contains('disk full'),
      )),
    );
  });

  test('an event-stream reply is read like a JSON one', () async {
    final (HttpServer server, _) = await _serve(
      (Map<String, Object?> m) => m['method'] == 'initialize'
          ? _ok(m, <String, Object?>{'protocolVersion': '2025-06-18'})
          : _ok(m, <String, Object?>{
              'tools': <Object?>[
                <String, Object?>{'name': 'ping', 'description': 'Ping'},
              ],
            }),
      sse: true,
    );
    addTearDown(() => server.close(force: true));

    final McpClient client = McpClient(
      transport: McpHttpTransport(url: 'http://127.0.0.1:${server.port}/mcp'),
    );
    final List<McpTool> tools = await client.listTools();
    expect(tools.single.name, 'ping');
  });

  test('a JSON-RPC error becomes an McpException', () async {
    final (HttpServer server, _) = await _serve((Map<String, Object?> m) =>
        m['method'] == 'initialize'
            ? _ok(m, <String, Object?>{'protocolVersion': '2025-06-18'})
            : <String, Object?>{
                'jsonrpc': '2.0',
                'id': m['id'],
                'error': <String, Object?>{
                  'code': -32601,
                  'message': 'Method not found',
                },
              });
    addTearDown(() => server.close(force: true));

    final McpClient client = McpClient(
      transport: McpHttpTransport(url: 'http://127.0.0.1:${server.port}/mcp'),
    );
    await expectLater(
      client.listTools(),
      throwsA(isA<McpException>().having(
        (McpException e) => e.message,
        'message',
        'Method not found',
      )),
    );
  });

  test('the toolkit runs a model tool call through the server', () async {
    final List<Map<String, Object?>> calls = <Map<String, Object?>>[];
    final (HttpServer server, _) = await _serve((Map<String, Object?> m) {
      if (m['method'] == 'initialize') {
        return _ok(m, <String, Object?>{'protocolVersion': '2025-06-18'});
      }
      if (m['method'] == 'tools/list') {
        return _ok(m, <String, Object?>{
          'tools': <Object?>[
            <String, Object?>{
              'name': 'weather',
              'description': 'Read the weather',
              'inputSchema': <String, Object?>{'type': 'object'},
            },
          ],
        });
      }
      if (m['method'] == 'tools/call') {
        calls.add(m['params']! as Map<String, Object?>);
        return _ok(m, <String, Object?>{
          'content': <Object?>[
            <String, Object?>{'type': 'text', 'text': '21C and clear'},
          ],
        });
      }
      return _ok(m, <String, Object?>{});
    });
    addTearDown(() => server.close(force: true));

    final McpClient client = McpClient(
      transport: McpHttpTransport(url: 'http://127.0.0.1:${server.port}/mcp'),
    );
    final Toolkit toolkit = await client.toolkit(server: 'weather-api');
    final ToolDefinition tool = toolkit['weather-api__weather']!;

    expect(tool.description, 'Read the weather');
    expect(
      await tool.execute!(<String, Object?>{'city': 'Tokyo'}),
      '21C and clear',
    );
    expect(calls.single['name'], 'weather');
    expect((calls.single['arguments']! as Map<String, Object?>)['city'], 'Tokyo');
  });

  test('one broken server does not take the working ones down', () async {
    final (HttpServer good, _) = await _serve((Map<String, Object?> m) =>
        m['method'] == 'initialize'
            ? _ok(m, <String, Object?>{'protocolVersion': '2025-06-18'})
            : _ok(m, <String, Object?>{
                'tools': <Object?>[
                  <String, Object?>{'name': 'ping', 'description': 'Ping'},
                ],
              }));
    addTearDown(() => good.close(force: true));

    final McpServers servers = McpServers(<McpServerConfig>[
      McpServerConfig(
        id: 'a',
        name: 'docs',
        transport: 'http',
        url: 'http://127.0.0.1:${good.port}/mcp',
      ),
      // A stdio connector has no process to run in the browser.
      const McpServerConfig(
        id: 'b',
        name: 'local',
        transport: 'stdio',
        command: 'npx',
      ),
      // A dead endpoint must not stop the pass either.
      const McpServerConfig(
        id: 'c',
        name: 'down',
        transport: 'http',
        url: 'http://127.0.0.1:1/mcp',
      ),
    ]);

    final (Toolkit toolkit, List<(String, String)> failures) =
        await servers.connect();

    expect(toolkit.keys, contains('docs__ping'));
    expect(failures.map((f) => f.$1), containsAll(<String>['local', 'down']));
  });
}
