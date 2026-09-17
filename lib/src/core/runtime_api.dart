import 'package:flutter/foundation.dart';

import 'adapters.dart';
import 'attachments.dart';
import 'message.dart';
import 'message_part.dart';

/// What the runtime can currently do. Widgets use these flags to disable
/// actions instead of guessing from message state.
class ThreadCapabilities {
  const ThreadCapabilities({
    this.cancel = true,
    this.edit = true,
    this.reload = true,
    this.branching = true,
    this.attachments = false,
    this.toolCalls = true,
    this.speech = false,
    this.dictation = false,
    this.feedback = false,
    this.voiceMode = false,
  });

  final bool cancel;
  final bool edit;
  final bool reload;
  final bool branching;
  final bool attachments;
  final bool toolCalls;

  /// True when a [SpeechSynthesisAdapter] is configured.
  final bool speech;

  /// True when a [DictationAdapter] is configured.
  final bool dictation;

  /// True when a [FeedbackAdapter] is configured.
  final bool feedback;

  /// True when the host ships a realtime voice mode.
  final bool voiceMode;

  ThreadCapabilities copyWith({
    bool? cancel,
    bool? edit,
    bool? reload,
    bool? branching,
    bool? attachments,
    bool? toolCalls,
    bool? speech,
    bool? dictation,
    bool? feedback,
    bool? voiceMode,
  }) {
    return ThreadCapabilities(
      cancel: cancel ?? this.cancel,
      edit: edit ?? this.edit,
      reload: reload ?? this.reload,
      branching: branching ?? this.branching,
      attachments: attachments ?? this.attachments,
      toolCalls: toolCalls ?? this.toolCalls,
      speech: speech ?? this.speech,
      dictation: dictation ?? this.dictation,
      feedback: feedback ?? this.feedback,
      voiceMode: voiceMode ?? this.voiceMode,
    );
  }
}

/// Thread snapshot handed to widgets.
/// A prompt the host offers after a run settles — the `follow-up-suggestions`
/// element's data.
@immutable
class ThreadSuggestion {
  const ThreadSuggestion({required this.prompt, this.title, this.label});

  /// Text sent when the suggestion is taken.
  final String prompt;

  /// Chip text; falls back to [prompt].
  final String? title;

  /// Small note beside the title, e.g. a shortcut.
  final String? label;

  String get display => title ?? prompt;
}

class ThreadState {
  const ThreadState({
    required this.messages,
    required this.isRunning,
    this.capabilities = const ThreadCapabilities(),
    this.speakingMessageId,
    this.contextUsage = ContextUsage.empty,
    this.suggestions = const <ThreadSuggestion>[],
    this.model,
    this.effort,
  });

  final List<ThreadMessage> messages;
  final bool isRunning;
  final ThreadCapabilities capabilities;

  /// Message currently being read aloud, if any.
  final String? speakingMessageId;

  /// Context-window usage for the thread, when the host reports one.
  final ContextUsage contextUsage;

  /// The model the next run will use, when one is picked.
  final String? model;

  /// Its reasoning effort, when the model takes one.
  final String? effort;

  /// Follow-up prompts the host put on offer; the thread clears them when a
  /// run starts again.
  final List<ThreadSuggestion> suggestions;

  bool get isEmpty => messages.isEmpty;
  bool get isNotEmpty => messages.isNotEmpty;

  ThreadMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  /// The last user message, which is what a run hangs off.
  ThreadMessage? get lastUserMessage {
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].isUser) return messages[i];
    }
    return null;
  }

  ThreadMessage? messageById(String id) {
    for (final ThreadMessage message in messages) {
      if (message.id == id) return message;
    }
    return null;
  }
}

/// A turn typed while a run was in flight, waiting its turn.
class QueuedMessage {
  const QueuedMessage({
    required this.id,
    required this.content,
    this.attachments = const <AuiAttachment>[],
  });

  final String id;
  final List<MessagePart> content;
  final List<AuiAttachment> attachments;

  String get text => content.whereType<TextPart>().map((TextPart p) => p.text).join();
}

/// How full the model's context window is — powers the composer's token ring.
class ContextUsage {
  const ContextUsage({required this.usedTokens, required this.maxTokens});

  final int usedTokens;
  final int maxTokens;

  /// 0..1, clamped.
  double get ratio =>
      maxTokens <= 0 ? 0 : (usedTokens / maxTokens).clamp(0.0, 1.0);

  /// Warning band the ring switches to, matching the upstream warning state.
  bool get isNearLimit => ratio >= 0.8;
  bool get isOverLimit => ratio >= 1.0;

  static const ContextUsage empty = ContextUsage(usedTokens: 0, maxTokens: 0);
}

