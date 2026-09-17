import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/abort.dart';
import '../core/adapters.dart';
import '../core/message.dart';
import '../core/message_part.dart';

/// Raised for transport failures and graph-side errors alike.
class LangGraphException implements Exception {
  const LangGraphException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() =>
      'LangGraphException${code == null ? '' : '($code)'}: $message';
}

/// One server-sent event from a run: the `event:` name and its `data:` payload.
class LangGraphEvent {
  const LangGraphEvent(this.event, this.data);

  /// `messages/partial`, `messages/complete`, `updates`, `values`, `custom`,
  /// `metadata`, `error` or `end`.
  final String event;
  final Object? data;

  bool get isError => event == 'error';
}

/// The LangGraph Platform client: threads, run streaming and thread state.
class LangGraphClient {
  LangGraphClient({
    required String baseUrl,
    this.apiKey,
    this.headers = const <String, String>{},
    http.Client? client,
  })  : baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _client = client ?? http.Client();

  final String baseUrl;
  final String? apiKey;
  final Map<String, String> headers;
  final http.Client _client;

  Map<String, String> get _headers => <String, String>{
        'content-type': 'application/json',
        'accept': 'application/json, text/event-stream',
        if (apiKey != null) 'x-api-key': apiKey!,
        ...headers,
      };

  /// Creates a thread and returns its id.
  Future<String> createThread({Map<String, Object?>? metadata}) async {
    final http.Response response = await _client.post(
      Uri.parse('$baseUrl/threads'),
      headers: _headers,
      body: jsonEncode(<String, Object?>{
        if (metadata != null) 'metadata': metadata,
      }),
    );
    final Map<String, Object?> body = _decode(response);
    final Object? id = body['thread_id'];
    if (id is! String) {
      throw const LangGraphException('No thread_id in the reply');
    }
    return id;
  }

  /// Streams a run. The default modes match upstream: messages, updates,
  /// custom.
  Stream<LangGraphEvent> streamRun({
    required String threadId,
    required String assistantId,
    Object? input,
    List<String> streamMode = const <String>['messages', 'updates', 'custom'],
    Object? command,
    String? checkpointId,
    Object? config,
    String onDisconnect = 'cancel',
    AbortSignal? abortSignal,
  }) {
    final StreamController<LangGraphEvent> controller =
        StreamController<LangGraphEvent>();

    Future<void> pump() async {
      try {
        final http.Request request = http.Request(
          'POST',
          Uri.parse('$baseUrl/threads/$threadId/runs/stream'),
        )
          ..headers.addAll(_headers)
          ..body = jsonEncode(<String, Object?>{
            'assistant_id': assistantId,
            'input': input,
            'stream_mode': streamMode,
            'on_disconnect': onDisconnect,
            if (command != null) 'command': command,
            if (checkpointId != null)
              'checkpoint': <String, Object?>{'checkpoint_id': checkpointId},
            if (config != null) 'config': config,
          });
        final http.StreamedResponse response = await _client.send(request);
        if (response.statusCode >= 400) {
          final String body = await response.stream.bytesToString();
          throw LangGraphException(
            'HTTP ${response.statusCode} from the run endpoint: $body',
          );
        }
        final Stream<String> lines = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        String? name;
        final List<String> dataLines = <String>[];
        void flush() {
          if (name == null && dataLines.isEmpty) return;
          final String payload = dataLines.join('\n');
          if (payload.trim() == '[DONE]') {
            name = null;
            dataLines.clear();
            return;
          }
          Object? decoded;
          try {
            decoded = jsonDecode(payload);
          } on FormatException {
            decoded = payload;
          }
          controller.add(LangGraphEvent(name ?? 'message', decoded));
          name = null;
          dataLines.clear();
        }

        await for (final String line in lines) {
          if (abortSignal?.isAborted ?? false) break;
          if (line.isEmpty) {
            flush();
            continue;
          }
          if (line.startsWith('event:')) {
            name = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            dataLines.add(line.substring(5).trimLeft());
          }
        }
        flush();
      } on Object catch (error, stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      } finally {
        if (!controller.isClosed) await controller.close();
      }
    }

    unawaited(pump());
    return controller.stream;
  }

