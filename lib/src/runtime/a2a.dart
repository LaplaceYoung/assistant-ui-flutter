import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/abort.dart';
import '../core/adapters.dart';
import '../core/message.dart';
import '../core/message_part.dart';

/// The A2A protocol version this client speaks.
const String a2aProtocolVersion = '1.0';

/// One content part, in any of the four shapes the protocol allows.
class A2APart {
  const A2APart({
    this.text,
    this.raw,
    this.url,
    this.data,
    this.metadata,
    this.filename,
    this.mediaType,
  });

  final String? text;

  /// Base64 bytes.
  final String? raw;
  final String? url;
  final Object? data;
  final Map<String, Object?>? metadata;
  final String? filename;
  final String? mediaType;

  static A2APart? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    return A2APart(
      text: raw['text'] as String?,
      raw: raw['raw'] as String?,
      url: raw['url'] as String?,
      data: raw['data'],
      metadata: raw['metadata'] as Map<String, Object?>?,
      filename: raw['filename'] as String?,
      mediaType: raw['mediaType'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        if (text != null) 'text': text,
        if (raw != null) 'raw': raw,
        if (url != null) 'url': url,
        if (data != null) 'data': data,
        if (metadata != null) 'metadata': metadata,
        if (filename != null) 'filename': filename,
        if (mediaType != null) 'mediaType': mediaType,
      };
}

/// Who wrote a message.
enum A2ARole { unspecified, user, agent }

/// A message in an A2A exchange.
class A2AMessage {
  const A2AMessage({
    required this.messageId,
    required this.role,
    required this.parts,
    this.contextId,
    this.taskId,
    this.metadata,
    this.extensions,
    this.referenceTaskIds,
  });

  final String messageId;
  final A2ARole role;
  final List<A2APart> parts;
  final String? contextId;
  final String? taskId;
  final Map<String, Object?>? metadata;
  final List<String>? extensions;
  final List<String>? referenceTaskIds;

  static A2AMessage? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Object? messageId = raw['messageId'];
    if (messageId is! String) return null;
    return A2AMessage(
      messageId: messageId,
      role: switch (raw['role']) {
        'user' => A2ARole.user,
        'agent' => A2ARole.agent,
        _ => A2ARole.unspecified,
      },
      parts: <A2APart>[
        for (final Object? part in (raw['parts'] as List<Object?>?) ?? const <Object?>[])
          if (A2APart.fromJson(part) case final A2APart parsed) parsed,
      ],
      contextId: raw['contextId'] as String?,
      taskId: raw['taskId'] as String?,
      metadata: raw['metadata'] as Map<String, Object?>?,
      extensions: _stringList(raw['extensions']),
      referenceTaskIds: _stringList(raw['referenceTaskIds']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'messageId': messageId,
        'role': role.name,
        'parts': <Map<String, Object?>>[
          for (final A2APart part in parts) part.toJson(),
        ],
        if (contextId != null) 'contextId': contextId,
        if (taskId != null) 'taskId': taskId,
        if (metadata != null) 'metadata': metadata,
        if (extensions != null) 'extensions': extensions,
        if (referenceTaskIds != null) 'referenceTaskIds': referenceTaskIds,
      };
}

/// The lifecycle states a task moves through.
enum A2ATaskState {
  unspecified('unspecified'),
  submitted('submitted'),
  working('working'),
  completed('completed'),
  failed('failed'),
  canceled('canceled'),
  inputRequired('input_required'),
  rejected('rejected'),
  authRequired('auth_required');

  const A2ATaskState(this.wire);

  /// The snake_case name the wire uses.
  final String wire;

  static A2ATaskState fromWire(Object? raw) {
    for (final A2ATaskState state in A2ATaskState.values) {
      if (state.wire == raw) return state;
    }
    return A2ATaskState.unspecified;
  }

  /// States that end the run.
  bool get isTerminal => const <A2ATaskState>{
        A2ATaskState.completed,
        A2ATaskState.failed,
        A2ATaskState.canceled,
        A2ATaskState.rejected,
      }.contains(this);