/// Composer snapshot handed to widgets.
class ComposerState {
  const ComposerState({
    this.text = '',
    this.attachments = const <AuiAttachment>[],
    this.attachmentDrafts = const <String, AuiAttachment>{},
    this.isEditing = false,
    this.editingMessageId,
    this.dictation,
    this.queue = const <QueuedMessage>[],
  });

  final String text;
  final List<AuiAttachment> attachments;

  /// Uploads still in flight, keyed by file name.
  final Map<String, AuiAttachment> attachmentDrafts;

  final bool isEditing;
  final String? editingMessageId;

  /// Non-null while a dictation session is live, mirroring
  /// `s.composer.dictation` upstream.
  final DictationState? dictation;

  /// Turns waiting for the current run to finish.
  final List<QueuedMessage> queue;

  bool get canSend => text.trim().isNotEmpty || attachments.isNotEmpty;
  bool get isEmpty => text.isEmpty && attachments.isEmpty;

  ComposerState copyWith({
    String? text,
    List<AuiAttachment>? attachments,
    Map<String, AuiAttachment>? attachmentDrafts,
    bool? isEditing,
    String? editingMessageId,
    bool clearEditingMessageId = false,
    DictationState? dictation,
    bool clearDictation = false,
    List<QueuedMessage>? queue,
  }) {
    return ComposerState(
      text: text ?? this.text,
      attachments: attachments ?? this.attachments,
      attachmentDrafts: attachmentDrafts ?? this.attachmentDrafts,
      isEditing: isEditing ?? this.isEditing,
      editingMessageId:
          clearEditingMessageId ? null : (editingMessageId ?? this.editingMessageId),
      dictation: clearDictation ? null : (dictation ?? this.dictation),
      queue: queue ?? this.queue,
    );
  }
}

/// Live dictation session state.
class DictationState {
  const DictationState({this.transcript = '', this.listening = true});

  /// Transcript so far, updated as the session streams.
  final String transcript;
  final bool listening;
}

/// Message snapshot, available inside a message scope.
class MessageState {
  const MessageState({
    required this.message,
    required this.isLast,
    this.isSpeaking = false,
  });

  final ThreadMessage message;
  final bool isLast;

  /// True while this message is being read aloud.
  final bool isSpeaking;

  int get branchCount => message.branchCount;
  int get branchIndex => message.branchIndex;
  bool get isEditing => message.isEditing;
  MessageRole get role => message.role;
}

/// One conversation in the thread list.
class ThreadListItem {
  const ThreadListItem({
    required this.id,
    this.title = '',
    this.status = ThreadListItemStatus.regular,
    this.remoteId,
    this.createdAt,
  });

  final String id;

  /// Generated or renamed label; empty until the thread earns one.
  final String title;

  final ThreadListItemStatus status;

  /// Server-side id, when the host persists threads.
  final String? remoteId;

  final DateTime? createdAt;

  bool get isArchived => status == ThreadListItemStatus.archived;
  bool get hasTitle => title.trim().isNotEmpty;

