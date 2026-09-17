import 'attachments.dart';
import 'message_part.dart';

/// Who produced a message.
enum MessageRole {
  user('user'),
  assistant('assistant'),
  system('system');

  const MessageRole(this.wireName);

  final String wireName;

  static MessageRole fromWire(String value) => MessageRole.values.firstWhere(
        (MessageRole r) => r.wireName == value,
        orElse: () => throw FormatException('Unknown message role: $value'),
      );
}

/// Lifecycle state of a message.
sealed class MessageStatus {
  const MessageStatus();

  String get type;
}

/// The model is still producing this message.
class MessageStatusRunning extends MessageStatus {
  const MessageStatusRunning();

  @override
  String get type => 'running';
}

/// The model finished; the content is final.
class MessageStatusComplete extends MessageStatus {
  const MessageStatusComplete();

  @override
  String get type => 'complete';
}

/// The run stopped early. Partial content is preserved.
class MessageStatusIncomplete extends MessageStatus {
  const MessageStatusIncomplete({required this.reason, this.error});

  final IncompleteReason reason;
  final String? error;

  @override
  String get type => 'incomplete';

  @override
  String toString() => 'incomplete(${reason.name}${error == null ? '' : ': $error'})';
}

enum IncompleteReason { cancelled, error, length, contentFilter, other }

/// The run paused because a human-in-the-loop tool needs a result.
class MessageStatusRequiresAction extends MessageStatus {
  const MessageStatusRequiresAction({this.reason = RequiresActionReason.toolCalls});

  final RequiresActionReason reason;

  @override
  String get type => 'requires-action';
}

enum RequiresActionReason { toolCalls }

/// One alternative content for a message. Regenerating or editing adds a
/// branch instead of destroying the previous answer.
class MessageBranch {
  const MessageBranch(this.content);

  final List<MessagePart> content;
}

/// Timing reported by the adapter for a run.
class MessageTiming {
  const MessageTiming({
    this.streamStartTime,
    this.firstTokenTime,
    this.totalStreamTime,
    this.tokenCount,
    this.tokensPerSecond,
    this.totalChunks,
  });

  /// Wall-clock time of the first chunk, in milliseconds since epoch.
  final int? streamStartTime;

  /// Milliseconds between run start and the first token.
  final int? firstTokenTime;

  /// Milliseconds the stream was open.
  final int? totalStreamTime;

  final int? tokenCount;
  final double? tokensPerSecond;
  final int? totalChunks;
}

/// Everything an adapter can attach to a message besides its content.
class MessageMetadata {
  const MessageMetadata({this.custom = const <String, Object?>{}, this.timing});

  final Map<String, Object?> custom;
  final MessageTiming? timing;

  MessageMetadata merge(MessageMetadata? other) {
    if (other == null) return this;
    return MessageMetadata(
      custom: <String, Object?>{...custom, ...other.custom},
      timing: other.timing ?? timing,
    );
  }
}

/// A message in the thread, with its branches and status.
///
/// Immutable: the runtime replaces messages instead of mutating them, so
/// widgets can compare snapshots by identity.
class ThreadMessage {
  const ThreadMessage({
    required this.id,
    required this.role,
    required this.branches,
    required this.createdAt,
    this.branchIndex = 0,
    this.status = const MessageStatusComplete(),
    this.metadata = const MessageMetadata(),
    this.attachments = const <AuiAttachment>[],
    this.isEditing = false,
  });

  /// Convenience constructor for a single-branch message.
  ThreadMessage.single({
    required this.id,
    required this.role,
    required List<MessagePart> content,
    required this.createdAt,
    this.status = const MessageStatusComplete(),
    this.metadata = const MessageMetadata(),
    this.attachments = const <AuiAttachment>[],
    this.isEditing = false,
  })  : branches = <MessageBranch>[MessageBranch(content)],
        branchIndex = 0;

  final String id;
  final MessageRole role;
  final List<MessageBranch> branches;
  final int branchIndex;
  final MessageStatus status;
  final DateTime createdAt;
  final MessageMetadata metadata;
  final List<AuiAttachment> attachments;

  /// True while the message is being edited in a composer.
  final bool isEditing;

  List<MessagePart> get content => branches[branchIndex].content;

  int get branchCount => branches.length;

  bool get isRunning => status is MessageStatusRunning;

  bool get isAssistant => role == MessageRole.assistant;
  bool get isUser => role == MessageRole.user;

  /// Concatenated text of the current branch, used for copy and export.
  String get text => content
      .whereType<TextPart>()
      .map((TextPart p) => p.text)
      .join('\n');

  /// Reason why this message cannot produce more tokens.
  bool get isRequiresAction => status is MessageStatusRequiresAction;

  /// Status of the part at [index].
  ///
  /// Text and reasoning parts only report `running` while they are the last
  /// part of a running message; tool calls take their status from the result.
  PartStatus partStatus(int index) {
    final MessagePart part = content[index];
    if (part is ToolCallPart) return part.status;
    final bool isLast = index == content.length - 1;
    if (!isLast) return PartStatus.complete;
    return switch (status) {
      MessageStatusRunning() => PartStatus.running,
      MessageStatusIncomplete() => PartStatus.incomplete,
      _ => PartStatus.complete,
    };
  }

  ThreadMessage copyWith({
    List<MessageBranch>? branches,
    int? branchIndex,
    MessageStatus? status,
    MessageMetadata? metadata,
    List<AuiAttachment>? attachments,
    bool? isEditing,
  }) {
    return ThreadMessage(
      id: id,
      role: role,
      branches: branches ?? this.branches,
      branchIndex: branchIndex ?? this.branchIndex,
      status: status ?? this.status,
      createdAt: createdAt,
      metadata: metadata ?? this.metadata,
      attachments: attachments ?? this.attachments,
      isEditing: isEditing ?? this.isEditing,
    );
  }

  /// Replaces the content of the current branch.
  ThreadMessage withContent(List<MessagePart> content) => copyWith(
        branches: <MessageBranch>[
          for (int i = 0; i < branches.length; i++)
            if (i == branchIndex) MessageBranch(content) else branches[i],
        ],
      );

  /// Appends a new branch and selects it.
  ThreadMessage withNewBranch(List<MessagePart> content) => copyWith(
        branches: <MessageBranch>[...branches, MessageBranch(content)],
        branchIndex: branches.length,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'role': role.wireName,
        'content': MessagePart.listToJson(content),
        'createdAt': createdAt.toIso8601String(),
        'status': status.type,
        'branchIndex': branchIndex,
        'branchCount': branchCount,
      };

  /// Parses the `{role, content}` shape used by assistant-ui adapters and the
  /// data stream protocol.
  static ThreadMessage fromJson(
    Map<String, Object?> json, {
    String? id,
    DateTime? createdAt,
  }) {
    final MessageRole role = MessageRole.fromWire(json['role']! as String);
    final List<MessagePart> content =
        MessagePart.listFromJson(json['content']! as List<Object?>);
    return ThreadMessage.single(
      id: id ?? 'msg_${DateTime.now().microsecondsSinceEpoch}',
      role: role,
      content: content,
      createdAt: createdAt ?? DateTime.now(),
      status: const MessageStatusComplete(),
    );
  }

  @override
  String toString() =>
      'ThreadMessage(${role.name}, ${content.length} parts, ${status.type})';
}