  /// Reads the thread's current state.
  Future<Map<String, Object?>> getThreadState(String threadId) async {
    final http.Response response = await _client.get(
      Uri.parse('$baseUrl/threads/$threadId/state'),
      headers: _headers,
    );
    return _decode(response);
  }

  void close() => _client.close();

  Map<String, Object?> _decode(http.Response response) {
    if (response.statusCode >= 400) {
      throw LangGraphException(
        'HTTP ${response.statusCode}: ${response.body}',
      );
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw LangGraphException(
        'Expected an object, got ${response.body}',
      );
    }
    return decoded;
  }
}

/// Parses a possibly-incomplete JSON object, the way a streaming tool-call
/// chunk needs: whole JSON first, then growing prefixes, then nothing.
Object? parsePartialJsonObject(String raw) {
  if (raw.isEmpty) return null;
  try {
    return jsonDecode(raw);
  } on FormatException {
    // fall through to prefix probing
  }
  for (int end = raw.length - 1; end > 0; end--) {
    final String candidate = raw.substring(0, end);
    try {
      final Object? value = jsonDecode(candidate);
      if (value is Map<String, Object?>) return value;
    } on FormatException {
      continue;
    }
  }
  return null;
}

/// Merges a LangGraph message chunk into the message already accumulated,
/// following `appendLangChainChunk`: text concatenates, thinking and reasoning
/// concatenate, and tool-call arguments concatenate into `partial_json`.
Map<String, Object?> langGraphAppendChunk(
  Map<String, Object?>? prev,
  Map<String, Object?> curr,
) {
  final bool isChunk = curr['type'] == 'AIMessageChunk';
  if (!isChunk) {
    if (prev?['type'] == 'ai' && curr['type'] == 'ai') {
      return _carryStreamedToolArgs(prev!, curr);
    }
    return curr;
  }

  Map<String, Object?> base;
  if (prev == null || prev['type'] != 'ai') {
    final Map<String, Object?> seeded = Map<String, Object?>.from(curr)
      ..remove('tool_call_chunks');
    if (curr['id'] == null) seeded.remove('id');
    base = seeded
      ..['type'] = 'ai'
      ..['content'] = <Object?>[];
    if (curr['content'] is! List<Object?>) {
      return base
        ..['content'] = curr['content'] is String ? curr['content'] : <Object?>[]
        ..['tool_calls'] = <Map<String, Object?>>[
          for (final Object? chunk in _listOf(curr['tool_call_chunks']))
            if (chunk is Map<String, Object?>) _chunkToToolCall(chunk),
        ];
    }
  } else {
    base = prev;
  }

  final List<Object?> content = <Object?>[
    if (base['content'] is String)
      <String, Object?>{'type': 'text', 'text': base['content']}
    else
      for (final Object? block in _listOf(base['content'])) block,
  ];

  final Object? incoming = curr['content'];
  if (incoming is String) {
    final int last = content.length - 1;
    final Object? tail = last >= 0 ? content[last] : null;
    if (tail is Map<String, Object?> && tail['type'] == 'text') {
      content[last] = <String, Object?>{
        ...tail,
        'text': '${tail['text'] ?? ''}$incoming',
      };
    } else {
      content.add(<String, Object?>{'type': 'text', 'text': incoming});
    }
  } else if (incoming is List<Object?>) {
    for (final Object? item in incoming) {
      if (item is! Map<String, Object?>) continue;
      final String? type = item['type'] as String?;
      if (type == null) continue;
      switch (type) {
        case 'text':
        case 'text_delta':
          final String text = (item['text'] as String?) ?? '';
          final int index = _findByIndex(content, item);
          final Object? existing = _at(content, index);
          if (existing is Map<String, Object?> && existing['type'] == 'text') {
            content[index] = <String, Object?>{
              ...existing,
              ...item,
              'type': 'text',
              'text': '${existing['text'] ?? ''}$text',
            };
          } else if (text.isNotEmpty) {
            content.add(<String, Object?>{...item, 'type': 'text', 'text': text});
          }
        case 'thinking':
          final int index = _findByIndex(content, item);
          final Object? existing = _at(content, index);
          if (existing is Map<String, Object?> && existing['type'] == 'thinking') {
            content[index] = <String, Object?>{
              ...existing,
              ...item,
              'thinking':
                  '${existing['thinking'] ?? ''}${item['thinking'] ?? ''}',
              if ((existing['signature'] ?? item['signature']) != null)
                'signature':
                    '${existing['signature'] ?? ''}${item['signature'] ?? ''}',
            };
          } else {
            content.add(<String, Object?>{...item, 'thinking': item['thinking'] ?? ''});
          }
        case 'reasoning':
          final int index = _findByIndex(content, item);
          final Object? existing = _at(content, index);
          if (existing is Map<String, Object?> && existing['type'] == 'reasoning') {
            content[index] = <String, Object?>{
              ...existing,
              ...item,
              'reasoning':
                  '${existing['reasoning'] ?? ''}${item['reasoning'] ?? ''}',
            };
          } else {
            content.add(item);
          }
        case 'tool_use':
        case 'input_json_delta':
          // Streamed through `tool_call_chunks` instead.
          break;
        default:
          final int index = _findByIndex(content, item);
          final Object? existing = _at(content, index);
          if (existing is Map<String, Object?>) {
            content[index] = <String, Object?>{
              ...existing,
              for (final MapEntry<String, Object?> entry in item.entries)
                if (entry.value != null) entry.key: entry.value,
            };
          } else {
            content.add(item);
          }
      }
    }
  }

  final List<Map<String, Object?>> toolCalls = <Map<String, Object?>>[
    for (final Object? call in _listOf(base['tool_calls']))
      if (call is Map<String, Object?>) call,
  ];
  for (final Object? raw in _listOf(curr['tool_call_chunks'])) {
    if (raw is! Map<String, Object?>) continue;
    int index = toolCalls.indexWhere(
      (Map<String, Object?> call) =>
          call['id'] != null &&
          call['id'] != '' &&
          call['id'] == raw['id'],
    );
    if (index == -1 && raw['index'] != null) {
      index = toolCalls.indexWhere(
        (Map<String, Object?> call) =>
            call['index'] == raw['index'] &&
            ((call['id'] ?? '') == '' || (raw['id'] ?? '') == ''),
      );
    }
    if (index == -1) {
      toolCalls.add(_chunkToToolCall(raw));
      continue;
    }
    final Map<String, Object?> existing = toolCalls[index];
    final String partial =
        '${existing['partial_json'] ?? ''}${raw['args'] ?? raw['args_json'] ?? ''}';
    toolCalls[index] = <String, Object?>{
      ...raw,
      ...existing,
      'id': (existing['id'] as String?)?.isNotEmpty == true
          ? existing['id']
          : raw['id'],
      'name': (existing['name'] as String?)?.isNotEmpty == true
          ? existing['name']
          : raw['name'],
      'partial_json': partial,
      'args': parsePartialJsonObject(partial) ??
          existing['args'] ??
          <String, Object?>{},
    };
  }

  return <String, Object?>{
    ...base,
    'content': content,
    'tool_calls': toolCalls,
  };
}