  /// States that park the run until the host answers.
  bool get isInterrupted => const <A2ATaskState>{
        A2ATaskState.inputRequired,
        A2ATaskState.authRequired,
      }.contains(this);
}

class A2ATaskStatus {
  const A2ATaskStatus({required this.state, this.message, this.timestamp});

  final A2ATaskState state;
  final A2AMessage? message;
  final String? timestamp;

  static A2ATaskStatus? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    return A2ATaskStatus(
      state: A2ATaskState.fromWire(raw['state']),
      message: A2AMessage.fromJson(raw['message']),
      timestamp: raw['timestamp'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'state': state.wire,
        if (message != null) 'message': message!.toJson(),
        if (timestamp != null) 'timestamp': timestamp,
      };
}

class A2AArtifact {
  const A2AArtifact({
    required this.artifactId,
    required this.parts,
    this.name,
    this.description,
    this.metadata,
    this.extensions,
  });

  final String artifactId;
  final List<A2APart> parts;
  final String? name;
  final String? description;
  final Map<String, Object?>? metadata;
  final List<String>? extensions;

  static A2AArtifact? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Object? artifactId = raw['artifactId'];
    if (artifactId is! String) return null;
    return A2AArtifact(
      artifactId: artifactId,
      parts: <A2APart>[
        for (final Object? part in (raw['parts'] as List<Object?>?) ?? const <Object?>[])
          if (A2APart.fromJson(part) case final A2APart parsed) parsed,
      ],
      name: raw['name'] as String?,
      description: raw['description'] as String?,
      metadata: raw['metadata'] as Map<String, Object?>?,
      extensions: _stringList(raw['extensions']),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'artifactId': artifactId,
        'parts': <Map<String, Object?>>[
          for (final A2APart part in parts) part.toJson(),
        ],
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (metadata != null) 'metadata': metadata,
        if (extensions != null) 'extensions': extensions,
      };
}

class A2ATask {
  const A2ATask({
    required this.id,
    required this.status,
    this.contextId,
    this.artifacts = const <A2AArtifact>[],
    this.history = const <A2AMessage>[],
    this.metadata,
  });

  final String id;
  final A2ATaskStatus status;
  final String? contextId;
  final List<A2AArtifact> artifacts;
  final List<A2AMessage> history;
  final Map<String, Object?>? metadata;

  static A2ATask? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Object? id = raw['id'];
    if (id is! String) return null;
    return A2ATask(
      id: id,
      status: A2ATaskStatus.fromJson(raw['status']) ??
          const A2ATaskStatus(state: A2ATaskState.unspecified),
      contextId: raw['contextId'] as String?,
      artifacts: <A2AArtifact>[
        for (final Object? entry
            in (raw['artifacts'] as List<Object?>?) ?? const <Object?>[])
          if (A2AArtifact.fromJson(entry) case final A2AArtifact parsed) parsed,
      ],
      history: <A2AMessage>[
        for (final Object? entry
            in (raw['history'] as List<Object?>?) ?? const <Object?>[])
          if (A2AMessage.fromJson(entry) case final A2AMessage parsed) parsed,
      ],
      metadata: raw['metadata'] as Map<String, Object?>?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'status': status.toJson(),
        if (contextId != null) 'contextId': contextId,
        if (artifacts.isNotEmpty)
          'artifacts': <Map<String, Object?>>[
            for (final A2AArtifact artifact in artifacts) artifact.toJson(),
          ],
        if (history.isNotEmpty)
          'history': <Map<String, Object?>>[
            for (final A2AMessage message in history) message.toJson(),
          ],
        if (metadata != null) 'metadata': metadata,
      };
}

/// What a streamed run sends back.
sealed class A2AStreamEvent {
  const A2AStreamEvent();

  /// Reads one wire event: `kind`-discriminated, with the REST-style wrapped
  /// envelopes accepted too. Unrecognized shapes return null.
  static A2AStreamEvent? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Map<String, Object?> flat = raw.containsKey('kind')
        ? (Map<String, Object?>.from(raw)..remove('kind'))
        : raw;

