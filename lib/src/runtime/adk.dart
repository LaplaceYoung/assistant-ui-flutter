import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/abort.dart';
import '../core/adapters.dart';
import '../core/message.dart';
import '../core/message_part.dart';

/// The synthetic tool call ADK emits to ask for a confirmation. The gated
/// tool's own id is never answerable, so every approval carries this call's id.
const String adkRequestConfirmation = 'adk_request_confirmation';

/// A gate waiting for the host's answer.
class AdkToolConfirmation {
  const AdkToolConfirmation({
    required this.approvalId,
    required this.toolName,
    this.gatedCallId,
    this.approved,
    this.args,
  });

  /// The id a reply quotes: the synthetic confirmation call's id.
  final String approvalId;

  /// The tool being gated.
  final String toolName;

  /// The gated call's own id, when the synthetic call carries it.
  final String? gatedCallId;

  /// Null while the gate is open.
  final bool? approved;

  final Object? args;

  AdkToolConfirmation copyWith({bool? approved}) => AdkToolConfirmation(
        approvalId: approvalId,
        toolName: toolName,
        gatedCallId: gatedCallId,
        approved: approved ?? this.approved,
        args: args,
      );
}

/// A credential the agent asked the host for.
class AdkAuthRequest {
  const AdkAuthRequest({required this.toolCallId, required this.authConfig});

  final String toolCallId;
  final Object? authConfig;
}

/// Raised for transport failures and ADK-side errors alike.
class AdkException implements Exception {
  const AdkException(this.message);

  final String message;

  @override
  String toString() => 'AdkException: $message';
}

/// One streamed ADK event, normalized to camelCase.
class AdkEvent {
  const AdkEvent({
    required this.raw,
    this.author,
    this.partial = false,
    this.turnComplete = false,
    this.interrupted = false,
    this.longRunningToolIds = const <String>[],
    this.parts = const <Map<String, Object?>>[],
  });

  final Map<String, Object?> raw;
  final String? author;

  /// A partial event replaces the buffer it belongs to.
  final bool partial;

  /// The turn is over.
  final bool turnComplete;

  final bool interrupted;
  final List<String> longRunningToolIds;

  /// The content parts, already normalized.
  final List<Map<String, Object?>> parts;

  /// Reads one event, accepting snake_case and camelCase field names.
  static AdkEvent fromJson(Map<String, Object?> raw) {
    Object? pick(String camel, String snake) =>
        raw.containsKey(camel) ? raw[camel] : raw[snake];

    final Object? content = raw['content'];
    final List<Map<String, Object?>> parts = <Map<String, Object?>>[
      if (content is Map<String, Object?> && content['parts'] is List<Object?>)
        for (final Object? part in content['parts']! as List<Object?>)
          if (part is Map<String, Object?>) part,
    ];
    final Object? longRunning =
        pick('longRunningToolIds', 'long_running_tool_ids');
    return AdkEvent(
      raw: raw,
      author: raw['author'] as String?,
      partial: pick('partial', 'partial') == true,
      turnComplete: pick('turnComplete', 'turn_complete') == true,
      interrupted: raw['interrupted'] == true,
      longRunningToolIds: <String>[
        if (longRunning is List<Object?>)
          for (final Object? id in longRunning)
            if (id is String) id,
      ],
      parts: parts,
    );
  }
}

/// The Google ADK client: sessions and the `/run_sse` endpoint.
class AdkClient {
  AdkClient({
    required String api,
    required this.appName,
    required this.userId,
    this.headers = const <String, String>{},
    http.Client? client,
  })  : api = api.endsWith('/') ? api.substring(0, api.length - 1) : api,
        _client = client ?? http.Client();

  final String api;
  final String appName;
  final String userId;
  final Map<String, String> headers;
  final http.Client _client;

  /// Creates a session and returns its id.
  Future<String> createSession({String? sessionId, Object? state}) async {
    final String id = sessionId ??
        'session-${DateTime.now().microsecondsSinceEpoch}';
    final http.Response response = await _client.post(
      Uri.parse('$api/apps/$appName/users/$userId/sessions/$id'),
      headers: <String, String>{'content-type': 'application/json', ...headers},
      body: jsonEncode(<String, Object?>{if (state != null) 'state': state}),
    );
    if (response.statusCode >= 400) {
      throw AdkException(
        'Session creation failed: HTTP ${response.statusCode} ${response.body}',
      );
    }
    return id;
  }