/// Keeps the streamed `partial_json` when a complete AI message arrives with
/// parsed `args` only, so argument text stays a prefix of what streamed.
Map<String, Object?> _carryStreamedToolArgs(
  Map<String, Object?> prev,
  Map<String, Object?> curr,
) {
  final List<Map<String, Object?>> previous = <Map<String, Object?>>[
    for (final Object? call in _listOf(prev['tool_calls']))
      if (call is Map<String, Object?>) call,
  ];
  final List<Object?> incoming = _listOf(curr['tool_calls']);
  if (previous.isEmpty || incoming.isEmpty) return curr;
  bool changed = false;
  final List<Object?> merged = <Object?>[
    for (final Object? call in incoming)
      if (call is! Map<String, Object?>)
        call
      else if (call['partial_json'] != null)
        call
      else
        () {
          final Map<String, Object?> match = previous.firstWhere(
            (Map<String, Object?> candidate) =>
                candidate['id'] != null && candidate['id'] == call['id'],
            orElse: () => <String, Object?>{},
          );
          final Object? streamed = match['partial_json'];
          if (streamed == null) return call;
          changed = true;
          return <String, Object?>{...call, 'partial_json': streamed};
        }(),
  ];
  return changed
      ? <String, Object?>{...curr, 'tool_calls': merged}
      : curr;
}

