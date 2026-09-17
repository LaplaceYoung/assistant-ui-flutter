import 'dart:convert';

import '../core/message_part.dart';

/// Frame codes of the Vercel AI data stream v1 — the wire format
/// `createAssistantStreamResponse` (assistant-stream) and AI SDK v4's
/// `toDataStreamResponse()` produce.
///
/// A frame is `<code>:<json>\n`. Blank lines are framing, unknown codes are
/// ignored, malformed frames are dropped: the same tolerance the upstream
/// `DataStreamChunkDecoder` applies.
abstract final class DataStreamChunkType {
  static const String textDelta = '0';
  static const String data = '2';
  static const String error = '3';
  static const String annotation = '8';
  static const String toolCall = '9';
  static const String toolCallResult = 'a';
  static const String startToolCall = 'b';
  static const String toolCallArgsTextDelta = 'c';
  static const String finishMessage = 'd';
  static const String finishStep = 'e';
  static const String startStep = 'f';
  static const String reasoningDelta = 'g';
  static const String source = 'h';
  static const String redactedReasoning = 'i';
  static const String reasoningSignature = 'j';
  static const String file = 'k';

  // assistant-ui extensions.
  static const String auiTextDelta = 'aui-text-delta';
  static const String auiReasoningDelta = 'aui-reasoning-delta';
  static const String auiReasoningPartStart = 'aui-reasoning-part-start';
  static const String auiDataPart = 'aui-data';
  static const String auiUpdateStateOperations = 'aui-state';
}

class _Segment {
  _Segment.text() : kind = 'text';
  _Segment.reasoning() : kind = 'reasoning';
  _Segment.toolCall(ToolCallPart part)
      : kind = 'tool-call',
        tool = part;
  _Segment.part(MessagePart part)
      : kind = 'part',
        fixed = part;

  final String kind;
  final StringBuffer buffer = StringBuffer();
  ToolCallPart? tool;
  MessagePart? fixed;
}

/// Incremental parser for the data stream protocol.
///
/// Feed raw text through [addChunk] (it splits lines and keeps the tail) or
/// complete frames through [addLine]. Read [parts] after any frame that
/// returned true for the message content so far.
///
/// Text and reasoning deltas extend the part they are already in; a delta of a
/// different kind starts a new part, so `text → tool call → text` streams as
/// three parts.
class DataStreamParser {
  final List<_Segment> _segments = <_Segment>[];
  final Map<String, int> _toolCallIndex = <String, int>{};
  final Map<String, StringBuffer> _toolArgsText = <String, StringBuffer>{};
  final StringBuffer _tail = StringBuffer();

  String? _error;
  String? _finishReason;
  Map<String, Object?>? _usage;
  bool _messageFinished = false;

  /// Error frame payload, if one arrived.
  String? get error => _error;

  /// Finish reason from the `d` frame: `stop`, `tool-calls`, `length`, ...
  String? get finishReason => _finishReason;

  Map<String, Object?>? get usage => _usage;

  /// True once the `d` frame arrived.
  bool get messageFinished => _messageFinished;

  /// Cumulative content, in stream order.
  List<MessagePart> get parts => List<MessagePart>.unmodifiable(<MessagePart>[
        for (final _Segment segment in _segments)
          switch (segment.kind) {
            'text' => TextPart(segment.buffer.toString()),
            'reasoning' => ReasoningPart(segment.buffer.toString()),
            'tool-call' => segment.tool!,
            _ => segment.fixed!,
          },
      ]);

  /// Feeds one raw chunk; returns true when the parsed state changed.
  void addChunk(String chunk) {
    _tail.write(chunk);
    final String buffered = _tail.toString();
    int start = 0;
    for (int i = 0; i < buffered.length; i++) {
      final String character = buffered[i];
      if (character != '\n' && character != '\r') continue;
      final String line = buffered.substring(start, i);
      if (character == '\r' &&
          i + 1 < buffered.length &&
          buffered[i + 1] == '\n') {
        start = i + 2;
        i++;
      } else {
        start = i + 1;
      }
      addLine(line);
    }
    _tail
      ..clear()
      ..write(buffered.substring(start));
  }

  /// Feeds one frame. Returns true when the parsed state changed.
  bool addLine(String rawLine) {
    if (rawLine.trim().isEmpty) return false;

    // SSE transports wrap each frame as `data: <frame>`.
    String line = rawLine;
    if (line.startsWith('data:')) {
      line = line.substring(5);
      if (line.startsWith(' ')) line = line.substring(1);
      if (line.trim().isEmpty) return false;
    }

    final int separator = line.indexOf(':');
    if (separator == -1) return false;
    final String code = line.substring(0, separator);
    final Object? value;
    try {
      value = jsonDecode(line.substring(separator + 1));
    } on FormatException {
      return false;
    }
    return _apply(code, value);
  }