  /// Streams a run against `/run_sse`.
  Stream<AdkEvent> runSse({
    required String sessionId,
    required Map<String, Object?> newMessage,
    Object? stateDelta,
    AbortSignal? abortSignal,
  }) {
    final StreamController<AdkEvent> controller = StreamController<AdkEvent>();

    Future<void> pump() async {
      try {
        final http.Request request = http.Request('POST', Uri.parse('$api/run_sse'))
          ..headers.addAll(<String, String>{
            'content-type': 'application/json',
            'accept': 'text/event-stream',
            ...headers,
          })
          ..body = jsonEncode(<String, Object?>{
            'appName': appName,
            'userId': userId,
            'sessionId': sessionId,
            'newMessage': newMessage,
            'streaming': true,
            if (stateDelta != null) 'stateDelta': stateDelta,
          });
        final http.StreamedResponse response = await _client.send(request);
        if (response.statusCode >= 400) {
          final String body = await response.stream.bytesToString();
          throw AdkException(
            'ADK request failed: HTTP ${response.statusCode} $body',
          );
        }
        final String contentType =
            response.headers['content-type']?.split(';').first.trim().toLowerCase() ??
                '';
        if (contentType != 'text/event-stream') {
          await response.stream.drain<void>();
          throw AdkException(
            'Expected ADK stream response Content-Type "text/event-stream", '
            'received ${contentType.isEmpty ? 'no Content-Type header' : '"$contentType"'}',
          );
        }

        // ADK frames are `data:` lines; some deployments prefix them with an
        // `event:` name, so both shapes are read.
        final List<String> dataLines = <String>[];
        void flush() {
          if (dataLines.isEmpty) return;
          final String payload = dataLines.join('\n');
          dataLines.clear();
          if (payload.trim().isEmpty) return;
          Object? decoded;
          try {
            decoded = jsonDecode(payload);
          } on FormatException {
            throw const AdkException(
              'Invalid ADK stream event: expected valid JSON.',
            );
          }
          if (decoded is Map<String, Object?>) {
            controller.add(AdkEvent.fromJson(decoded));
          }
        }

        final Stream<String> lines = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());
        await for (final String line in lines) {
          if (abortSignal?.isAborted ?? false) break;
          if (line.isEmpty) {
            flush();
            continue;
          }
          if (line.startsWith('data:')) {
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

  void close() => _client.close();
}

/// Accumulates ADK events into parts.
///
/// Partial events replace the text they belong to; a non-partial event from the
/// same author closes that text out. Function calls become tool calls, and a
/// matching function response lands as its result.
class AdkEventAccumulator {
  final List<MessagePart> _parts = <MessagePart>[];
  final Map<String, int> _toolCallIndex = <String, int>{};

  /// The streamed text buffer for the event currently being accumulated.
  String _partialText = '';
  String? _partialAuthor;

  /// State the server pushed through `actions.stateDelta`.
  final Map<String, Object?> state = <String, Object?>{};

  /// Artifact names the server touched, with their version counters.
  final Map<String, int> artifacts = <String, int>{};

  /// Tool ids the server marked long-running: the run parks on them.
  final List<String> pendingLongRunningToolIds = <String>[];

  /// Whether the last event ended the turn.
  bool turnComplete = false;

  /// Whether the server reported an interruption.
  bool interrupted = false;

  /// Confirmations waiting for the host, keyed by approval id.
  final Map<String, AdkToolConfirmation> confirmations =
      <String, AdkToolConfirmation>{};

  /// Credentials the agent asked for.
  final List<AdkAuthRequest> authRequests = <AdkAuthRequest>[];

  /// The agent the run was handed to, when the server transferred it.
  String? transferToAgent;

  /// Whether the server asked to escalate to a human.
  bool escalated = false;

  /// The confirmations still open, in arrival order.
  List<AdkToolConfirmation> get pendingConfirmations => <AdkToolConfirmation>[
        for (final AdkToolConfirmation approval in confirmations.values)
          if (approval.approved == null) approval,
      ];

  List<MessagePart> get parts => List<MessagePart>.unmodifiable(_parts);

  void add(AdkEvent event) {
    _mergeActions(event);
    if (event.longRunningToolIds.isNotEmpty) {
      for (final String id in event.longRunningToolIds) {
        if (!pendingLongRunningToolIds.contains(id)) {
          pendingLongRunningToolIds.add(id);
        }
      }
    }
    if (event.interrupted) interrupted = true;
    if (event.turnComplete) turnComplete = true;

    for (final Map<String, Object?> part in event.parts) {
      final Object? text = part['text'];
      if (text is String && text.isNotEmpty) {
        _addText(text, partial: event.partial, author: event.author);
        continue;
      }
      final Object? call = part['functionCall'];
      if (call is Map<String, Object?>) {
        _addToolCall(call);
        continue;
      }
      final Object? response = part['functionResponse'];
      if (response is Map<String, Object?>) {
        _addToolResult(response);
      }
    }
  }

  void _addText(String text, {required bool partial, required String? author}) {
    if (partial) {
      // A partial event carries the text so far, not a delta.
      _partialText = text;
      _partialAuthor = author;
      final int index = _lastTextIndex();
      if (index >= 0) {
        _parts[index] = TextPart(text);
      } else {
        _parts.add(TextPart(text));
      }
      return;
    }
    if (_partialText.isNotEmpty && _partialAuthor == author) {
      // The final event replaces whatever the partial buffer held.
      _partialText = '';
      final int index = _lastTextIndex();
      if (index >= 0) {
        _parts[index] = TextPart(text);
        return;
      }
    }
    _parts.add(TextPart(text));
  }

  int _lastTextIndex() {
    for (int i = _parts.length - 1; i >= 0; i--) {
      if (_parts[i] is TextPart) return i;
    }
    return -1;
  }

  void _addToolCall(Map<String, Object?> call) {
    final String name = (call['name'] as String?) ?? 'tool';
    final String id = (call['id'] as String?) ?? 'call-${_parts.length}';
    if (_toolCallIndex.containsKey(id) || confirmations.containsKey(id)) return;
    _toolCallIndex[id] = _parts.length;
    if (name == adkRequestConfirmation) {
      // The gate itself: ADK answers it, and the gated call it names gets the
      // same approval so a UI never offers a second, unanswerable control.
      final String? gated = adkGatedCallId(call['args']);
      confirmations[id] = AdkToolConfirmation(
        approvalId: id,
        toolName: gated == null
            ? name
            : (adkGatedToolName(call['args']) ?? name),
        gatedCallId: gated,
        args: call['args'],
      );
      _parts.add(
        ToolCallPart(toolCallId: id, toolName: name, args: call['args']),
      );
      return;
    }
    _parts.add(
      ToolCallPart(
        toolCallId: id,
        toolName: name,
        args: call['args'],
      ),
    );
  }

  void _addToolResult(Map<String, Object?> response) {
    final String? id = response['id'] as String?;
    if (id == null) return;
    final int? index = _toolCallIndex[id];
    if (index == null || index >= _parts.length) return;
    final ToolCallPart call = _parts[index] as ToolCallPart;
    final Object? payload = response['response'];
    final String text = payload is String
        ? payload
        : const JsonEncoder.withIndent('  ').convert(payload ?? <String, Object?>{});
    _parts[index] = ToolCallPart(
      toolCallId: call.toolCallId,
      toolName: call.toolName,
      args: call.args,
      result: text,
      // ADK marks failures inside the response payload.
      isError: payload is Map<String, Object?> &&
          payload.containsKey('error') &&
          payload['error'] != null,
    );
  }

  void _mergeActions(AdkEvent event) {
    final Object? actions = event.raw['actions'];
    if (actions is! Map<String, Object?>) return;
    final Object? delta = actions['stateDelta'] ?? actions['state_delta'];
    if (delta is Map<String, Object?>) state.addAll(delta);
    final Object? artifact = actions['artifactDelta'] ?? actions['artifact_delta'];
    if (artifact is Map<String, Object?>) {
      for (final MapEntry<String, Object?> entry in artifact.entries) {
        if (entry.value is int) {
          artifacts[entry.key] = entry.value! as int;
        }
      }
    }
    if (actions['escalate'] == true) escalated = true;
    final Object? transfer =
        actions['transferToAgent'] ?? actions['transfer_to_agent'];
    if (transfer is String && transfer.isNotEmpty) transferToAgent = transfer;
    final Object? auth =
        actions['requestedAuthConfigs'] ?? actions['requested_auth_configs'];
    if (auth is Map<String, Object?>) {
      for (final MapEntry<String, Object?> entry in auth.entries) {
        authRequests.add(
          AdkAuthRequest(toolCallId: entry.key, authConfig: entry.value),
        );
      }
    }
  }

  /// Answers a confirmation: the decision is kept, so the tree can show it and
  /// [adkConfirmationReply] can build the message that resumes the run.
  void answerConfirmation(String approvalId, bool confirmed) {
    final AdkToolConfirmation? approval = confirmations[approvalId];
    if (approval == null || approval.approved != null) return;
    confirmations[approvalId] = approval.copyWith(approved: confirmed);
  }
}

/// Bridges a Google ADK agent onto the package's adapter contract.
class AdkChatModelAdapter extends ChatModelAdapter {
  AdkChatModelAdapter({
    required this.client,
    this.sessionId,
    this.stateDelta,
  });

  final AdkClient client;

  /// Reused when set; otherwise a session is created on the first run.
  final String? sessionId;

  /// State sent with each run.
  final Map<String, Object?>? stateDelta;

  String? _sessionId;

  /// The accumulator of the last run, for state, artifacts and tool ids.
  AdkEventAccumulator? lastAccumulator;

  @override
  Stream<ChatModelRunResult> run(ChatModelRunContext context) async* {
    final String session = sessionId ??
        _sessionId ??
        (_sessionId = await client.createSession());

    final AdkEventAccumulator accumulator = AdkEventAccumulator();
    lastAccumulator = accumulator;

    await for (final AdkEvent event in client.runSse(
      sessionId: session,
      newMessage: adkContentFromParts(_lastUserParts(context)),
      stateDelta: stateDelta,
      abortSignal: context.abortSignal,
    )) {
      accumulator.add(event);
      final bool parked = accumulator.pendingLongRunningToolIds.isNotEmpty ||
          accumulator.pendingConfirmations.isNotEmpty ||
          accumulator.authRequests.isNotEmpty ||
          accumulator.interrupted;
      yield ChatModelRunResult(
        content: accumulator.parts,
        status: parked
            ? const MessageStatusRequiresAction()
            : const MessageStatusRunning(),
      );
      if (parked) return;
    }

    yield ChatModelRunResult(
      content: accumulator.parts,
      status: const MessageStatusComplete(),
    );
  }

  List<MessagePart> _lastUserParts(ChatModelRunContext context) {
    for (final ThreadMessage message in context.messages.reversed) {
      if (message.role == MessageRole.user) return message.content;
    }
    return context.getMessage().content;
  }
}

/// The ADK content a message turns into.
Map<String, Object?> adkContentFromParts(List<MessagePart> parts) {
  final List<Map<String, Object?>> content = <Map<String, Object?>>[];
  for (final MessagePart part in parts) {
    switch (part) {
      case TextPart():
        if (part.text.isNotEmpty) {
          content.add(<String, Object?>{'text': part.text});
        }
      case FilePart():
        final bool isUrl = (part.data ?? '').startsWith('http');
        content.add(<String, Object?>{
          'fileData': <String, Object?>{
            if (isUrl) 'fileUri': part.data else 'data': part.data,
            'mimeType': part.mimeType,
            if (part.filename != null) 'displayName': part.filename,
          },
        });
      case ImagePart():
        content.add(<String, Object?>{
          'fileData': <String, Object?>{
            if (part.image.startsWith('http'))
              'fileUri': part.image
            else
              'data': part.image,
            'mimeType': 'image/png',
            if (part.filename != null) 'displayName': part.filename,
          },
        });
      default:
        break;
    }
  }
  return <String, Object?>{'role': 'user', 'parts': content};
}

/// The parts an ADK event's content carries, for hosts that read raw events.
List<MessagePart> adkPartsToContent(List<Map<String, Object?>> parts) {
  final List<MessagePart> content = <MessagePart>[];
  for (final Map<String, Object?> part in parts) {
    final Object? text = part['text'];
    if (text is String && text.isNotEmpty) {
      content.add(TextPart(text));
      continue;
    }
    final Object? call = part['functionCall'];
    if (call is Map<String, Object?>) {
      content.add(
        ToolCallPart(
          toolCallId: (call['id'] as String?) ?? 'call-${content.length}',
          toolName: (call['name'] as String?) ?? 'tool',
          args: call['args'],
        ),
      );
    }
  }
  return content;
}

/// The gated call id a confirmation carries. ADK nestles the original call
/// under `originalFunctionCall` (snake_case accepted too); a bare id key is
/// read as well.
String? adkGatedCallId(Object? args) {
  if (args is! Map<String, Object?>) return null;
  for (final String key in const <String>[
    'originalFunctionCall',
    'original_function_call',
    'gatedCall',
    'gated_call',
  ]) {
    final Object? nested = args[key];
    if (nested is Map<String, Object?>) {
      final Object? id = nested['id'] ?? nested['toolCallId'] ?? nested['tool_call_id'];
      if (id is String && id.isNotEmpty) return id;
    }
  }
  for (final String key in const <String>['gatedCallId', 'gated_call_id', 'toolCallId']) {
    final Object? id = args[key];
    if (id is String && id.isNotEmpty) return id;
  }
  return null;
}

/// The name of the tool behind a confirmation.
String? adkGatedToolName(Object? args) {
  if (args is! Map<String, Object?>) return null;
  for (final String key in const <String>[
    'originalFunctionCall',
    'original_function_call',
    'gatedCall',
    'gated_call',
  ]) {
    final Object? nested = args[key];
    if (nested is Map<String, Object?>) {
      final Object? name = nested['name'];
      if (name is String && name.isNotEmpty) return name;
    }
  }
  final Object? name = args['toolName'] ?? args['tool_name'];
  return name is String && name.isNotEmpty ? name : null;
}

/// The tool message that answers a confirmation and resumes the run.
Map<String, Object?> adkConfirmationReply(
  String approvalId,
  bool confirmed, {
  Object? payload,
  String? id,
}) =>
    <String, Object?>{
      'id': id ?? 'reply-$approvalId',
      'type': 'tool',
      'tool_call_id': approvalId,
      'name': adkRequestConfirmation,
      'content': <String, Object?>{
        'confirmed': confirmed,
        if (payload != null) 'payload': payload,
      },
      'status': 'success',
    };

/// Reads the gated call id a confirmation reply answers, when one is readable.
String? adkConfirmationTarget(Map<String, Object?> message) =>
    message['type'] == 'tool' && message['name'] == adkRequestConfirmation
        ? message['tool_call_id'] as String?
        : null;

/// Whether a reply confirmed or denied, reading through the nesting ADK uses.
bool? adkConfirmationDecision(Object? content) {
  Object? value = content;
  for (int depth = 0; depth < 4 && value is String; depth++) {
    try {
      value = jsonDecode(value);
    } on FormatException {
      return null;
    }
  }
  if (value is! Map<String, Object?>) return null;
  for (final String key in const <String>['confirmed', 'confirmation', 'response']) {
    final Object? entry = value[key];
    if (entry is bool) return entry;
  }
  return null;
}

/// The approvals in a transcript: which gates are open and which are answered.
Map<String, AdkToolConfirmation> projectAdkToolConfirmations(
  List<Map<String, Object?>> messages,
) {
  final Map<String, AdkToolConfirmation> approvals = <String, AdkToolConfirmation>{};
  for (final Map<String, Object?> message in messages) {
    if (message['type'] == 'ai' || message['type'] == 'AIMessageChunk') {
      for (final Object? call in (message['tool_calls'] as List<Object?>?) ??
          const <Object?>[]) {
        if (call is! Map<String, Object?> || call['name'] != adkRequestConfirmation) {
          continue;
        }
        final Object? id = call['id'];
        if (id is! String) continue;
        approvals[id] = AdkToolConfirmation(
          approvalId: id,
          toolName: adkGatedToolName(call['args']) ?? adkRequestConfirmation,
          gatedCallId: adkGatedCallId(call['args']),
          args: call['args'],
        );
      }
      continue;
    }
    final String? target = adkConfirmationTarget(message);
    if (target == null) continue;
    final AdkToolConfirmation? approval = approvals[target];
    if (approval == null) continue;
    approvals[target] =
        approval.copyWith(approved: adkConfirmationDecision(message['content']));
  }
  return approvals;
}