    if (raw.containsKey('statusUpdate') || raw.containsKey('artifactUpdate')) {
      // Wrapped envelopes, as the REST binding sends them.
      final Object? status = raw['statusUpdate'];
      if (status is Map<String, Object?>) {
        final A2AStatusUpdateEvent? event = A2AStatusUpdateEvent.fromJson(status);
        if (event != null) return event;
      }
      final Object? artifact = raw['artifactUpdate'];
      if (artifact is Map<String, Object?>) {
        final A2AArtifactUpdateEvent? event =
            A2AArtifactUpdateEvent.fromJson(artifact);
        if (event != null) return event;
      }
      final Object? task = raw['task'];
      if (task is Map<String, Object?>) {
        final A2ATask? parsed = A2ATask.fromJson(task);
        if (parsed != null) return A2ATaskEvent(parsed);
      }
      final Object? message = raw['message'];
      if (message is Map<String, Object?>) {
        final A2AMessage? parsed = A2AMessage.fromJson(message);
        if (parsed != null) return A2AMessageEvent(parsed);
      }
      return null;
    }

    switch (raw['kind']) {
      case 'task':
        final A2ATask? task = A2ATask.fromJson(flat);
        return task == null ? null : A2ATaskEvent(task);
      case 'message':
        final A2AMessage? message = A2AMessage.fromJson(flat);
        return message == null ? null : A2AMessageEvent(message);
      case 'status-update':
        return A2AStatusUpdateEvent.fromJson(flat);
      case 'artifact-update':
        return A2AArtifactUpdateEvent.fromJson(flat);
      default:
        return null;
    }
  }
}

class A2ATaskEvent extends A2AStreamEvent {
  const A2ATaskEvent(this.task);
  final A2ATask task;
}

class A2AMessageEvent extends A2AStreamEvent {
  const A2AMessageEvent(this.message);
  final A2AMessage message;
}

class A2AStatusUpdateEvent extends A2AStreamEvent {
  const A2AStatusUpdateEvent({
    required this.taskId,
    required this.contextId,
    required this.status,
  });

  final String taskId;
  final String contextId;
  final A2ATaskStatus status;

  static A2AStatusUpdateEvent? fromJson(Map<String, Object?> raw) {
    final Object? taskId = raw['taskId'];
    final A2ATaskStatus? status = A2ATaskStatus.fromJson(raw['status']);
    if (taskId is! String || status == null) return null;
    return A2AStatusUpdateEvent(
      taskId: taskId,
      contextId: (raw['contextId'] as String?) ?? '',
      status: status,
    );
  }
}

class A2AArtifactUpdateEvent extends A2AStreamEvent {
  const A2AArtifactUpdateEvent({
    required this.taskId,
    required this.contextId,
    required this.artifact,
    this.append = false,
    this.lastChunk = false,
  });

  final String taskId;
  final String contextId;
  final A2AArtifact artifact;
  final bool append;
  final bool lastChunk;

  static A2AArtifactUpdateEvent? fromJson(Map<String, Object?> raw) {
    final Object? taskId = raw['taskId'];
    final A2AArtifact? artifact = A2AArtifact.fromJson(raw['artifact']);
    if (taskId is! String || artifact == null) return null;
    return A2AArtifactUpdateEvent(
      taskId: taskId,
      contextId: (raw['contextId'] as String?) ?? '',
      artifact: artifact,
      append: raw['append'] == true,
      lastChunk: raw['lastChunk'] == true,
    );
  }
}

/// The discovery document at `/.well-known/agent-card.json`.
class A2AAgentCard {
  const A2AAgentCard({
    required this.name,
    this.description,
    this.url,
    this.version,
    this.capabilities = const <String, Object?>{},
    this.skills = const <Map<String, Object?>>[],
  });

  final String name;
  final String? description;
  final String? url;
  final String? version;
  final Map<String, Object?> capabilities;
  final List<Map<String, Object?>> skills;

  static A2AAgentCard? fromJson(Object? raw) {
    if (raw is! Map<String, Object?>) return null;
    final Object? name = raw['name'];
    if (name is! String) return null;
    return A2AAgentCard(
      name: name,
      description: raw['description'] as String?,
      url: raw['url'] as String?,
      version: raw['version'] as String?,
      capabilities: raw['capabilities'] as Map<String, Object?>? ??
          const <String, Object?>{},
      skills: <Map<String, Object?>>[
        for (final Object? skill
            in (raw['skills'] as List<Object?>?) ?? const <Object?>[])
          if (skill is Map<String, Object?>) skill,
      ],
    );
  }
}

/// Raised for transport failures and structured A2A errors alike.
class A2AException implements Exception {
  const A2AException({required this.code, this.status, required this.message});

