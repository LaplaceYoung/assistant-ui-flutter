import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../components/mcp_config.dart';
import '../core/adapters.dart';

/// One tool advertised by a server.
class McpTool {
  const McpTool({
    required this.server,
    required this.name,
    required this.description,
    this.parameters = const <String, Object?>{},
  });

  final String server;
  final String name;
  final String description;

  /// JSON Schema of the arguments, passed through as the server sent it.
  final Map<String, Object?> parameters;

  /// The name the runtime registers: `server__tool`, so two servers can both
  /// expose `search` without colliding.
  String get qualifiedName => '${server}__$name';
}

/// A resource or prompt the server exposes, kept for the config panel.
class McpResource {
  const McpResource({required this.uri, required this.name, this.mimeType});

  final String uri;
  final String name;
  final String? mimeType;
}

/// The transport contract, so tests can drive the client without a socket.
abstract class McpTransport {
  Future<Map<String, Object?>> call(Map<String, Object?> message);

  Future<void> close();
}

/// Streamable HTTP transport: one POST per JSON-RPC message, with the reply
/// coming back as JSON or as an SSE stream the transport reads to completion.
class McpHttpTransport implements McpTransport {
  McpHttpTransport({
    required this.url,
    this.headers = const <String, String>{},
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String url;
  final Map<String, String> headers;
  final http.Client _client;

  String? _sessionId;

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> message) async {
    final http.Response response = await _client.post(
      Uri.parse(url),
      headers: <String, String>{
        'content-type': 'application/json',
        'accept': 'application/json, text/event-stream',
        if (_sessionId != null) 'mcp-session-id': _sessionId!,
        ...headers,
      },
      body: jsonEncode(message),
    );
    final String? session = response.headers['mcp-session-id'];
    if (session != null) _sessionId = session;

    if (response.statusCode >= 400) {
      throw McpException(
        'HTTP ${response.statusCode} from $url: ${response.body}',
      );
    }
    final String contentType = response.headers['content-type'] ?? '';
    if (contentType.contains('text/event-stream')) {
      // Read the stream to the message carrying the id we asked for.
      final Object? id = message['id'];
      for (final String line in const LineSplitter().convert(response.body)) {
        if (!line.startsWith('data:')) continue;
        final Object? decoded = jsonDecode(line.substring(5).trim());
        if (decoded is Map<String, Object?> && decoded['id'] == id) {
          return decoded;
        }
      }
      throw McpException('No reply for $id in the event stream from $url');
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is Map<String, Object?>) return decoded;
    throw McpException('Unexpected payload from $url: ${response.body}');
  }

  @override
  Future<void> close() async => _client.close();
}

/// Raised for transport failures and JSON-RPC errors alike.
class McpException implements Exception {
  const McpException(this.message);

  final String message;

  @override
  String toString() => 'McpException: $message';
}

/// A Model Context Protocol client: initialize, list tools, call them.
///
/// This is the Dart counterpart of `@assistant-ui/react-mcp`'s client half.
/// It speaks JSON-RPC 2.0 over the streamable HTTP transport; stdio servers
/// are out of scope here because the browser is the target platform.
class McpClient {
  McpClient({required this.transport, this.clientName = 'assistant-ui'});

  final McpTransport transport;
  final String clientName;

  int _nextId = 1;
  String? _protocolVersion;
  Map<String, Object?>? _serverInfo;

  String? get protocolVersion => _protocolVersion;
  Map<String, Object?>? get serverInfo => _serverInfo;

  /// Opens the session. Safe to call more than once.
  Future<void> initialize() async {
    if (_protocolVersion != null) return;
    final Map<String, Object?> reply = await _call(
      'initialize',
      <String, Object?>{
        'protocolVersion': '2025-06-18',
        'capabilities': <String, Object?>{
          'tools': <String, Object?>{},
          'resources': <String, Object?>{},
        },
        'clientInfo': <String, Object?>{'name': clientName, 'version': '1.0.0'},
      },
    );
    final Map<String, Object?> result = _resultOf(reply);
    _protocolVersion = result['protocolVersion'] as String?;
    _serverInfo = result['serverInfo'] as Map<String, Object?>?;
    // The spec asks for this notification once the session is up.
    await _notify('notifications/initialized');
  }

  /// Every tool the server advertises, following pagination cursors.
  Future<List<McpTool>> listTools({String server = 'mcp'}) async {
    await initialize();
    final List<McpTool> tools = <McpTool>[];
    String? cursor;
    do {
      final Map<String, Object?> reply = await _call(
        'tools/list',
        <String, Object?>{if (cursor != null) 'cursor': cursor},
      );
      final Map<String, Object?> result = _resultOf(reply);
      for (final Object? entry in (result['tools'] as List<Object?>?) ??
          const <Object?>[]) {
        if (entry is! Map<String, Object?>) continue;
        tools.add(
          McpTool(
            server: server,
            name: entry['name']! as String,
            description: (entry['description'] as String?) ?? '',
            parameters: (entry['inputSchema'] as Map<String, Object?>?) ??
                const <String, Object?>{},
          ),
        );
      }
      cursor = result['nextCursor'] as String?;
    } while (cursor != null);
    return tools;
  }

