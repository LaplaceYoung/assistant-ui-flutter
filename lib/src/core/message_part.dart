/// Message parts: the typed building blocks a message is made of.
///
/// Mirrors `MessagePart` from assistant-ui. Three kinds exist upstream, and
/// this port keeps the same split:
///
/// * modality — [TextPart], [ImagePart], [FilePart]
/// * provider channel — [ReasoningPart], [SourcePart], [ToolCallPart]
/// * extensibility — [DataPart], routed by [DataPart.name]
library;

/// Status of a single part inside a message.
///
/// A text or reasoning part reports [PartStatus.running] only while it is the
/// last part of the message — every earlier one reads as complete.
enum PartStatus { running, complete, incomplete }

/// Base class for everything a message can contain.
sealed class MessagePart {
  const MessagePart();

  /// Wire tag, matching assistant-ui's JSON (`text`, `tool-call`, ...).
  String get type;

  Map<String, Object?> toJson();

  /// Parses the assistant-ui / generic message wire format.
  static MessagePart fromJson(Map<String, Object?> json) {
    final String type = json['type']! as String;
    switch (type) {
      case 'text':
        return TextPart(json['text']! as String);
      case 'reasoning':
        return ReasoningPart(json['text']! as String);
      case 'image':
        return ImagePart(
          image: json['image']! as String,
          filename: json['filename'] as String?,
        );
      case 'file':
        return FilePart(
          data: json['data'] as String?,
          mimeType: (json['mimeType'] as String?) ?? 'application/octet-stream',
          filename: json['filename'] as String?,
        );
      case 'source':
        return SourcePart(
          sourceType: json['sourceType'] as String?,
          id: json['id'] as String?,
          url: json['url'] as String?,
          title: json['title'] as String?,
        );
      case 'quote':
        return QuotePart(
          text: json['text']! as String,
          messageId: json['messageId'] as String?,
          role: json['role'] as String?,
        );
      case 'tool-call':
        return ToolCallPart(
          toolCallId: json['toolCallId']! as String,
          toolName: json['toolName']! as String,
          args: json['args'],
          result: json['result'],
          isError: (json['isError'] as bool?) ?? false,
        );
      case 'data':
        return DataPart(name: json['name']! as String, data: json['data']);
      default:
        throw FormatException('Unknown message part type: $type');
    }
  }

  static List<MessagePart> listFromJson(List<Object?> json) => json
      .map((Object? e) => MessagePart.fromJson((e! as Map<String, Object?>)))
      .toList(growable: false);

  static List<Object?> listToJson(List<MessagePart> parts) =>
      parts.map((MessagePart p) => p.toJson()).toList(growable: false);
}

/// Plain text emitted by the model or typed by the user.
class TextPart extends MessagePart {
  const TextPart(this.text);

  final String text;

  /// Text parts are joined when a message is exported to markdown or copied.
  String get markdown => text;

  @override
  String get type => 'text';

  @override
  Map<String, Object?> toJson() => <String, Object?>{'type': 'text', 'text': text};

  @override
  String toString() => 'TextPart(${text.length} chars)';
}

/// Model reasoning / thinking output. Rendered inside a disclosure by default.
class ReasoningPart extends MessagePart {
  const ReasoningPart(this.text);

  final String text;

  @override
  String get type => 'reasoning';

  @override
  Map<String, Object?> toJson() =>
      <String, Object?>{'type': 'reasoning', 'text': text};
}

/// An inline image, either a URL or a `data:` URI.
class ImagePart extends MessagePart {
  const ImagePart({required this.image, this.filename});

  final String image;
  final String? filename;

  @override
  String get type => 'image';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': 'image',
        'image': image,
        if (filename != null) 'filename': filename,
      };
}

/// Any non-image binary modality. Audio, video and PDFs all travel as file
/// parts, distinguished by [mimeType].
class FilePart extends MessagePart {
  const FilePart({this.data, required this.mimeType, this.filename});

  /// Base64 payload, a URL, or null when the payload lives elsewhere.
  final String? data;
  final String mimeType;
  final String? filename;

  @override
  String get type => 'file';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': 'file',
        if (data != null) 'data': data,
        'mimeType': mimeType,
        if (filename != null) 'filename': filename,
      };
}

/// A citation or retrieval source attached to the answer.
class SourcePart extends MessagePart {
  const SourcePart({this.sourceType, this.id, this.url, this.title});

  final String? sourceType;
  final String? id;
  final String? url;
  final String? title;

  @override
  String get type => 'source';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': 'source',
        if (sourceType != null) 'sourceType': sourceType,
        if (id != null) 'id': id,
        if (url != null) 'url': url,
        if (title != null) 'title': title,
      };
}

/// A passage the user quoted from an earlier message. It travels as a part so
/// the model sees the quoted text in place, with the source message and role
/// kept alongside for the UI.
class QuotePart extends MessagePart {
  const QuotePart({required this.text, this.messageId, this.role});

  final String text;

  /// The message the passage came from; null for text quoted from outside.
  final String? messageId;

  /// `user` or `assistant` — which side wrote the quoted message.
  final String? role;

  @override
  String get type => 'quote';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': 'quote',
        'text': text,
        if (messageId != null) 'messageId': messageId,
        if (role != null) 'role': role,
      };
}

/// A model tool call. [result] is filled in once the tool has run — either by
/// the runtime (tool executors) or by the app (human-in-the-loop tools).
class ToolCallPart extends MessagePart {
  const ToolCallPart({
    required this.toolCallId,
    required this.toolName,
    this.args,
    this.result,
    this.isError = false,
  });

  final String toolCallId;
  final String toolName;
  final Object? args;
  final Object? result;
  final bool isError;

  bool get hasResult => result != null;

  /// Tool call status comes from the result, never from streaming position.
  PartStatus get status {
    if (hasResult) return isError ? PartStatus.incomplete : PartStatus.complete;
    return PartStatus.running;
  }

  ToolCallPart copyWith({Object? result, bool? isError}) => ToolCallPart(
        toolCallId: toolCallId,
        toolName: toolName,
        args: args,
        result: result ?? this.result,
        isError: isError ?? this.isError,
      );

  @override
  String get type => 'tool-call';

  @override
  Map<String, Object?> toJson() => <String, Object?>{
        'type': 'tool-call',
        'toolCallId': toolCallId,
        'toolName': toolName,
        'args': args,
        if (result != null) 'result': result,
        if (isError) 'isError': true,
      };
}

/// App-level payload routed by [name]. The growth path for anything that is
/// neither a model modality nor a channel the model emits.
class DataPart extends MessagePart {
  const DataPart({required this.name, this.data});

  final String name;
  final Object? data;

  @override
  String get type => 'data';

  @override
  Map<String, Object?> toJson() =>
      <String, Object?>{'type': 'data', 'name': name, 'data': data};
}