  final Object code;
  final String? status;
  final String message;

  @override
  String toString() =>
      'A2AException($code${status == null ? '' : ' $status'}): $message';
}

/// Maps one A2A part onto a message part, following upstream's conversions:
/// text first, then url (image vs file by media type), then base64 bytes, and
/// finally structured data, which renders as pretty JSON text.
MessagePart a2aPartToContent(A2APart part) {
  if (part.text != null) return TextPart(part.text!);
  if (part.url != null) {
    if (part.mediaType?.startsWith('image/') ?? false) {
      return ImagePart(image: part.url!, filename: part.filename);
    }
    return FilePart(
      data: part.url,
      mimeType: part.mediaType ?? 'application/octet-stream',
      filename: part.filename,
    );
  }
  if (part.raw != null) {
    if (part.mediaType?.startsWith('image/') ?? false) {
      return ImagePart(
        image: 'data:${part.mediaType};base64,${part.raw}',
        filename: part.filename,
      );
    }
    return FilePart(
      data: part.raw,
      mimeType: part.mediaType ?? 'application/octet-stream',
      filename: part.filename,
    );
  }
  if (part.data != null) {
    return TextPart(
      const JsonEncoder.withIndent('  ').convert(part.data),
    );
  }
  return const TextPart('');
}

List<MessagePart> a2aPartsToContent(List<A2APart> parts) =>
    <MessagePart>[for (final A2APart part in parts) a2aPartToContent(part)];

/// The message status a task state maps onto.
MessageStatus a2aTaskStateToMessageStatus(A2ATaskState state) => switch (state) {
      A2ATaskState.submitted || A2ATaskState.working => const MessageStatusRunning(),
      A2ATaskState.completed => const MessageStatusComplete(),
      A2ATaskState.failed || A2ATaskState.rejected => MessageStatusIncomplete(
          reason: IncompleteReason.error,
        ),
      A2ATaskState.canceled => MessageStatusIncomplete(
          reason: IncompleteReason.cancelled,
        ),
      A2ATaskState.inputRequired || A2ATaskState.authRequired =>
        const MessageStatusRequiresAction(),
      A2ATaskState.unspecified => const MessageStatusRunning(),
    };

/// The parts a thread message turns into before it is sent.
List<A2APart> contentPartsToA2AParts(List<MessagePart> content) {
  final List<A2APart> parts = <A2APart>[];
  for (final MessagePart part in content) {
    switch (part) {
      case TextPart():
        parts.add(A2APart(text: part.text));
      case ImagePart():
        final String image = part.image;
        if (image.startsWith('data:')) {
          final int comma = image.indexOf(',');
          final String header = image.substring(5, comma < 0 ? image.length : comma);
          final String mediaType = header.split(';').first;
          parts.add(
            A2APart(
              raw: comma < 0 ? '' : image.substring(comma + 1),
              mediaType: mediaType.isEmpty ? 'image/png' : mediaType,
              filename: part.filename,
            ),
          );
        } else {
          parts.add(
            A2APart(
              url: image,
              mediaType: 'image/png',
              filename: part.filename,
            ),
          );
        }
      case FilePart():
        final String? data = part.data;
        final bool isUrl = data != null &&
            (data.startsWith('http://') || data.startsWith('https://'));
        parts.add(
          A2APart(
            raw: isUrl ? null : data,
            url: isUrl ? data : null,
            mediaType: part.mimeType,
            filename: part.filename,
          ),
        );
      case DataPart():
        parts.add(A2APart(data: part.data, metadata: <String, Object?>{'name': part.name}));
      default:
        break;
    }
  }
  return parts;
}

/// Turns a thread message into the A2A message a `send` carries.
A2AMessage threadMessageToA2AMessage(
  ThreadMessage message, {
  String? contextId,
  String? taskId,
}) =>
    A2AMessage(
      messageId: message.id,
      role: A2ARole.user,
      parts: contentPartsToA2AParts(message.content),
      contextId: contextId,
      taskId: taskId,
    );

/// The A2A client: the Dart counterpart of `A2AClient` in
/// `@assistant-ui/react-a2a`.
class A2AClient {
  A2AClient({
    required String baseUrl,
    this.headers = const <String, String>{},
    this.tenant,
    this.extensions = const <String>[],
    http.Client? client,
  })  : baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _client = client ?? http.Client();