Map<String, Object?> _chunkToToolCall(Map<String, Object?> chunk) {
  final String partial =
      '${chunk['args'] ?? chunk['args_json'] ?? ''}';
  return <String, Object?>{
    ...chunk,
    'partial_json': partial,
    'args': parsePartialJsonObject(partial) ?? <String, Object?>{},
  };
}

/// Finds the block a chunked item belongs to: by `index` when the server sends
/// one, otherwise the tail. Returns -1 when there is nothing to merge into, so
/// the caller appends instead.
int _findByIndex(List<Object?> content, Map<String, Object?> item) {
  if (content.isEmpty) return -1;
  final Object? index = item['index'];
  if (index == null) return content.length - 1;
  for (int i = 0; i < content.length; i++) {
    final Object? block = content[i];
    if (block is Map<String, Object?> && block['index'] == index) return i;
  }
  return -1;
}

/// The block at [index], or null when there is none.
Object? _at(List<Object?> content, int index) =>
    index < 0 || index >= content.length ? null : content[index];

/// The id-keyed accumulator: messages upsert by id, `remove` deletes, and
/// `__remove_all__` clears everything, mirroring the server's reducer.
class LangGraphMessageAccumulator {
  LangGraphMessageAccumulator({
    List<Map<String, Object?>> initialMessages =
        const <Map<String, Object?>>[],
  }) {
    addMessages(initialMessages);
  }

  static const String removeAllSentinel = '__remove_all__';

  final Map<String, Map<String, Object?>> _messages =
      <String, Map<String, Object?>>{};
  int _generated = 0;
  int _version = 0;

  /// Bumped on every change, so a view can rebuild only when it moved.
  int get version => _version;

  List<Map<String, Object?>> get messages =>
      List<Map<String, Object?>>.unmodifiable(_messages.values);

  Map<String, Object?>? byId(String id) => _messages[id];

  List<Map<String, Object?>> addMessages(List<Map<String, Object?>> incoming) {
    for (Map<String, Object?> raw in incoming) {
      final Map<String, Object?> message = raw['id'] == null
          ? <String, Object?>{...raw, 'id': 'generated-${_generated++}'}
          : raw;
      final String id = message['id']! as String;
      if (message['type'] == 'remove') {
        if (id == removeAllSentinel) {
          _messages.clear();
        } else {
          _messages.remove(id);
        }
        _version++;
        continue;
      }
      _messages[id] = langGraphAppendChunk(_messages[id], message);
      _version++;
    }
    return messages;
  }

  void clear() {
    _messages.clear();
    _version++;
  }
}

/// Reads the message list out of an `updates` or `values` payload: node
/// outputs carry `messages`, and a bare payload may be the list itself.
List<Map<String, Object?>> langGraphMessagesOf(Object? payload) {
  if (payload is List<Object?>) {
    return <Map<String, Object?>>[
      for (final Object? entry in payload)
        if (entry is Map<String, Object?>) entry,
    ];
  }
  if (payload is Map<String, Object?>) {
    if (payload['messages'] is List<Object?>) {
      return langGraphMessagesOf(payload['messages']);
    }
    // Node-keyed updates: {"agent": {"messages": [...]}}.
    final List<Map<String, Object?>> collected = <Map<String, Object?>>[];
    for (final Object? value in payload.values) {
      collected.addAll(langGraphMessagesOf(value));
    }
    return collected;
  }
  return const <Map<String, Object?>>[];
}

