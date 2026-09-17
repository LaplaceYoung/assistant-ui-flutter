import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/abort.dart';
import '../core/adapters.dart';
import '../core/message.dart';
import '../core/message_part.dart';

/// The AG-UI event vocabulary, as `@assistant-ui/react-ag-ui` models it.
///
/// One class per wire event; [parseAgUiEvent] is the only place the raw maps
/// are read, so the adapter can pattern-match on the sealed type.
sealed class AgUiEvent {
  const AgUiEvent();
}

class AgUiRunStarted extends AgUiEvent {
  const AgUiRunStarted(this.runId);
  final String runId;
}

/// How a run ended: plain success, or parked on interrupts.
sealed class AgUiRunOutcome {
  const AgUiRunOutcome();
}

class AgUiRunSucceeded extends AgUiRunOutcome {
  const AgUiRunSucceeded();
}

class AgUiRunInterrupted extends AgUiRunOutcome {
  const AgUiRunInterrupted(this.interrupts);
  final List<AgUiInterrupt> interrupts;
}

class AgUiRunFinished extends AgUiEvent {
  const AgUiRunFinished(this.runId, {this.outcome});
  final String runId;
  final AgUiRunOutcome? outcome;
}

class AgUiRunCancelled extends AgUiEvent {
  const AgUiRunCancelled({this.runId});
  final String? runId;
}

class AgUiRunError extends AgUiEvent {
  const AgUiRunError({this.message, this.code});
  final String? message;
  final String? code;
}

class AgUiTextMessageStart extends AgUiEvent {
  const AgUiTextMessageStart({this.messageId, this.subagentRunId});
  final String? messageId;
  final String? subagentRunId;
}

class AgUiTextMessageContent extends AgUiEvent {
  const AgUiTextMessageContent(this.delta, {this.messageId, this.subagentRunId});
  final String delta;
  final String? messageId;
  final String? subagentRunId;
}

class AgUiTextMessageEnd extends AgUiEvent {
  const AgUiTextMessageEnd({this.messageId, this.subagentRunId});
  final String? messageId;
  final String? subagentRunId;
}

/// A one-shot text delta, for servers that skip the start/end pair.
class AgUiTextMessageChunk extends AgUiEvent {
  const AgUiTextMessageChunk(this.delta, {this.messageId, this.subagentRunId});
  final String delta;
  final String? messageId;
  final String? subagentRunId;
}

class AgUiThinkingStart extends AgUiEvent {
  const AgUiThinkingStart({this.title});
  final String? title;
}

class AgUiThinkingTextMessageStart extends AgUiEvent {
  const AgUiThinkingTextMessageStart();
}

class AgUiThinkingTextMessageContent extends AgUiEvent {
  const AgUiThinkingTextMessageContent(this.delta);
  final String delta;
}

class AgUiThinkingTextMessageEnd extends AgUiEvent {
  const AgUiThinkingTextMessageEnd();
}

class AgUiThinkingEnd extends AgUiEvent {
  const AgUiThinkingEnd();
}

class AgUiReasoningStart extends AgUiEvent {
  const AgUiReasoningStart({this.messageId, this.subagentRunId});
  final String? messageId;
  final String? subagentRunId;
}

class AgUiReasoningMessageStart extends AgUiEvent {
  const AgUiReasoningMessageStart({this.messageId, this.subagentRunId});
  final String? messageId;
  final String? subagentRunId;
}

class AgUiReasoningMessageContent extends AgUiEvent {
  const AgUiReasoningMessageContent(
    this.delta, {
    this.messageId,
    this.subagentRunId,
  });
  final String delta;
  final String? messageId;
  final String? subagentRunId;
}

class AgUiReasoningMessageEnd extends AgUiEvent {
  const AgUiReasoningMessageEnd({this.messageId, this.subagentRunId});
  final String? messageId;
  final String? subagentRunId;
}