  final String baseUrl;
  final Map<String, String> headers;
  final String? tenant;
  final List<String> extensions;
  final http.Client _client;

  Map<String, String> _headers({bool json = true, bool stream = false}) =>
      <String, String>{
        'accept': stream
            ? 'text/event-stream'
            : 'application/a2a+json, application/json',
        'a2a-version': a2aProtocolVersion,
        if (json) 'content-type': 'application/a2a+json',
        if (extensions.isNotEmpty) 'a2a-extensions': extensions.join(', '),
        ...headers,
      };

  String get _basePath => tenant == null
      ? ''
      : '/${Uri.encodeComponent(tenant!)}';

  /// Reads the agent card.
  Future<A2AAgentCard> getAgentCard() async {
    final http.Response response = await _client.get(
      Uri.parse('$baseUrl/.well-known/agent-card.json'),
      headers: _headers(json: false),
    );
    final Map<String, Object?> body = await _decode(response);
    final A2AAgentCard? card = A2AAgentCard.fromJson(body);
    if (card == null) {
      throw const A2AException(code: 'invalid-card', message: 'No agent card');
    }
    return card;
  }

  /// Sends a message and waits for the task or the reply.
  Future<Object> sendMessage(A2AMessage message) async {
    final http.Response response = await _client.post(
      Uri.parse('$baseUrl$_basePath/message:send'),
      headers: _headers(),
      body: jsonEncode(<String, Object?>{'message': message.toJson()}),
    );
    final Map<String, Object?> body = await _decode(response);
    final A2ATask? task = A2ATask.fromJson(body);
    if (task != null) return task;
    final A2AMessage? reply = A2AMessage.fromJson(body);
    if (reply != null) return reply;
    throw const A2AException(
      code: 'invalid-response',
      message: 'Neither a task nor a message',
    );
  }

  /// Streams a run: one [A2AStreamEvent] per SSE frame.
  Stream<A2AStreamEvent> streamMessage(
    A2AMessage message, {
    AbortSignal? abortSignal,
  }) {
    final StreamController<A2AStreamEvent> controller =
        StreamController<A2AStreamEvent>();

    Future<void> pump() async {
      try {
        final http.Request request = http.Request(
          'POST',
          Uri.parse('$baseUrl$_basePath/message:stream'),
        )
          ..headers.addAll(_headers(stream: true))
          ..body = jsonEncode(<String, Object?>{'message': message.toJson()});
        final http.StreamedResponse response = await _client.send(request);
        final String contentType =
            response.headers['content-type']?.split(';').first.trim().toLowerCase() ??
                '';
        if (response.statusCode >= 400) {
          final String body = await response.stream.bytesToString();
          controller.addError(_errorFrom(response.statusCode, body));
          return;
        }
        if (contentType != 'text/event-stream') {
          await response.stream.drain<void>();
          controller.addError(
            A2AException(
              code: 'content-type',
              message: 'Expected "text/event-stream", received '
                  '${contentType.isEmpty ? 'no Content-Type header' : '"$contentType"'}',
            ),
          );
          return;
        }
        final Stream<String> lines = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());
        await for (final String line in lines) {
          if (abortSignal?.isAborted ?? false) break;
          if (!line.startsWith('data:')) continue;
          final String payload = line.substring(5).trim();
          if (payload.isEmpty) continue;
          Object? decoded;
          try {
            decoded = jsonDecode(payload);
          } on FormatException {
            // A frame that is not JSON is skipped, not fatal.
            continue;
          }
          // JSON-RPC-shaped frames carry their event under `result`.
          if (decoded is Map<String, Object?>) {
            final Object? error = decoded['error'];
            if (error is Map<String, Object?>) {
              controller.addError(
                A2AException(
                  code: error['code'] ?? 'error',
                  status: error['status'] as String?,
                  message: (error['message'] as String?) ?? 'A2A stream error',
                ),
              );
              return;
            }
            decoded = decoded['result'] ?? decoded;
          }
          final A2AStreamEvent? event = A2AStreamEvent.fromJson(decoded);
          if (event != null) controller.add(event);
        }
      } on Object catch (error, stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      } finally {
        if (!controller.isClosed) await controller.close();
      }
    }