  bool _apply(String code, Object? value) {
    switch (code) {
      case DataStreamChunkType.textDelta:
        _appendText('text', value! as String);
        return true;

      case DataStreamChunkType.auiTextDelta:
        _appendText('text', _string(value, 'textDelta'));
        return true;

      case DataStreamChunkType.reasoningDelta:
        _appendText('reasoning', value! as String);
        return true;

      case DataStreamChunkType.auiReasoningDelta:
        _appendText('reasoning', _string(value, 'reasoningDelta'));
        return true;

      case DataStreamChunkType.redactedReasoning:
        _appendText('reasoning', '[redacted]');
        return true;

      case DataStreamChunkType.toolCall:
      case DataStreamChunkType.startToolCall:
        _upsertToolCall(
          _string(value, 'toolCallId'),
          _string(value, 'toolName'),
          args: _map(value)['args'] as Map<String, Object?>?,
        );
        return true;

      case DataStreamChunkType.toolCallArgsTextDelta:
        _appendToolArgs(
          _string(value, 'toolCallId'),
          _string(value, 'argsTextDelta'),
          isFinal: _map(value)['isFinal'] == true,
        );
        return true;

      case DataStreamChunkType.toolCallResult:
        _setToolResult(
          _string(value, 'toolCallId'),
          _map(value)['result'],
          isError: _map(value)['isError'] == true,
        );
        return true;

      case DataStreamChunkType.source:
        _segments.add(_Segment.part(SourcePart(
          sourceType: _map(value)['sourceType'] as String?,
          id: _map(value)['id'] as String?,
          url: _map(value)['url'] as String?,
          title: _map(value)['title'] as String?,
        )));
        return true;

      case DataStreamChunkType.file:
        _segments.add(_Segment.part(FilePart(
          data: _map(value)['data'] as String?,
          mimeType: (_map(value)['mimeType'] as String?) ??
              'application/octet-stream',
        )));
        return true;

      case DataStreamChunkType.auiDataPart:
        _segments.add(_Segment.part(DataPart(
          name: (_map(value)['name'] as String?) ?? 'data',
          data: _map(value)['data'],
        )));
        return true;

      case DataStreamChunkType.data:
        _segments.add(_Segment.part(DataPart(name: 'data', data: value)));
        return true;

      case DataStreamChunkType.error:
        _error = value! as String;
        return true;

      case DataStreamChunkType.finishMessage:
        final Map<String, Object?> frame = _map(value);
        _finishReason = frame['finishReason'] as String?;
        _usage = frame['usage'] as Map<String, Object?>?;
        _messageFinished = true;
        return true;

      // Frames this port does not render: step boundaries and signatures.
      case DataStreamChunkType.finishStep:
      case DataStreamChunkType.startStep:
      case DataStreamChunkType.annotation:
      case DataStreamChunkType.reasoningSignature:
      case DataStreamChunkType.auiReasoningPartStart:
      case DataStreamChunkType.auiUpdateStateOperations:
        return false;

      default:
        return false;
    }
  }

  static String _string(Object? value, String key) =>
      (_map(value)[key]! as String);

  static Map<String, Object?> _map(Object? value) => value is Map
      ? value.cast<String, Object?>()
      : const <String, Object?>{};

  void _appendText(String kind, String delta) {
    if (delta.isEmpty) return;
    if (_segments.isNotEmpty && _segments.last.kind == kind) {
      _segments.last.buffer.write(delta);
      return;
    }
    final _Segment segment =
        kind == 'text' ? _Segment.text() : _Segment.reasoning();
    segment.buffer.write(delta);
    _segments.add(segment);
  }

  void _upsertToolCall(
    String toolCallId,
    String toolName, {
    Map<String, Object?>? args,
  }) {
    final int? existingIndex = _toolCallIndex[toolCallId];
    if (existingIndex != null) {
      final ToolCallPart existing = _segments[existingIndex].tool!;
      _segments[existingIndex].tool = ToolCallPart(
        toolCallId: toolCallId,
        toolName: toolName.isEmpty ? existing.toolName : toolName,
        args: args ?? existing.args,
        result: existing.result,
        isError: existing.isError,
      );
      return;
    }
    _segments.add(_Segment.toolCall(ToolCallPart(
      toolCallId: toolCallId,
      toolName: toolName,
      args: args,
    )));
    _toolCallIndex[toolCallId] = _segments.length - 1;
  }

  /// Accumulates JSON text fragments until they parse into an object.
  ///
  /// While incomplete, `args` holds the raw fragment so a tool UI can still
  /// show what the model is producing.
  void _appendToolArgs(
    String toolCallId,
    String delta, {
    required bool isFinal,
  }) {
    final int? index = _toolCallIndex[toolCallId];
    if (index == null) return;
    final StringBuffer buffer =
        _toolArgsText.putIfAbsent(toolCallId, StringBuffer.new)..write(delta);
    final String raw = buffer.toString();
    final ToolCallPart existing = _segments[index].tool!;

    Object? args = raw.isEmpty ? existing.args : raw;
    if (isFinal || raw.trim().startsWith('{')) {
      try {
        args = jsonDecode(raw);
      } on FormatException {
        args = raw;
      }
    }
    _segments[index].tool = ToolCallPart(
      toolCallId: toolCallId,
      toolName: existing.toolName,
      args: args,
      result: existing.result,
      isError: existing.isError,
    );
  }

  void _setToolResult(
    String toolCallId,
    Object? result, {
    required bool isError,
  }) {
    final int? index = _toolCallIndex[toolCallId];
    if (index == null) return;
    final ToolCallPart existing = _segments[index].tool!;
    _segments[index].tool =
        existing.copyWith(result: result, isError: isError);
  }
}