/// The interrupts a graph parked on, when an update carries `__interrupt__`.
List<Map<String, Object?>> langGraphInterruptsOf(Object? payload) {
  final List<Map<String, Object?>> found = <Map<String, Object?>>[];
  void walk(Object? value) {
    if (value is List<Object?>) {
      for (final Object? entry in value) {
        walk(entry);
      }
      return;
    }
    if (value is! Map<String, Object?>) return;
    final Object? interrupts = value['__interrupt__'];
    if (interrupts is List<Object?>) {
      for (final Object? entry in interrupts) {
        if (entry is Map<String, Object?>) found.add(entry);
      }
    }
    for (final Object? nested in value.values) {
      walk(nested);
    }
  }

  walk(payload);
  return found;
}

/// Turns one LangChain message into parts. `tool` messages return a marker
/// carrying their id and payload, for [applyLangChainToolResult] to attach.
List<MessagePart> langChainMessageToParts(Map<String, Object?> message) {
  final String type = (message['type'] ?? message['role'] ?? '').toString();
  switch (type) {
    case 'system':
      return <MessagePart>[TextPart(_stringContent(message['content']))];
    case 'human':
    case 'user':
      return _contentToParts(message['content']);
    case 'ai':
    case 'assistant':
    case 'AIMessageChunk':
      final List<MessagePart> parts = <MessagePart>[];
      final Object? reasoning = _additional(message, 'reasoning');
      if (reasoning is String && reasoning.isNotEmpty) {
        parts.add(ReasoningPart(reasoning));
      }
      parts.addAll(_contentToParts(message['content']));
      for (final Object? output in _listOf(_additional(message, 'tool_outputs'))) {
        if (output is String) parts.add(TextPart(output));
      }
      for (final Object? call in _listOf(message['tool_calls'])) {
        if (call is! Map<String, Object?>) continue;
        parts.add(
          ToolCallPart(
            toolCallId: (call['id'] as String?) ??
                'call-${parts.length}',
            toolName: (call['name'] as String?) ?? 'tool',
            args: call['args'] ??
                parsePartialJsonObject((call['partial_json'] as String?) ?? ''),
          ),
        );
      }
      return parts;
    default:
      return _contentToParts(message['content']);
  }
}

/// The id, content and error flag of a `tool` message.
({String toolCallId, Object? content, bool isError})? langChainToolResult(
  Map<String, Object?> message,
) {
  if (message['type'] != 'tool') return null;
  final Object? id = message['tool_call_id'];
  if (id is! String) return null;
  return (
    toolCallId: id,
    content: message['content'],
    isError: message['status'] == 'error',
  );
}

/// Attaches a tool result to the call it answers.
List<MessagePart> applyLangChainToolResult(
  List<MessagePart> parts,
  Map<String, Object?> message,
) {
  final ({String toolCallId, Object? content, bool isError})? result =
      langChainToolResult(message);
  if (result == null) return parts;
  return <MessagePart>[
    for (final MessagePart part in parts)
      if (part is ToolCallPart && part.toolCallId == result.toolCallId)
        ToolCallPart(
          toolCallId: part.toolCallId,
          toolName: part.toolName,
          args: part.args,
          result: result.content,
          isError: result.isError,
        )
      else
        part,
  ];
}