    unawaited(pump());
    return controller.stream;
  }

  /// Reads a task back.
  Future<A2ATask> getTask(String taskId, {int? historyLength}) async {
    final Uri uri = Uri.parse('$baseUrl$_basePath/tasks/$taskId').replace(
      queryParameters: <String, String>{
        if (historyLength != null) 'historyLength': '$historyLength',
      },
    );
    final http.Response response =
        await _client.get(uri, headers: _headers(json: false));
    final Map<String, Object?> body = await _decode(response);
    final A2ATask? task = A2ATask.fromJson(body);
    if (task == null) {
      throw const A2AException(code: 'invalid-task', message: 'No task in reply');
    }
    return task;
  }

  /// Asks the agent to stop a task.
  Future<A2ATask> cancelTask(String taskId) async {
    final http.Response response = await _client.post(
      Uri.parse('$baseUrl$_basePath/tasks/$taskId:cancel'),
      headers: _headers(),
      body: '{}',
    );
    final Map<String, Object?> body = await _decode(response);
    final A2ATask? task = A2ATask.fromJson(body);
    if (task == null) {
      throw const A2AException(code: 'invalid-task', message: 'No task in reply');
    }
    return task;
  }

  void close() => _client.close();

  Future<Map<String, Object?>> _decode(http.Response response) async {
    if (response.statusCode >= 400) {
      throw _errorFrom(response.statusCode, response.body);
    }
    final Object? decoded = jsonDecode(response.body);
    if (decoded is! Map<String, Object?>) {
      throw A2AException(
        code: 'invalid-body',
        message: 'Expected an object, got ${response.body}',
      );
    }
    // JSON-RPC frames unwrap to their result; `kind` is the wire's type tag and
    // is dropped before the payload reaches the typed readers.
    Object? body = decoded.containsKey('result') ? decoded['result'] : decoded;
    final Object? error = decoded['error'];
    if (error is Map<String, Object?>) {
      throw A2AException(
        code: error['code'] ?? 'error',
        status: error['status'] as String?,
        message: (error['message'] as String?) ?? 'A2A request failed',
      );
    }
    if (body is Map<String, Object?>) {
      body = Map<String, Object?>.from(body)..remove('kind');
    }
    return body is Map<String, Object?> ? body : const <String, Object?>{};
  }

  A2AException _errorFrom(int statusCode, String body) {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is Map<String, Object?> && decoded['error'] is Map<String, Object?>) {
        final Map<String, Object?> error =
            decoded['error']! as Map<String, Object?>;
        return A2AException(
          code: error['code'] ?? statusCode,
          status: error['status'] as String?,
          message: (error['message'] as String?) ?? 'A2A request failed: $statusCode',
        );
      }
    } on FormatException {
      // Fall through to the status-based error.
    }
    return A2AException(
      code: statusCode,
      message: 'A2A request failed: $statusCode ${body.trim()}'.trim(),
    );
  }
}

/// Bridges an A2A agent onto the package's adapter contract.
///
/// The last user turn is sent as an A2A message; streamed status updates,
/// messages and artifacts accumulate into the parts the runtime renders.
/// `input_required` / `auth_required` end the run as `requires-action` and the
/// host answers by sending the next message.
class A2AChatModelAdapter extends ChatModelAdapter {
  A2AChatModelAdapter({
    required this.client,
    this.contextId,
    this.taskId,
  });

  final A2AClient client;

  /// Reused across runs once the agent assigns one.
  final String? contextId;

  /// Set to continue a specific task.
  final String? taskId;

  /// The latest task snapshot the run produced, when the agent sent one.
  A2ATask? lastTask;