/// Provider-side encrypted reasoning, carried through untouched.
class AgUiReasoningEncryptedValue extends AgUiEvent {
  const AgUiReasoningEncryptedValue({
    required this.subtype,
    required this.entityId,
    required this.encryptedValue,
    this.subagentRunId,
  });

  /// `message` or `tool-call`.
  final String subtype;
  final String entityId;
  final String encryptedValue;
  final String? subagentRunId;
}

class AgUiReasoningEnd extends AgUiEvent {
  const AgUiReasoningEnd({this.messageId, this.subagentRunId});
  final String? messageId;
  final String? subagentRunId;
}

class AgUiToolCallStart extends AgUiEvent {
  const AgUiToolCallStart({
    required this.toolCallId,
    this.toolCallName,
    this.parentMessageId,
    this.subagentRunId,
  });

  final String toolCallId;
  final String? toolCallName;
  final String? parentMessageId;
  final String? subagentRunId;
}

class AgUiToolCallArgs extends AgUiEvent {
  const AgUiToolCallArgs(this.toolCallId, this.delta, {this.subagentRunId});
  final String toolCallId;
  final String delta;
  final String? subagentRunId;
}

class AgUiToolCallEnd extends AgUiEvent {
  const AgUiToolCallEnd(this.toolCallId, {this.subagentRunId});
  final String toolCallId;
  final String? subagentRunId;
}

class AgUiToolCallChunk extends AgUiEvent {
  const AgUiToolCallChunk({
    this.toolCallId,
    this.toolCallName,
    this.parentMessageId,
    this.delta,
    this.subagentRunId,
  });

  final String? toolCallId;
  final String? toolCallName;
  final String? parentMessageId;
  final String? delta;
  final String? subagentRunId;
}

class AgUiToolCallResult extends AgUiEvent {
  const AgUiToolCallResult({
    required this.toolCallId,
    required this.content,
    this.messageId,
    this.isToolRole = false,
    this.subagentRunId,
  });

  final String toolCallId;
  final String content;
  final String? messageId;
  final bool isToolRole;
  final String? subagentRunId;
}

class AgUiStateSnapshot extends AgUiEvent {
  const AgUiStateSnapshot(this.snapshot);
  final Object? snapshot;
}

class AgUiStateDelta extends AgUiEvent {
  const AgUiStateDelta(this.delta);
  final List<Object?> delta;
}

class AgUiMessagesSnapshot extends AgUiEvent {
  const AgUiMessagesSnapshot(this.messages);
  final List<Object?> messages;
}

class AgUiActivitySnapshot extends AgUiEvent {
  const AgUiActivitySnapshot({
    required this.activityType,
    required this.content,
    this.messageId,
    this.replace,
    this.subagentRunId,
  });

  final String activityType;
  final Map<String, Object?> content;
  final String? messageId;
  final bool? replace;
  final String? subagentRunId;
}

class AgUiRaw extends AgUiEvent {
  const AgUiRaw({this.event, this.source});
  final Object? event;
  final String? source;
}

class AgUiCustom extends AgUiEvent {
  const AgUiCustom(this.name, {this.value});
  final String name;
  final Object? value;
}

class AgUiSubagentStarted extends AgUiEvent {
  const AgUiSubagentStarted({
    required this.subagentRunId,
    required this.name,
    this.description,
    this.parentSubagentRunId,
    this.parentToolCallId,
    this.parentMessageId,
  });

  final String subagentRunId;
  final String name;
  final String? description;
  final String? parentSubagentRunId;
  final String? parentToolCallId;
  final String? parentMessageId;
}

sealed class AgUiSubagentOutcome {
  const AgUiSubagentOutcome();
}

class AgUiSubagentSucceeded extends AgUiSubagentOutcome {
  const AgUiSubagentSucceeded();
}

class AgUiSubagentSuspended extends AgUiSubagentOutcome {
  const AgUiSubagentSuspended(this.interruptIds);
  final List<String> interruptIds;
}

class AgUiSubagentFinished extends AgUiEvent {
  const AgUiSubagentFinished({
    required this.subagentRunId,
    this.result,
    this.outcome,
  });