  /// Resources the server exposes, for the connectors panel.
  Future<List<McpResource>> listResources() async {
    await initialize();
    final Map<String, Object?> reply = await _call('resources/list', null);
    final Map<String, Object?> result = _resultOf(reply);
    return <McpResource>[
      for (final Object? entry in (result['resources'] as List<Object?>?) ??
          const <Object?>[])
        if (entry is Map<String, Object?>)
          McpResource(
            uri: entry['uri']! as String,
            name: (entry['name'] as String?) ?? entry['uri']! as String,
            mimeType: entry['mimeType'] as String?,
          ),
    ];
  }

  /// Runs a tool and returns its content, flattened to text when the server
  /// answers with content blocks.
  Future<Object?> callTool(
    String name, {
    Map<String, Object?> args = const <String, Object?>{},
  }) async {
    await initialize();
    final Map<String, Object?> reply = await _call(
      'tools/call',
      <String, Object?>{'name': name, 'arguments': args},
    );
    if (reply['error'] != null) {
      throw McpException(_errorOf(reply));
    }
    final Map<String, Object?> result = _resultOf(reply);
    if (result['isError'] == true) {
      throw McpException(_textOf(result) ?? 'Tool $name failed');
    }
    return _textOf(result) ?? result;
  }

  /// The runtime toolkit for these tools, ready for `LocalRuntimeOptions`.
  ///
  /// Each entry executes against the server, so a model tool call round-trips
  /// through the same client the panel lists.
  Future<Toolkit> toolkit({String server = 'mcp'}) async {
    final List<McpTool> tools = await listTools(server: server);
    return <String, ToolDefinition>{
      for (final McpTool tool in tools)
        tool.qualifiedName: ToolDefinition(
          description: tool.description,
          parameters: tool.parameters,
          execute: (Map<String, Object?> args) =>
              callTool(tool.name, args: args),
          renderText: ToolRenderText(
            running: 'Calling ${tool.name} on $server',
            complete: '${tool.name} finished',
          ),
        ),
    };
  }

  Future<void> close() => transport.close();

  Future<Map<String, Object?>> _call(
    String method,
    Map<String, Object?>? params,
  ) async {
    final Map<String, Object?> reply = await transport.call(
      <String, Object?>{
        'jsonrpc': '2.0',
        'id': _nextId++,
        'method': method,
        if (params != null) 'params': params,
      },
    );
    if (reply['error'] != null) throw McpException(_errorOf(reply));
    return reply;
  }

  Future<void> _notify(String method) async {
    await transport.call(<String, Object?>{
      'jsonrpc': '2.0',
      'method': method,
    });
  }

  Map<String, Object?> _resultOf(Map<String, Object?> reply) =>
      (reply['result'] as Map<String, Object?>?) ?? const <String, Object?>{};

  String _errorOf(Map<String, Object?> reply) {
    final Object? error = reply['error'];
    if (error is Map<String, Object?>) {
      return (error['message'] as String?) ?? error.toString();
    }
    return error.toString();
  }

  /// Joins the text blocks of a tool result.
  String? _textOf(Map<String, Object?> result) {
    final Object? content = result['content'];
    if (content is! List<Object?>) return null;
    final List<String> texts = <String>[
      for (final Object? block in content)
        if (block is Map<String, Object?> && block['type'] == 'text')
          (block['text'] as String?) ?? '',
    ];
    if (texts.isEmpty) return null;
    return texts.join('\n');
  }
}

/// Every configured server behind one client, yielding one merged toolkit and
/// the failure list the config panel shows.
class McpServers {
  const McpServers(this.servers);

  final List<McpServerConfig> servers;

  /// The transport for a configured server: HTTP for `http` / `sse`, and a
  /// clear failure for `stdio`, which needs a process the browser has not got.
  static McpTransport _transportFor(McpServerConfig config) {
    if (config.transport == 'stdio') {
      return _UnsupportedTransport(
        'stdio servers need a local process; the hosted transport is http',
      );
    }
    return McpHttpTransport(url: config.url, headers: config.headers);
  }

  /// Builds a client per enabled server and merges their tools. Servers that
  /// fail to answer are reported instead of throwing, so one bad endpoint does
  /// not take the rest down.
  Future<(Toolkit, List<(String, String)>)> connect({
    McpTransport Function(McpServerConfig config)? transportFor,
  }) async {
    final Toolkit toolkit = <String, ToolDefinition>{};
    final List<(String, String)> failures = <(String, String)>[];
    for (final McpServerConfig config in servers) {
      // `error` connectors stay listed but are not dialled again by this pass.
      if (config.status == McpConfigStatus.error) continue;
      final McpClient client = McpClient(
        transport: transportFor?.call(config) ?? _transportFor(config),
      );
      try {
        toolkit.addAll(await client.toolkit(server: config.name));
      } on Object catch (error) {
        failures.add((config.name, error.toString()));
      }
    }
    return (toolkit, failures);
  }
}

/// Collects text from a server that pushes progress notifications.
Stream<String> mcpProgress(Stream<Map<String, Object?>> messages) =>
    messages.where((Map<String, Object?> m) => m['method'] == 'notifications/progress').map(
          (Map<String, Object?> m) =>
              (((m['params'] as Map<String, Object?>?) ??
                          const <String, Object?>{})['message'] ??
                      '')
                  .toString(),
        );

/// A transport that always fails, carrying the reason for the failures list.
class _UnsupportedTransport implements McpTransport {
  const _UnsupportedTransport(this.reason);

  final String reason;

  @override
  Future<Map<String, Object?>> call(Map<String, Object?> message) async =>
      throw McpException(reason);

  @override
  Future<void> close() async {}
}