  @override
  Stream<ChatModelRunResult> run(ChatModelRunContext context) async* {
    final List<ThreadMessage> incoming = context.messages
        .where((ThreadMessage message) => message.role == MessageRole.user)
        .toList();
    final A2AMessage message = incoming.isEmpty
        ? A2AMessage(
            messageId: 'message-${DateTime.now().microsecondsSinceEpoch}',
            role: A2ARole.user,
            parts: contentPartsToA2AParts(context.getMessage().content),
            contextId: contextId,
            taskId: taskId,
          )
        : threadMessageToA2AMessage(
            incoming.last,
            contextId: contextId,
            taskId: taskId,
          );

    final List<MessagePart> parts = <MessagePart>[];
    // Parts the agent sent directly (status and message events), kept apart
    // from the artifacts so a rebuild never drops them.
    final List<MessagePart> streamed = <MessagePart>[];
    final Map<String, List<MessagePart>> artifacts = <String, List<MessagePart>>{};
    A2ATaskState state = A2ATaskState.submitted;
    String? statusText;

    void emit() {
      parts
        ..clear()
        ..addAll(streamed)
        ..addAll(<MessagePart>[
          for (final List<MessagePart> artifact in artifacts.values) ...artifact,
        ]);
    }

    await for (final A2AStreamEvent event in client.streamMessage(
      message,
      abortSignal: context.abortSignal,
    )) {
      switch (event) {
        case A2ATaskEvent(:final A2ATask task):
          lastTask = task;
          state = task.status.state;
          if (task.status.message != null) {
            final List<MessagePart> update =
                a2aPartsToContent(task.status.message!.parts);
            streamed.addAll(update);
            statusText = _textOf(update) ?? statusText;
          }
          for (final A2AArtifact artifact in task.artifacts) {
            artifacts[artifact.artifactId] = a2aPartsToContent(artifact.parts);
          }
        case A2AMessageEvent(:final A2AMessage message):
          streamed.addAll(a2aPartsToContent(message.parts));
        case A2AStatusUpdateEvent(:final A2ATaskStatus status):
          state = status.state;
          final A2AMessage? update = status.message;
          if (update != null) {
            final List<MessagePart> mapped = a2aPartsToContent(update.parts);
            streamed.addAll(mapped);
            statusText = _textOf(mapped) ?? statusText;
          }
        case A2AArtifactUpdateEvent(
            :final A2AArtifact artifact,
            :final bool append
          ):
          final List<MessagePart> mapped = a2aPartsToContent(artifact.parts);
          artifacts[artifact.artifactId] = append
              ? <MessagePart>[
                  ...(artifacts[artifact.artifactId] ?? const <MessagePart>[]),
                  ...mapped,
                ]
              : mapped;
      }

      if (state == A2ATaskState.failed || state == A2ATaskState.rejected) {
        throw A2AException(
          code: state.wire,
          message: statusText ?? 'The task ${state.wire}',
        );
      }
      if (state == A2ATaskState.canceled) {
        emit();
        yield ChatModelRunResult(
          content: List<MessagePart>.unmodifiable(parts),
          status: a2aTaskStateToMessageStatus(state),
        );
        return;
      }

      emit();
      yield ChatModelRunResult(
        content: List<MessagePart>.unmodifiable(parts),
        status: state.isTerminal || state.isInterrupted
            ? a2aTaskStateToMessageStatus(state)
            : const MessageStatusRunning(),
      );
      if (state.isTerminal || state.isInterrupted) return;
    }

    // The stream ended without a terminal state: report what arrived.
    emit();
    yield ChatModelRunResult(
      content: List<MessagePart>.unmodifiable(parts),
      status: state.isInterrupted
          ? a2aTaskStateToMessageStatus(state)
          : const MessageStatusComplete(),
    );
  }
}

List<String>? _stringList(Object? raw) {
  if (raw is! List<Object?>) return null;
  return <String>[
    for (final Object? entry in raw)
      if (entry is String) entry,
  ];
}

/// Joins the text parts of an agent message, for error reporting.
String? _textOf(List<MessagePart> parts) {
  final String text = <String>[
    for (final MessagePart part in parts)
      if (part is TextPart) part.text,
  ].join('\n');
  return text.isEmpty ? null : text;
}