  ThreadListItem copyWith({
    String? title,
    ThreadListItemStatus? status,
    String? remoteId,
    DateTime? createdAt,
  }) {
    return ThreadListItem(
      id: id,
      title: title ?? this.title,
      status: status ?? this.status,
      remoteId: remoteId ?? this.remoteId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

enum ThreadListItemStatus { regular, archived }

/// Snapshot of every conversation the runtime knows about.
///
/// Mirrors `s.threads` upstream: `threadIds` is the active list, archived ids
/// live beside it, and `mainThreadId` is the one on screen.
class ThreadsState {
  const ThreadsState({
    this.threadIds = const <String>[],
    this.archivedThreadIds = const <String>[],
    this.mainThreadId = '',
    this.items = const <String, ThreadListItem>{},
    this.isLoading = false,
    this.hasMore = false,
  });

  /// Active conversations, newest first.
  final List<String> threadIds;

  final List<String> archivedThreadIds;
  final String mainThreadId;
  final Map<String, ThreadListItem> items;
  final bool isLoading;

  /// True when a paged backend still has older threads to fetch.
  final bool hasMore;

  bool get isEmpty => threadIds.isEmpty && archivedThreadIds.isEmpty;
  bool get isNotEmpty => !isEmpty;
  bool get hasArchived => archivedThreadIds.isNotEmpty;

  ThreadListItem? itemById(String id) => items[id];
}

/// Operations the thread list exposes to widgets.
abstract class ThreadsRuntimeApi {
  ThreadsState get state;

  /// Moves the given conversation onto the screen.
  Future<void> switchToThread(String threadId);

  /// Creates a conversation and returns its id. It becomes the main thread.
  Future<String> create({String? title});

  Future<void> archive(String threadId);
  Future<void> unarchive(String threadId);

  /// Deletes a conversation; if it was on screen, an empty one takes its place.
  Future<void> delete(String threadId);

  Future<void> rename(String threadId, String title);

  /// Fetches the next page when the host persists threads remotely.
  Future<void> loadMore();
}

/// The state object selectors receive. `message` is only non-null inside a
/// message scope, mirroring `s.message` in assistant-ui's `AuiIf`.
class AuiState {
  const AuiState({
    required this.thread,
    required this.composer,
    this.threads = const ThreadsState(),
    this.message,
  });

  final ThreadState thread;
  final ComposerState composer;

  /// Every conversation the runtime knows about.
  final ThreadsState threads;

  final MessageState? message;

  AuiState withMessage(MessageState? message) => AuiState(
        thread: thread,
        composer: composer,
        threads: threads,
        message: message,
      );
}

/// Operations a thread exposes to widgets.
abstract class ThreadRuntimeApi {
  ThreadState get state;

  /// Puts follow-up prompts on offer; pass an empty list to clear them.
  void setSuggestions(List<ThreadSuggestion> suggestions);

  /// Completes when the thread is idle again: the run finished and any tool
  /// continuations it triggered are done. Already complete when nothing runs.
  ///
  /// The mutation methods below return as soon as the run has *started*, so
  /// this is how a caller waits for the answer.
  Future<void> get settled;

  /// Appends a finished message (for example from history) without running.
  Future<void> append(ThreadMessage message);

  /// Appends a user message and starts a run that answers it.
  Future<void> send({
    List<MessagePart>? content,
    List<AuiAttachment> attachments = const <AuiAttachment>[],
  });

  /// Starts a run on the last user message. [parentId] optionally regenerates a
  /// specific assistant message instead of appending a new one.
  Future<void> startRun({String? parentId});

  /// Aborts the running generation; partial content stays as `incomplete`.
  void cancelRun();

  /// Regenerates an assistant message as a new branch.
  Future<void> reload({String? messageId});

  /// Loads a message into the composer for editing.
  void beginEdit(String messageId);

  /// Leaves edit mode without changing the message.
  void cancelEdit();

  /// Replaces the edited message's content and re-runs the conversation from
  /// that point as a new branch.
  Future<void> commitEdit({List<MessagePart>? content});

  /// Flips between alternative answers of a message.
  void switchToBranch(String messageId, int branchIndex);

  /// Supplies the result of a human-in-the-loop tool call and continues.
  Future<void> addToolResult({
    required String toolCallId,
    Object? result,
    bool isError = false,
  });

  /// Reads a message aloud through the speech adapter.
  Future<void> speak(String messageId);

  /// Stops playback started by [speak].
  Future<void> stopSpeaking();

  /// Rates a message through the feedback adapter.
  Future<void> submitFeedback({
    required String messageId,
    required FeedbackType type,
    String? comment,
  });

  /// Starts a dictation session; transcripts land in the composer text.
  Future<void> startDictation();

  /// Ends the dictation session, keeping the transcript.
  Future<void> stopDictation();
}

/// Operations the composer exposes to widgets.
abstract class ComposerRuntimeApi {
  ComposerState get state;

  void setText(String text);

  /// Adds an attachment that is already uploaded.
  void addAttachment(AuiAttachment attachment);

  /// Uploads a picked file through the runtime's attachment adapter and adds
  /// the result. Without an adapter the file is inlined (data URI / base64).
  Future<void> addPendingAttachment(PendingAttachment file);

  void removeAttachment(String id);

  /// Submits: sends a new message, or commits an edit. While a run is in
  /// flight the message joins the queue instead of being dropped.
  Future<void> send();

  /// Drops a queued turn before it is sent.
  void removeQueued(String id);

  /// Clears the whole queue.
  void clearQueued();

  /// Leaves edit mode (cancel button), or clears the composer when composing.
  void cancel();
}

/// The contract every runtime implements. `LocalRuntime` is the built-in one;
/// `ExternalStoreRuntime` adapts an app-owned store.
abstract class AssistantRuntime extends ChangeNotifier {
  /// Current snapshot. Cheap to read; never mutated in place.
  AuiState get state;

  /// The model the next run should use, when the host picked one. Runtimes
  /// whose backend chooses report null.
  String? get model => null;

  /// The model's reasoning effort (`low` / `medium` / `high`), when it takes
  /// one.
  String? get effort => null;

  /// Picks the model. Runtimes that do not support a pick ignore it.
  void setModel(String? id) {}

  /// Picks the reasoning effort. Ignored where the model takes none.
  void setEffort(String? id) {}

  ThreadRuntimeApi get thread;
  ComposerRuntimeApi get composer;

  /// Conversation management: the thread list.
  ThreadsRuntimeApi get threads;
}