/// The wire message a thread message turns into.
Map<String, Object?> threadMessageToLangChain(ThreadMessage message) {
  final String type = switch (message.role) {
    MessageRole.user => 'human',
    MessageRole.system => 'system',
    MessageRole.assistant => 'ai',
  };
  final List<Object?> content = <Object?>[];
  final List<Map<String, Object?>> toolCalls = <Map<String, Object?>>[];
  for (final MessagePart part in message.content) {
    switch (part) {
      case TextPart():
        content.add(<String, Object?>{'type': 'text', 'text': part.text});
      case ImagePart():
        content.add(<String, Object?>{'type': 'image', 'image': part.image});
      case FilePart():
        content.add(<String, Object?>{
          'type': 'file',
          'data': part.data,
          'mime_type': part.mimeType,
          if (part.filename != null) 'filename': part.filename,
        });
      case ToolCallPart():
        toolCalls.add(<String, Object?>{
          'id': part.toolCallId,
          'name': part.toolName,
          'args': part.args ?? <String, Object?>{},
        });
      case ReasoningPart():
        content.add(<String, Object?>{
          'type': 'reasoning',
          'reasoning': part.text,
        });
      default:
        break;
    }
  }
  return <String, Object?>{
    'type': type,
    if (message.role != MessageRole.system) 'id': message.id,
    'content': content,
    if (toolCalls.isNotEmpty) 'tool_calls': toolCalls,
  };
}

/// Bridges a LangGraph Platform graph onto the package's adapter contract.
class LangGraphChatModelAdapter extends ChatModelAdapter {
  LangGraphChatModelAdapter({
    required this.client,
    required this.assistantId,
    this.threadId,
    this.streamMode = const <String>['messages', 'updates', 'custom'],
    this.state,
    this.command,
  });

  final LangGraphClient client;
  final String assistantId;

  /// Reused when set; otherwise a thread is created on the first run.
  final String? threadId;
  final List<String> streamMode;

  /// Graph state sent alongside the messages.
  final Map<String, Object?>? state;

  /// A graph command, for resuming after an interrupt.
  final Object? command;

  String? _threadId;

  /// The last `values` payload, so a host can read shared graph state.
  Map<String, Object?>? lastState;

  /// The last `metadata` payload (run and thread ids).
  Map<String, Object?>? lastMetadata;

  /// `custom` payloads, in arrival order.
  final List<Object?> customEvents = <Object?>[];

  /// The interrupts the last run parked on.
  final List<Map<String, Object?>> pendingInterrupts = <Map<String, Object?>>[];

  @override
  Stream<ChatModelRunResult> run(ChatModelRunContext context) async* {
    final String thread = threadId ??
        _threadId ??
        (_threadId = await client.createThread());

    final LangGraphMessageAccumulator accumulator =
        LangGraphMessageAccumulator(
      initialMessages: <Map<String, Object?>>[
        for (final ThreadMessage message in context.messages)
          threadMessageToLangChain(message),
      ],
    );

    pendingInterrupts.clear();
    final List<MessagePart> parts = <MessagePart>[];
    bool interrupted = false;

    List<MessagePart> render() {
      final List<MessagePart> rendered = <MessagePart>[];
      for (final Map<String, Object?> message in accumulator.messages) {
        final ({String toolCallId, Object? content, bool isError})? result =
            langChainToolResult(message);
        if (result != null) {
          // Tool results land on the call they answer.
          final List<MessagePart> patched =
              applyLangChainToolResult(rendered, message);
          rendered
            ..clear()
            ..addAll(patched);
          continue;
        }
        if (message['type'] == 'system') continue;
        rendered.addAll(langChainMessageToParts(message));
      }
      return rendered;
    }

    await for (final LangGraphEvent event in client.streamRun(
      threadId: thread,
      assistantId: assistantId,
      input: <String, Object?>{
        if (state != null) ...state!,
        'messages': <Map<String, Object?>>[
          for (final ThreadMessage message in context.messages)
            threadMessageToLangChain(message),
        ],
      },
      streamMode: streamMode,
      command: command,
      abortSignal: context.abortSignal,
    )) {
      switch (event.event) {
        case 'messages/partial':
        case 'messages/complete':
        case 'messages':
          accumulator.addMessages(langGraphMessagesOf(event.data));
        case 'updates':
          accumulator.addMessages(langGraphMessagesOf(event.data));
          final List<Map<String, Object?>> interrupts =
              langGraphInterruptsOf(event.data);
          if (interrupts.isNotEmpty) {
            interrupted = true;
            pendingInterrupts.addAll(interrupts);
          }
        case 'values':
          if (event.data is Map<String, Object?>) {
            lastState = event.data! as Map<String, Object?>;
            accumulator.addMessages(langGraphMessagesOf(event.data));
            final List<Map<String, Object?>> interrupts =
                langGraphInterruptsOf(event.data);
            if (interrupts.isNotEmpty) {
              interrupted = true;
              pendingInterrupts.addAll(interrupts);
            }
          }
        case 'metadata':
          if (event.data is Map<String, Object?>) {
            lastMetadata = event.data! as Map<String, Object?>;
          }
        case 'custom':
          customEvents.add(event.data);
        case 'error':
          throw LangGraphException(_errorMessage(event.data));
        case 'end':
          break;
      }

      parts
        ..clear()
        ..addAll(render());
      yield ChatModelRunResult(
        content: List<MessagePart>.unmodifiable(parts),
        status: interrupted
            ? const MessageStatusRequiresAction()
            : const MessageStatusRunning(),
      );
      if (interrupted) return;
    }

    parts
      ..clear()
      ..addAll(render());
    yield ChatModelRunResult(
      content: List<MessagePart>.unmodifiable(parts),
      status: const MessageStatusComplete(),
    );
  }

