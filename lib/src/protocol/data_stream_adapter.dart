import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/adapters.dart';
import '../core/attachments.dart';
import '../core/message.dart';
import '../core/message_part.dart';
import 'data_stream.dart';

/// [ChatModelAdapter] that talks to a backend speaking the Vercel AI data
/// stream v1 — what `createAssistantStreamResponse` (assistant-stream) and AI
/// SDK v4 `toDataStreamResponse()` emit.
///
/// Requests carry `{messages, tools, system, threadId}`, the same body shape
/// `@assistant-ui/react-data-stream` sends, so an existing endpoint needs no
/// changes.
class DataStreamChatModelAdapter extends ChatModelAdapter {
  DataStreamChatModelAdapter({
    required this.apiUrl,
    this.headers,
    this.extraBody,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Absolute endpoint URL, for example `https://api.example.com/chat`.
  ///
  /// On web, resolve a relative path first:
  /// `Uri.base.resolve('/api/chat').toString()`.
  final String apiUrl;

  /// Static headers, or a callback evaluated per request.
  final FutureOr<Map<String, String>> Function()? headers;

  /// Extra fields merged into the request body.
  final FutureOr<Map<String, Object?>> Function()? extraBody;

  final http.Client _client;

  void dispose() => _client.close();

  @override
  Stream<ChatModelRunResult> run(ChatModelRunContext context) {
    final StreamController<ChatModelRunResult> controller =
        StreamController<ChatModelRunResult>();
    final DataStreamParser parser = DataStreamParser();
    StreamSubscription<String>? subscription;

    Future<void> start() async {
      final Uri uri = Uri.parse(apiUrl);
      final Map<String, String> resolvedHeaders = <String, String>{
        'Content-Type': 'application/json',
        ...?await headers?.call(),
      };
      final Map<String, Object?> body = <String, Object?>{
        'messages': toGenericMessages(context.messages),
        if (context.context.systemPrompt != null)
          'system': context.context.systemPrompt,
        if (context.context.tools.isNotEmpty) 'tools': context.context.tools,
        ...?await extraBody?.call(),
      };

      final http.Request request = http.Request('POST', uri)
        ..headers.addAll(resolvedHeaders)
        ..body = jsonEncode(body);

      late final http.StreamedResponse response;
      try {
        response = await _client.send(request);
      } catch (error) {
        if (!controller.isClosed) {
          controller.add(ChatModelRunResult(
            content: parser.parts,
            status: MessageStatusIncomplete(
              reason: IncompleteReason.error,
              error: '$error',
            ),
          ));
          await controller.close();
        }
        return;
      }

      if (response.statusCode != 200) {
        final String message = await response.stream.bytesToString();
        if (!controller.isClosed) {
          controller.add(ChatModelRunResult(
            content: parser.parts,
            status: MessageStatusIncomplete(
              reason: IncompleteReason.error,
              error: 'HTTP ${response.statusCode}: ${message.trim()}',
            ),
          ));
          await controller.close();
        }
        return;
      }

      subscription = response.stream.transform(utf8.decoder).listen(
        (String chunk) {
          parser.addChunk(chunk);
          if (controller.isClosed) return;
          controller.add(ChatModelRunResult(content: parser.parts));
          if (parser.messageFinished) {
            controller.add(ChatModelRunResult(
              content: parser.parts,
              status: _terminalStatus(parser),
            ));
            unawaited(controller.close());
          }
        },
        onError: (Object error, StackTrace _) {
          if (controller.isClosed) return;
          controller.add(ChatModelRunResult(
            content: parser.parts,
            status: MessageStatusIncomplete(
              reason: IncompleteReason.error,
              error: '$error',
            ),
          ));
          unawaited(controller.close());
        },
        onDone: () {
          if (controller.isClosed) return;
          controller.add(ChatModelRunResult(
            content: parser.parts,
            status: _terminalStatus(parser),
          ));
          unawaited(controller.close());
        },
        cancelOnError: true,
      );

      context.abortSignal.addListener(() {
        unawaited(subscription?.cancel());
        if (!controller.isClosed) unawaited(controller.close());
      });
    }

    controller.onListen = () => unawaited(start());
    controller.onCancel = () => subscription?.cancel();
    return controller.stream;
  }

  static MessageStatus _terminalStatus(DataStreamParser parser) {
    if (parser.error != null) {
      return MessageStatusIncomplete(
        reason: IncompleteReason.error,
        error: parser.error,
      );
    }
    return switch (parser.finishReason) {
      'length' => const MessageStatusIncomplete(reason: IncompleteReason.length),
      'content-filter' =>
        const MessageStatusIncomplete(reason: IncompleteReason.contentFilter),
      _ => const MessageStatusComplete(),
    };
  }

  /// Converts thread messages into the generic wire format: `system`, `user`,
  /// `assistant` (text and tool calls), and a `tool` message per assistant
  /// message that has tool results.
  static List<Map<String, Object?>> toGenericMessages(
    List<ThreadMessage> messages,
  ) {
    final List<Map<String, Object?>> result = <Map<String, Object?>>[];
    for (final ThreadMessage message in messages) {
      switch (message.role) {
        case MessageRole.system:
          result.add(<String, Object?>{
            'role': 'system',
            'content': message.text,
          });
        case MessageRole.user:
          result.add(<String, Object?>{
            'role': 'user',
            'content': <Map<String, Object?>>[
              for (final MessagePart part in message.content)
                ..._userPartToGeneric(part),
              for (final AuiAttachment attachment in message.attachments)
                ..._userPartToGeneric(attachment.asPart),
            ],
          });
        case MessageRole.assistant:
          final List<Map<String, Object?>> content = <Map<String, Object?>>[];
          final List<Map<String, Object?>> toolResults =
              <Map<String, Object?>>[];
          for (final MessagePart part in message.content) {
            if (part is TextPart) {
              content.add(part.toJson());
              continue;
            }
            if (part is! ToolCallPart) continue;
            content.add(<String, Object?>{
              'type': 'tool-call',
              'toolCallId': part.toolCallId,
              'toolName': part.toolName,
              'args': part.args is Map ? part.args : <String, Object?>{},
            });
            if (part.hasResult) {
              toolResults.add(<String, Object?>{
                'type': 'tool-result',
                'toolCallId': part.toolCallId,
                'toolName': part.toolName,
                'result': part.result,
                if (part.isError) 'isError': true,
              });
            }
          }
          result.add(<String, Object?>{'role': 'assistant', 'content': content});
          if (toolResults.isNotEmpty) {
            result.add(<String, Object?>{
              'role': 'tool',
              'content': toolResults,
            });
          }
      }
    }
    return result;
  }

  static List<Map<String, Object?>> _userPartToGeneric(MessagePart part) {
    switch (part) {
      case TextPart():
        return <Map<String, Object?>>[part.toJson()];
      case ImagePart():
        return <Map<String, Object?>>[
          <String, Object?>{
            'type': 'file',
            'data': part.image,
            'mediaType': _mediaTypeOf(part.image, fallback: 'image/png'),
            if (part.filename != null) 'filename': part.filename,
          },
        ];
      case FilePart():
        return <Map<String, Object?>>[
          <String, Object?>{
            'type': 'file',
            if (part.data != null) 'data': part.data,
            'mediaType': part.mimeType,
            if (part.filename != null) 'filename': part.filename,
          },
        ];
      default:
        return const <Map<String, Object?>>[];
    }
  }

  static const Map<String, String> _extensionMediaTypes = <String, String>{
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'svg': 'image/svg+xml',
  };

  /// Media type from a data URI, the file extension, or [fallback].
  static String _mediaTypeOf(String url, {required String fallback}) {
    final RegExpMatch? dataUri =
        RegExp(r'^data:([^;,]+)', caseSensitive: false).firstMatch(url);
    if (dataUri != null) return dataUri.group(1)!.toLowerCase();
    final String path = Uri.tryParse(url)?.path ?? url;
    final int dot = path.lastIndexOf('.');
    if (dot != -1 && dot < path.length - 1) {
      final String extension = path.substring(dot + 1).toLowerCase();
      final String? known = _extensionMediaTypes[extension];
      if (known != null) return known;
    }
    return fallback;
  }
}