  final String subagentRunId;
  final Object? result;
  final AgUiSubagentOutcome? outcome;
}

class AgUiSubagentError extends AgUiEvent {
  const AgUiSubagentError({
    required this.subagentRunId,
    required this.message,
    this.code,
  });

  final String subagentRunId;
  final String message;
  final String? code;
}

/// A gate the run parked on: the host answers it and resumes.
class AgUiInterrupt {
  const AgUiInterrupt({
    required this.id,
    required this.reason,
    this.message,
    this.toolCallId,
    this.expiresAt,
    this.responseSchema,
    this.metadata,
  });

  final String id;
  final String reason;
  final String? message;
  final String? toolCallId;
  final String? expiresAt;

  /// A JSON Schema the answer must satisfy, when the server sent one.
  final Object? responseSchema;
  final Map<String, Object?>? metadata;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'reason': reason,
        if (message != null) 'message': message,
        if (toolCallId != null) 'toolCallId': toolCallId,
        if (expiresAt != null) 'expiresAt': expiresAt,
        if (responseSchema != null) 'responseSchema': responseSchema,
        if (metadata != null) 'metadata': metadata,
      };
}

/// Reads one wire event. Malformed events return null; unknown types come back
/// as [AgUiRaw] with the type as their source, the way upstream tolerates them.
AgUiEvent? parseAgUiEvent(Object? raw) {
  if (raw is! Map<String, Object?>) return null;
  final Object? type = raw['type'];
  if (type is! String) return null;

  String? string(String key) {
    final Object? value = raw[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  String? optional(String key) {
    final Object? value = raw[key];
    return value is String ? value : null;
  }

  switch (type) {
    case 'RUN_STARTED':
      final String? runId = string('runId');
      return runId == null ? null : AgUiRunStarted(runId);
    case 'RUN_FINISHED':
      final String? runId = string('runId');
      if (runId == null) return null;
      return AgUiRunFinished(runId, outcome: _parseRunOutcome(raw['outcome']));
    case 'RUN_CANCELLED':
      return AgUiRunCancelled(runId: optional('runId'));
    case 'RUN_ERROR':
      return AgUiRunError(message: optional('message'), code: optional('code'));
    case 'TEXT_MESSAGE_START':
      return AgUiTextMessageStart(
        messageId: optional('messageId'),
        subagentRunId: optional('subagentRunId'),
      );
    case 'TEXT_MESSAGE_CONTENT':
      final String? delta = string('delta');
      if (delta == null) return null;
      return AgUiTextMessageContent(
        delta,
        messageId: optional('messageId'),
        subagentRunId: optional('subagentRunId'),
      );
    case 'TEXT_MESSAGE_END':
      return AgUiTextMessageEnd(
        messageId: optional('messageId'),
        subagentRunId: optional('subagentRunId'),
      );
    case 'TEXT_MESSAGE_CHUNK':
      return AgUiTextMessageChunk(
        optional('delta') ?? '',
        messageId: optional('messageId'),
        subagentRunId: optional('subagentRunId'),
      );
    case 'THINKING_START':
      return AgUiThinkingStart(title: optional('title'));
    case 'THINKING_TEXT_MESSAGE_START':
      return const AgUiThinkingTextMessageStart();
    case 'THINKING_TEXT_MESSAGE_CONTENT':
      return AgUiThinkingTextMessageContent(optional('delta') ?? '');
    case 'THINKING_TEXT_MESSAGE_END':
      return const AgUiThinkingTextMessageEnd();
    case 'THINKING_END':
      return const AgUiThinkingEnd();
    case 'REASONING_START':
      return AgUiReasoningStart(
        messageId: optional('messageId'),
        subagentRunId: optional('subagentRunId'),
      );
    case 'REASONING_MESSAGE_START':
      return AgUiReasoningMessageStart(
        messageId: optional('messageId'),
        subagentRunId: optional('subagentRunId'),
      );
    case 'REASONING_MESSAGE_CONTENT':
      return AgUiReasoningMessageContent(
        optional('delta') ?? '',
        messageId: optional('messageId'),
        subagentRunId: optional('subagentRunId'),
      );
    case 'REASONING_MESSAGE_END':
      return AgUiReasoningMessageEnd(
        messageId: optional('messageId'),
        subagentRunId: optional('subagentRunId'),
      );
    case 'REASONING_ENCRYPTED_VALUE':
      final String? entityId = string('entityId');
      final String? value = string('encryptedValue');
      final String? subtype = optional('subtype');
      if (entityId == null || value == null) return null;
      if (subtype != 'message' && subtype != 'tool-call') return null;
      return AgUiReasoningEncryptedValue(
        subtype: subtype!,
        entityId: entityId,
        encryptedValue: value,
        subagentRunId: optional('subagentRunId'),
      );
    case 'REASONING_END':
      return AgUiReasoningEnd(
        messageId: optional('messageId'),
        subagentRunId: optional('subagentRunId'),
      );
    case 'TOOL_CALL_START':
      final String? toolCallId = string('toolCallId');
      if (toolCallId == null) return null;
      return AgUiToolCallStart(
        toolCallId: toolCallId,
        toolCallName: optional('toolCallName'),
        parentMessageId: optional('parentMessageId'),
        subagentRunId: optional('subagentRunId'),
      );
    case 'TOOL_CALL_ARGS':
      final String? toolCallId = string('toolCallId');
      if (toolCallId == null) return null;
      return AgUiToolCallArgs(
        toolCallId,
        optional('delta') ?? '',
        subagentRunId: optional('subagentRunId'),
      );
    case 'TOOL_CALL_END':
      final String? toolCallId = string('toolCallId');
      if (toolCallId == null) return null;
      return AgUiToolCallEnd(toolCallId, subagentRunId: optional('subagentRunId'));
    case 'TOOL_CALL_CHUNK':
      return AgUiToolCallChunk(
        toolCallId: optional('toolCallId'),
        toolCallName: optional('toolCallName'),
        parentMessageId: optional('parentMessageId'),
        delta: optional('delta'),
        subagentRunId: optional('subagentRunId'),
      );
    case 'TOOL_CALL_RESULT':
      final String? toolCallId = string('toolCallId');
      if (toolCallId == null) return null;
      return AgUiToolCallResult(
        toolCallId: toolCallId,
        content: optional('content') ?? '',
        messageId: optional('messageId'),
        isToolRole: raw['role'] == 'tool',
        subagentRunId: optional('subagentRunId'),
      );
    case 'STATE_SNAPSHOT':
      if (!raw.containsKey('snapshot')) return null;
      return AgUiStateSnapshot(raw['snapshot']);
    case 'STATE_DELTA':
      final Object? delta = raw['delta'];
      return AgUiStateDelta(
        delta is List<Object?> ? delta : const <Object?>[],
      );
    case 'MESSAGES_SNAPSHOT':
      final Object? messages = raw['messages'];
      if (messages is! List<Object?>) return null;
      return AgUiMessagesSnapshot(messages);
    case 'ACTIVITY_SNAPSHOT':
      final String? activityType = string('activityType');
      final Object? content = raw['content'];
      if (activityType == null || content is! Map<String, Object?>) return null;
      return AgUiActivitySnapshot(
        activityType: activityType,
        content: content,
        messageId: optional('messageId'),
        replace: raw['replace'] is bool ? raw['replace']! as bool : null,
        subagentRunId: optional('subagentRunId'),
      );
    case 'RAW':
      return AgUiRaw(event: raw['event'], source: optional('source'));
    case 'CUSTOM':
      final String? name = string('name');
      if (name == null) return null;
      return AgUiCustom(name, value: raw['value']);
    case 'SUBAGENT_STARTED':
      final String? subagentRunId = string('subagentRunId');
      final String? name = string('name');
      if (subagentRunId == null || name == null) return null;
      return AgUiSubagentStarted(
        subagentRunId: subagentRunId,
        name: name,
        description: optional('description'),
        parentSubagentRunId: optional('parentSubagentRunId'),
        parentToolCallId: optional('parentToolCallId'),
        parentMessageId: optional('parentMessageId'),
      );
    case 'SUBAGENT_FINISHED':
      final String? subagentRunId = string('subagentRunId');
      if (subagentRunId == null) return null;
      return AgUiSubagentFinished(
        subagentRunId: subagentRunId,
        result: raw['result'],
        outcome: _parseSubagentOutcome(raw['outcome']),
      );
    case 'SUBAGENT_ERROR':
      final String? subagentRunId = string('subagentRunId');
      final String? message = string('message');
      if (subagentRunId == null || message == null) return null;
      return AgUiSubagentError(
        subagentRunId: subagentRunId,
        message: message,
        code: optional('code'),
      );
    default:
      return AgUiRaw(event: raw, source: type);
  }
}

AgUiRunOutcome? _parseRunOutcome(Object? raw) {
  if (raw is! Map<String, Object?>) return null;
  if (raw['type'] == 'success') return const AgUiRunSucceeded();
  if (raw['type'] != 'interrupt') return null;
  final Object? interrupts = raw['interrupts'];
  if (interrupts is! List<Object?>) return null;
  final List<AgUiInterrupt> parsed = <AgUiInterrupt>[
    for (final Object? entry in interrupts)
      if (_parseInterrupt(entry) case final AgUiInterrupt interrupt) interrupt,
  ];
  if (parsed.isEmpty) return null;
  return AgUiRunInterrupted(parsed);
}

AgUiSubagentOutcome? _parseSubagentOutcome(Object? raw) {
  if (raw is! Map<String, Object?>) return null;
  if (raw['type'] == 'success') return const AgUiSubagentSucceeded();
  if (raw['type'] != 'suspended') return null;
  final Object? ids = raw['interruptIds'];
  return AgUiSubagentSuspended(<String>[
    if (ids is List<Object?>)
      for (final Object? id in ids)
        if (id is String) id,
  ]);
}

AgUiInterrupt? _parseInterrupt(Object? raw) {
  if (raw is! Map<String, Object?>) return null;
  final Object? id = raw['id'];
  final Object? reason = raw['reason'];
  if (id is! String || reason is! String) return null;
  String? text(Object? value) => value is String ? value : null;
  final Object? schema = raw['responseSchema'];
  return AgUiInterrupt(
    id: id,
    reason: reason,
    message: text(raw['message']),
    toolCallId: text(raw['toolCallId']),
    expiresAt: text(raw['expiresAt']),
    // `null` reads as absent: it is what a server sends for an unset field.
    responseSchema: schema,
    metadata: raw['metadata'] is Map<String, Object?>
        ? raw['metadata']! as Map<String, Object?>
        : null,
  );
}

/// What a run sends: the AG-UI `RunAgentInput`.
class AgUiRunAgentInput {
  const AgUiRunAgentInput({
    required this.threadId,
    required this.runId,
    this.messages = const <Map<String, Object?>>[],
    this.tools = const <Map<String, Object?>>[],
    this.state,
    this.context = const <Map<String, Object?>>[],
    this.forwardedProps,
    this.resume = const <Map<String, Object?>>[],
  });

  final String threadId;
  final String runId;
  final List<Map<String, Object?>> messages;
  final List<Map<String, Object?>> tools;
  final Object? state;
  final List<Map<String, Object?>> context;
  final Object? forwardedProps;

  /// Answers to the interrupts that parked the previous run.
  final List<Map<String, Object?>> resume;

  Map<String, Object?> toJson() => <String, Object?>{
        'threadId': threadId,
        'runId': runId,
        'messages': messages,
        'tools': tools,
        'state': state,
        'context': context,
        'forwardedProps': forwardedProps,
        if (resume.isNotEmpty) 'resume': resume,
      };
}

/// Posts a run and reads the event stream back.
///
/// The transport is the one AG-UI specifies: a POST whose response is an SSE
/// stream of `data:` payloads, one event each.
class AgUiAgent {
  AgUiAgent({required this.url, this.headers = const <String, String>{}, http.Client? client})
      : _client = client ?? http.Client();

  final String url;
  final Map<String, String> headers;
  final http.Client _client;

  Stream<AgUiEvent> run(AgUiRunAgentInput input, {AbortSignal? abortSignal}) {
    final StreamController<AgUiEvent> controller = StreamController<AgUiEvent>();

    Future<void> pump() async {
      try {
        final http.Request request = http.Request('POST', Uri.parse(url))
          ..headers.addAll(<String, String>{
            'content-type': 'application/json',
            'accept': 'text/event-stream',
            ...headers,
          })
          ..body = jsonEncode(input.toJson());
        final http.StreamedResponse response =
            await _client.send(request);
        if (response.statusCode >= 400) {
          final String body = await response.stream.bytesToString();
          throw AgUiException(
            'HTTP ${response.statusCode} from $url: $body',
          );
        }
        final Stream<String> lines = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());
        await for (final String line in lines) {
          if (abortSignal?.isAborted ?? false) break;
          if (!line.startsWith('data:')) continue;
          final String payload = line.substring(5).trim();
          if (payload.isEmpty || payload == '[DONE]') continue;
          final Object? decoded = jsonDecode(payload);
          final AgUiEvent? event = parseAgUiEvent(decoded);
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

  void close() => _client.close();
}

/// Raised for transport failures and server-side run errors.
class AgUiException implements Exception {
  const AgUiException(this.message);

  final String message;

  @override
  String toString() => 'AgUiException: $message';
}

/// Bridges an AG-UI endpoint onto the package's [ChatModelAdapter] contract.
///
/// Deltas accumulate into the parts the runtime streams: text, reasoning and
/// tool calls. Events with no part of their own (state, activity, custom,
/// subagents) travel as data parts so the host can render them.
class AgUiChatModelAdapter extends ChatModelAdapter {
  AgUiChatModelAdapter({
    required this.url,
    this.headers = const <String, String>{},
    this.threadId,
    this.forwardedProps,
    this.tools = const <String, Object?>{},
    http.Client? client,
  }) : _agent = AgUiAgent(url: url, headers: headers, client: client);

  final String url;
  final Map<String, String> headers;

  /// Overrides the thread id sent with each run; defaults to one per adapter.
  final String? threadId;
  final Object? forwardedProps;

  /// Tool schemas announced to the agent, keyed by name.
  final Map<String, Object?> tools;

  final AgUiAgent _agent;

  String? _defaultThreadId;

  /// Interrupts the last run parked on, in arrival order.
  final List<AgUiInterrupt> pendingInterrupts = <AgUiInterrupt>[];

  /// Data parts collected from the last run, by name.
  final Map<String, Object?> lastState = <String, Object?>{};

  @override
  Stream<ChatModelRunResult> run(ChatModelRunContext context) async* {
    final String thread =
        threadId ?? (_defaultThreadId ??= 'thread-${DateTime.now().microsecondsSinceEpoch}');
    final String runId = 'run-${DateTime.now().microsecondsSinceEpoch}';
    final AgUiRunAgentInput input = AgUiRunAgentInput(
      threadId: thread,
      runId: runId,
      messages: <Map<String, Object?>>[
        for (final ThreadMessage message in context.messages) message.toJson(),
      ],
      tools: <Map<String, Object?>>[
        for (final MapEntry<String, Object?> entry in tools.entries)
          if (entry.value is Map<String, Object?>)
            <String, Object?>{
              'name': entry.key,
              ...entry.value! as Map<String, Object?>,
            }
          else
            <String, Object?>{'name': entry.key},
      ],
      forwardedProps: forwardedProps,
    );

    pendingInterrupts.clear();
    yield* _consume(input, context);
  }

  Stream<ChatModelRunResult> _consume(
    AgUiRunAgentInput input,
    ChatModelRunContext context,
  ) async* {
    final List<MessagePart> parts = <MessagePart>[];
    final Map<String, String> toolArgs = <String, String>{};
    final Map<String, AgUiToolCallStart> toolStarts =
        <String, AgUiToolCallStart>{};
    final Map<String, String> toolResults = <String, String>{};
    final StringBuffer text = StringBuffer();
    final StringBuffer reasoning = StringBuffer();
    bool interrupted = false;

    void emit() {
      parts
        ..clear()
        ..addAll(<MessagePart>[
          if (reasoning.isNotEmpty) ReasoningPart(reasoning.toString()),
          if (text.isNotEmpty) TextPart(text.toString()),
          for (final MapEntry<String, AgUiToolCallStart> entry
              in toolStarts.entries)
            ToolCallPart(
              toolCallId: entry.key,
              toolName: entry.value.toolCallName ?? 'tool',
              args: _decodeArgs(toolArgs[entry.key]),
              result: toolResults[entry.key],
            ),
        ]);
    }

    await for (final AgUiEvent event in _agent.run(
      input,
      abortSignal: context.abortSignal,
    )) {
      switch (event) {
        case AgUiTextMessageContent(:final String delta):
        case AgUiTextMessageChunk(:final String delta):
          text.write(delta);
        case AgUiThinkingTextMessageContent(:final String delta):
        case AgUiReasoningMessageContent(:final String delta):
          reasoning.write(delta);
        case AgUiToolCallStart():
          toolStarts[event.toolCallId] = event;
          toolArgs[event.toolCallId] = '';
          parts.add(
            ToolCallPart(
              toolCallId: event.toolCallId,
              toolName: event.toolCallName ?? 'tool',
            ),
          );
        case AgUiToolCallArgs(:final String toolCallId, :final String delta):
          toolArgs[toolCallId] = (toolArgs[toolCallId] ?? '') + delta;
        case AgUiToolCallChunk(
            :final String? toolCallId,
            :final String? toolCallName,
            :final String? delta
          ):
          if (toolCallId != null) {
            toolStarts[toolCallId] ??= AgUiToolCallStart(
              toolCallId: toolCallId,
              toolCallName: toolCallName,
            );
            toolArgs[toolCallId] = (toolArgs[toolCallId] ?? '') + (delta ?? '');
          }
        case AgUiToolCallResult(:final String toolCallId, :final String content):
          // The result lands on the call it answers; a result without a call
          // still shows up as a text part so nothing is lost.
          if (toolStarts.containsKey(toolCallId)) {
            toolResults[toolCallId] = content;
          } else if (content.isNotEmpty) {
            text.write(content);
          }
        case AgUiStateSnapshot(:final Object? snapshot):
          lastState['snapshot'] = snapshot;
        case AgUiActivitySnapshot():
          lastState[event.activityType] = event.content;
        case AgUiCustom(:final String name, :final Object? value):
          lastState[name] = value;
        case AgUiRunFinished(:final AgUiRunOutcome? outcome):
          if (outcome is AgUiRunInterrupted) {
            interrupted = true;
            pendingInterrupts.addAll(outcome.interrupts);
          }
        case AgUiRunError(:final String? message, :final String? code):
          throw AgUiException(message ?? code ?? 'The run failed');
        case AgUiRunCancelled():
          return;
        default:
          break;
      }

      emit();
      yield ChatModelRunResult(
        content: List<MessagePart>.unmodifiable(parts),
        status: interrupted
            ? const MessageStatusRequiresAction()
            : const MessageStatusRunning(),
      );
    }

    emit();
    yield ChatModelRunResult(
      content: List<MessagePart>.unmodifiable(parts),
      status: interrupted
          ? const MessageStatusRequiresAction()
          : const MessageStatusComplete(),
    );
  }

  Object? _decodeArgs(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } on FormatException {
      // A stream cut mid-argument leaves a fragment; keep it readable.
      return raw;
    }
  }
}