  String _errorMessage(Object? data) {
    if (data is Map<String, Object?>) {
      return (data['message'] as String?) ??
          (data['error'] as String?) ??
          data.toString();
    }
    return data?.toString() ?? 'The run failed';
  }
}

List<Object?> _listOf(Object? value) =>
    value is List<Object?> ? value : const <Object?>[];

Object? _additional(Map<String, Object?> message, String key) {
  final Object? kwargs = message['additional_kwargs'];
  return kwargs is Map<String, Object?> ? kwargs[key] : null;
}

String _stringContent(Object? content) {
  if (content is String) return content;
  if (content is List<Object?>) {
    return <String>[
      for (final Object? block in content)
        if (block is Map<String, Object?> && block['type'] == 'text')
          (block['text'] as String?) ?? '',
    ].join();
  }
  return '';
}

List<MessagePart> _contentToParts(Object? content) {
  if (content == null) return const <MessagePart>[];
  if (content is String) return <MessagePart>[TextPart(content)];
  if (content is! List<Object?>) return const <MessagePart>[];
  final List<MessagePart> parts = <MessagePart>[];
  for (final Object? block in content) {
    if (block is! Map<String, Object?>) continue;
    switch (block['type']) {
      case 'text':
      case 'text_delta':
        final String text = (block['text'] as String?) ?? '';
        if (text.isNotEmpty) parts.add(TextPart(text));
      case 'image':
        final Object? image = block['image'];
        if (image is String) parts.add(ImagePart(image: image));
      case 'file':
        final Object? data = block['data'];
        if (data is String) {
          parts.add(
            FilePart(
              data: data,
              mimeType: (block['mime_type'] as String?) ??
                  'application/octet-stream',
              filename: block['filename'] as String?,
            ),
          );
        }
      case 'thinking':
        final String thinking = (block['thinking'] as String?) ?? '';
        if (thinking.isNotEmpty) parts.add(ReasoningPart(thinking));
      case 'reasoning':
        final String reasoning = (block['reasoning'] as String?) ?? '';
        if (reasoning.isNotEmpty) parts.add(ReasoningPart(reasoning));
      case 'tool_use':
        final Object? id = block['id'];
        final Object? name = block['name'];
        if (id is String && name is String) {
          parts.add(
            ToolCallPart(
              toolCallId: id,
              toolName: name,
              args: block['input'] ?? block['args'],
            ),
          );
        }
      default:
        break;
    }
  }
  return parts;
}
