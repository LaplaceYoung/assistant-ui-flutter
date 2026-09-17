import 'dart:async';
import 'dart:convert';

import '../core/abort.dart';
import '../core/adapters.dart';
import '../core/attachments.dart';
import '../core/message.dart';
import '../core/message_part.dart';
import '../core/runtime_api.dart';

/// Tuning knobs for [LocalRuntime].
class LocalRuntimeOptions {
  const LocalRuntimeOptions({
    this.tools = const <String, ToolDefinition>{},
    this.maxSteps = 1,
    this.systemPrompt,
    this.attachmentAdapter,
    this.capabilities = const ThreadCapabilities(),
    this.speech,
    this.dictation,
    this.feedback,
    this.contextWindowTokens = 128000,
    this.tokenCounter,
    this.runOnStart = false,
  });

  /// Tools the runtime executes itself, and whose schemas it hands to the
  /// adapter through `context.tools`.
  final Toolkit tools;

  /// How many tool-call round trips one user turn may trigger. `1` lets the
  /// model call tools once; the results are fed back in one continuation run.
  final int maxSteps;

  final String? systemPrompt;
  final AttachmentAdapter? attachmentAdapter;
  final ThreadCapabilities capabilities;

  /// Text-to-speech backend; enables the speak action when set.
  final SpeechSynthesisAdapter? speech;

  /// Speech-to-text backend; enables dictation when set.
  final DictationAdapter? dictation;

  /// Rating backend; enables the feedback buttons when set.
  final FeedbackAdapter? feedback;

  /// Model context window, used by the composer's token ring. Zero hides it.
  final int contextWindowTokens;

  /// Exact token count for a message list; defaults to a character heuristic.
  final int Function(List<ThreadMessage> messages)? tokenCounter;

  /// Starts a run on construction, for a thread seeded with an unanswered
  /// user message.
  final bool runOnStart;
}

/// The default runtime: owns the thread, the composer, and the run lifecycle,
/// and delegates model calls to a [ChatModelAdapter].
///
/// Covers the same ground as `useLocalRuntime`: streaming, cancellation,
/// regeneration, editing, branching, and tool execution.
class LocalRuntime extends AssistantRuntime {
  LocalRuntime({
    required ChatModelAdapter adapter,
    List<ThreadMessage> initialMessages = const <ThreadMessage>[],
    this.options = const LocalRuntimeOptions(),
  }) : _adapter = adapter {
    final String initialId = _nextThreadId();
    _records[initialId] = _ThreadRecord(
      item: ThreadListItem(id: initialId, createdAt: DateTime.now()),
      messages: List<ThreadMessage>.of(initialMessages),
    );
    _threadOrder.add(initialId);
    _mainThreadId = initialId;
    _messages = _records[initialId]!.messages;
    // Publish the seeded thread, otherwise widgets would render an empty
    // thread until the first mutation.
    _emit();
    if (options.runOnStart && _messages.isNotEmpty) {
      unawaited(_startRun());
    }
  }

  final ChatModelAdapter _adapter;
  final LocalRuntimeOptions options;

  /// Conversation storage: every thread's messages live in its own record, and
  /// [_messages] points at the one on screen.
  final Map<String, _ThreadRecord> _records = <String, _ThreadRecord>{};

  /// Active (non-archived) thread ids, newest first.
  final List<String> _threadOrder = <String>[];

  final List<String> _archivedOrder = <String>[];

  String _mainThreadId = '';

  /// Local runtimes never page, so this stays false; a persisting host
  /// overrides the handoff by supplying its own [ThreadsRuntimeApi].
  static const bool _loadingThreads = false;

  late List<ThreadMessage> _messages;
  ThreadsState _threadsState = const ThreadsState();

  ComposerState _composer = const ComposerState();
  ThreadState _threadState =
      const ThreadState(messages: <ThreadMessage>[], isRunning: false);

  int _idCounter = 0;
  int _stepCount = 0;

  _ActiveRun? _activeRun;

  /// Future of the current run chain; `settled` hands it to callers.
  Future<void> _chain = Future<void>.value();

  /// Parts of the steps already finished in the message being generated.
  List<MessagePart> _baseParts = const <MessagePart>[];

  /// Parts produced by the in-flight step. Message content is
  /// `_baseParts + _stepParts`, so a tool round trip reads as
  /// `text → tool call → answer` inside one assistant message.
  List<MessagePart> _stepParts = const <MessagePart>[];

  @override
  late final ThreadRuntimeApi thread = _LocalThreadApi(this);

  @override
  late final ComposerRuntimeApi composer = _LocalComposerApi(this);

  @override
  late final ThreadsRuntimeApi threads = _LocalThreadsApi(this);

  @override
  AuiState get state => AuiState(
        thread: _threadState,
        composer: _composer,
        threads: _threadsState,
      );

  ThreadState get threadState => _threadState;
  ComposerState get composerState => _composer;
  ThreadsState get threadsState => _threadsState;

  String _nextThreadId() => 'thread_${_threadIdCounter++}';

  int _threadIdCounter = 0;

  /// Live message list (unmodifiable snapshot).
  List<ThreadMessage> get messages =>
      List<ThreadMessage>.unmodifiable(_messages);

  bool get isRunning => _activeRun != null;

  /// Completes when the thread goes idle again, tool continuations included.
  Future<void> get settled => _chain;

  Toolkit get tools => options.tools;

  ModelContext get modelContext => ModelContext(
        systemPrompt: options.systemPrompt,
        tools: <Map<String, Object?>>[
          for (final MapEntry<String, ToolDefinition> entry
              in options.tools.entries)
            entry.value.toJsonSchema(entry.key),
        ],
      );

  String? _speakingMessageId;

  /// Unsent composer text per thread, restored when the thread comes back.
  final Map<String, String> _drafts = <String, String>{};

  int _queuedCounter = 0;

  StreamSubscription<String>? _dictationSubscription;
  Future<void> Function()? _dictationStop;

  /// Capabilities merged from the declared ones and the configured adapters.
  late final ThreadCapabilities _capabilities = options.capabilities.copyWith(
    speech: options.capabilities.speech || options.speech != null,
    dictation: options.capabilities.dictation || options.dictation != null,
    feedback: options.capabilities.feedback || options.feedback != null,
    attachments:
        options.capabilities.attachments || options.attachmentAdapter != null,
  );

  List<ThreadSuggestion> _suggestions = <ThreadSuggestion>[];

  /// Replaces the follow-up prompts the thread offers.
  void updateSuggestions(List<ThreadSuggestion> suggestions) {
    _suggestions = List<ThreadSuggestion>.of(suggestions);
    _emit();
    notifyListeners();
  }

  void _emit() {
    _threadState = ThreadState(
      messages: List<ThreadMessage>.unmodifiable(_messages),
      isRunning: _activeRun != null,
      capabilities: _capabilities,
      speakingMessageId: _speakingMessageId,
      contextUsage: _contextUsage(),
      suggestions: List<ThreadSuggestion>.unmodifiable(_suggestions),
    );
    _threadsState = ThreadsState(
      threadIds: List<String>.unmodifiable(_threadOrder),
      archivedThreadIds: List<String>.unmodifiable(_archivedOrder),
      mainThreadId: _mainThreadId,
      items: Map<String, ThreadListItem>.unmodifiable(<String, ThreadListItem>{
        for (final MapEntry<String, _ThreadRecord> entry in _records.entries)
          entry.key: entry.value.item,
      }),
      isLoading: _loadingThreads,
    );
    notifyListeners();
  }

  String _nextId() => 'msg_${_idCounter++}';

  ThreadMessage? _messageById(String id) {
    for (final ThreadMessage message in _messages) {
      if (message.id == id) return message;
    }
    return null;
  }

  int _indexOf(String id) {
    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].id == id) return i;
    }
    return -1;
  }

  void _replaceAt(int index, ThreadMessage message) {
    _messages[index] = message;
    _emit();
  }

  // ------------------------------------------------------------ threading

  Future<void> _append(ThreadMessage message) async {
    _messages.add(message);
    _emit();
  }

  Future<void> _sendMessage({
    required List<MessagePart> parts,
    List<AuiAttachment> attachments = const <AuiAttachment>[],
  }) async {
    if (parts.isEmpty || _activeRun != null) return;
    final ThreadMessage userMessage = ThreadMessage.single(
      id: _nextId(),
      role: MessageRole.user,
      content: parts,
      createdAt: DateTime.now(),
      attachments: attachments,
    );
    _messages.add(userMessage);
    _maybeTitleActiveThread(userMessage.text);
    _composer = _composer.copyWith(
      text: '',
      attachments: const <AuiAttachment>[],
      isEditing: false,
      clearEditingMessageId: true,
      clearDictation: true,
    );
    _emit();
    await _startRunInternal(parentId: userMessage.id);
  }

  /// Starts a run answering everything up to and including [parentId].
  ///
  /// With [continueMessageId] the run continues an existing assistant message
  /// (after tool calls, or after a human supplied a tool result) instead of
  /// appending a new one.
  Future<void> _startRunInternal({
    required String parentId,
    String? continueMessageId,
  }) async {
    final int parentIndex = _indexOf(parentId);
    if (parentIndex < 0 || _activeRun != null) return;

    final bool isContinuation = continueMessageId != null;
    if (!isContinuation) _stepCount = 0;

    final AbortController controller = AbortController();
    final int startedAt = DateTime.now().millisecondsSinceEpoch;

    late final ThreadMessage assistantMessage;
    late final int assistantIndex;

    if (isContinuation) {
      assistantIndex = _indexOf(continueMessageId);
      if (assistantIndex < 0) return;
      assistantMessage = _messages[assistantIndex];
      _baseParts = List<MessagePart>.of(assistantMessage.content);
    } else {
      assistantMessage = ThreadMessage.single(
        id: _nextId(),
        role: MessageRole.assistant,
        content: const <MessagePart>[],
        createdAt: DateTime.now(),
        status: const MessageStatusRunning(),
      );
      _messages.add(assistantMessage);
      assistantIndex = _messages.length - 1;
      _baseParts = const <MessagePart>[];
    }

    _stepParts = const <MessagePart>[];
    _activeRun = _ActiveRun(
      messageId: assistantMessage.id,
      controller: controller,
    );
    _replaceAt(
      assistantIndex,
      assistantMessage.copyWith(
        status: const MessageStatusRunning(),
        metadata: MessageMetadata(
          custom: assistantMessage.metadata.custom,
          timing: MessageTiming(streamStartTime: startedAt),
        ),
      ),
    );

    final List<ThreadMessage> contextMessages = <ThreadMessage>[
      for (int i = 0; i <= parentIndex; i++) _messages[i],
      // A continuation lets the adapter read the tool results it is answering.
      if (isContinuation && assistantMessage.content.isNotEmpty)
        _messages[assistantIndex],
    ];

    int? firstTokenAt;
    int chunks = 0;
    ChatModelRunResult? last;
    final Completer<void> done = Completer<void>();

    void applyContent() {
      final List<MessagePart> merged = <MessagePart>[
        ..._baseParts,
        ..._stepParts,
      ];
      final ThreadMessage current = _messages[assistantIndex];
      _messages[assistantIndex] = current.copyWith(
        branches: <MessageBranch>[
          for (int i = 0; i < current.branches.length; i++)
            if (i == current.branchIndex)
              MessageBranch(merged)
            else
              current.branches[i],
        ],
      );
    }

    void finish(MessageStatus status) {
      if (done.isCompleted) return;
      final int endedAt = DateTime.now().millisecondsSinceEpoch;
      final int? firstToken = firstTokenAt;
      applyContent();
      final ThreadMessage current = _messages[assistantIndex];
      _messages[assistantIndex] = current.copyWith(
        status: status,
        metadata: MessageMetadata(
          custom: current.metadata.custom,
          timing: MessageTiming(
            streamStartTime: startedAt,
            firstTokenTime: firstToken == null ? null : firstToken - startedAt,
            totalStreamTime: endedAt - startedAt,
            totalChunks: chunks,
          ),
        ),
      );
      _activeRun = null;
      _baseParts = const <MessagePart>[];
      _stepParts = const <MessagePart>[];
      _emit();
      done.complete();
    }

    StreamSubscription<ChatModelRunResult>? subscription;

    void abortSubscription() {
      final StreamSubscription<ChatModelRunResult>? current = subscription;
      if (current != null) unawaited(current.cancel());
    }

    controller.signal.addListener(() {
      if (done.isCompleted) return;
      abortSubscription();
      finish(const MessageStatusIncomplete(reason: IncompleteReason.cancelled));
    });

    final Stream<ChatModelRunResult> stream;
    try {
      stream = _adapter.run(
        ChatModelRunContext(
          messages: contextMessages,
          abortSignal: controller.signal,
          context: modelContext,
          getMessage: () => _messages[assistantIndex],
        ),
      );
    } catch (error) {
      finish(
        MessageStatusIncomplete(reason: IncompleteReason.error, error: '$error'),
      );
      _chain = Future<void>.value();
      return;
    }

    subscription = stream.listen(
      (ChatModelRunResult event) {
        if (done.isCompleted) return;
        firstTokenAt ??= DateTime.now().millisecondsSinceEpoch;
        chunks++;
        last = event;
        _stepParts = event.content;
        if (event.metadata != null) {
          _messages[assistantIndex] = _messages[assistantIndex]
              .copyWith(
                metadata:
                    _messages[assistantIndex].metadata.merge(event.metadata),
              );
        }
        applyContent();
        _emit();
        final MessageStatus? status = event.status;
        if (status != null && status is! MessageStatusRunning) {
          // An explicit status ends the run; `requires-action` pauses it until
          // the app supplies a tool result.
          abortSubscription();
          finish(status);
        }
      },
      onError: (Object error, StackTrace _) {
        finish(
          MessageStatusIncomplete(
            reason: IncompleteReason.error,
            error: '$error',
          ),
        );
      },
      onDone: () => finish(last?.status ?? const MessageStatusComplete()),
      cancelOnError: true,
    );

    // The caller returns as soon as the run is under way. `settled` waits for
    // the whole chain, tool continuations included.
    _chain = _completeRun(
      messageId: assistantMessage.id,
      signal: controller.signal,
      runDone: done.future,
    );
  }

  /// Completes when the run and everything it triggers have finished.
  Future<void> _completeRun({
    required String messageId,
    required AbortSignal signal,
    required Future<void> runDone,
  }) async {
    await runDone;
    if (signal.isAborted) return;
    final ThreadMessage? message = _messageById(messageId);
    if (message == null) return;
    if (message.status is MessageStatusRequiresAction) return;
    await _runToolsIfNeeded(messageId);
    // Anything the user typed mid-run goes next.
    await _drainQueue();
  }

  /// Runs the tool calls the model asked for, then continues the run while
  /// [LocalRuntimeOptions.maxSteps] leaves budget.
  Future<void> _runToolsIfNeeded(String assistantMessageId) async {
    while (true) {
      final int index = _indexOf(assistantMessageId);
      if (index < 0) return;

      final ThreadMessage message = _messages[index];
      final List<ToolCallPart> executable = message.content
          .whereType<ToolCallPart>()
          .where((ToolCallPart part) {
        final ToolDefinition? definition = options.tools[part.toolName];
        return !part.hasResult &&
            definition != null &&
            !definition.human &&
            definition.execute != null;
      }).toList(growable: false);

      if (executable.isEmpty) return;
      if (_stepCount >= options.maxSteps) return;
      _stepCount++;

      for (final ToolCallPart call in executable) {
        final ToolDefinition definition = options.tools[call.toolName]!;
        Object? result;
        bool isError = false;
        try {
          final Object? args = call.args;
          result = await definition.execute!(
            args is Map<String, Object?>
                ? args
                : args is Map
                    ? args.cast<String, Object?>()
                    : const <String, Object?>{},
          );
        } catch (error) {
          result = '$error';
          isError = true;
        }
        _replaceToolCall(index, call.toolCallId,
            result: result, isError: isError);
      }

      await _startRunInternal(
        parentId: _parentIdFor(index),
        continueMessageId: assistantMessageId,
      );
      // Wait for that continuation (and any it triggers) before looping.
      await _chain;
      // Loop: the continuation may have produced further tool calls.
    }
  }

  /// The user message a run against the assistant message at [assistantIndex]
  /// hangs off.
  String _parentIdFor(int assistantIndex) {
    for (int i = assistantIndex - 1; i >= 0; i--) {
      if (_messages[i].isUser) return _messages[i].id;
    }
    return _messages[assistantIndex].id;
  }

  void _replaceToolCall(
    int messageIndex,
    String toolCallId, {
    Object? result,
    bool isError = false,
  }) {
    final ThreadMessage message = _messages[messageIndex];
    _messages[messageIndex] = message.withContent(<MessagePart>[
      for (final MessagePart part in message.content)
        if (part is ToolCallPart && part.toolCallId == toolCallId)
          part.copyWith(result: result, isError: isError)
        else
          part,
    ]);
    _emit();
  }

  void _cancelRun() => _activeRun?.controller.abort('cancelled');

  Future<void> _startRun({String? parentId}) async {
    if (_activeRun != null) return;
    final String? parent =
        parentId ?? (_messages.isEmpty ? null : _messages.last.id);
    if (parent == null) return;
    await _startRunInternal(parentId: parent);
  }

  Future<void> _reload({String? messageId}) async {
    if (_activeRun != null) return;
    final int index = messageId != null
        ? _indexOf(messageId)
        : _messages.lastIndexWhere((ThreadMessage m) => m.isAssistant);
    if (index < 0) return;

    final ThreadMessage message = _messages[index];
    // Regeneration keeps the previous answer as a branch and fills a fresh one.
    _replaceAt(
      index,
      message.copyWith(
        branches: <MessageBranch>[
          ...message.branches,
          const MessageBranch(<MessagePart>[]),
        ],
        branchIndex: message.branches.length,
        status: const MessageStatusRunning(),
      ),
    );
    await _startRunInternal(
      parentId: _parentIdFor(index),
      continueMessageId: message.id,
    );
  }

  void _beginEdit(String messageId) {
    final ThreadMessage? message = _messageById(messageId);
    if (message == null) return;
    _composer = _composer.copyWith(
      text: message.text,
      isEditing: true,
      editingMessageId: messageId,
    );
    _replaceAt(_indexOf(messageId), message.copyWith(isEditing: true));
  }

  void _cancelEdit() {
    final String? id = _composer.editingMessageId;
    if (id != null) {
      final int index = _indexOf(id);
      if (index >= 0) {
        _replaceAt(index, _messages[index].copyWith(isEditing: false));
      }
    }
    _composer = _composer.copyWith(
      text: '',
      attachments: const <AuiAttachment>[],
      isEditing: false,
      clearEditingMessageId: true,
    );
    _emit();
  }

  Future<void> _commitEdit({List<MessagePart>? content}) async {
    final String? id = _composer.editingMessageId;
    if (id == null) return;
    final int index = _indexOf(id);
    if (index < 0) return;

    final List<MessagePart> parts = content ??
        <MessagePart>[
          if (_composer.text.trim().isNotEmpty) TextPart(_composer.text.trim()),
          for (final AuiAttachment attachment in _composer.attachments)
            attachment.asPart,
        ];

    final ThreadMessage message = _messages[index];
    // The edited content becomes a new branch, and everything the old branch
    // produced after it is dropped.
    _replaceAt(
      index,
      message.copyWith(
        branches: <MessageBranch>[
          ...message.branches,
          if (parts.isNotEmpty) MessageBranch(parts),
        ],
        branchIndex: parts.isEmpty ? message.branchIndex : message.branches.length,
        status: const MessageStatusComplete(),
        isEditing: false,
      ),
    );
    if (index + 1 < _messages.length) {
      _messages.removeRange(index + 1, _messages.length);
    }
    _composer = _composer.copyWith(
      text: '',
      attachments: const <AuiAttachment>[],
      isEditing: false,
      clearEditingMessageId: true,
    );
    _emit();

    if (parts.isNotEmpty) {
      await _startRunInternal(parentId: id);
    }
  }

  void _switchToBranch(String messageId, int branchIndex) {
    final int index = _indexOf(messageId);
    if (index < 0) return;
    final ThreadMessage message = _messages[index];
    final int clamped = branchIndex.clamp(0, message.branchCount - 1);
    if (clamped == message.branchIndex) return;
    _replaceAt(index, message.copyWith(branchIndex: clamped));
  }

  Future<void> _addToolResult({
    required String toolCallId,
    Object? result,
    bool isError = false,
  }) async {
    final int index = _messages.lastIndexWhere(
      (ThreadMessage m) =>
          m.isAssistant &&
          m.content.whereType<ToolCallPart>().any(
                (ToolCallPart p) => p.toolCallId == toolCallId,
              ),
    );
    if (index < 0) return;
    _replaceToolCall(index, toolCallId, result: result, isError: isError);

    final ThreadMessage message = _messages[index];
    final bool allResolved = message.content
        .whereType<ToolCallPart>()
        .every((ToolCallPart part) => part.hasResult);
    if (!allResolved || message.status is! MessageStatusRequiresAction) return;

    _replaceAt(index, message.copyWith(status: const MessageStatusComplete()));
    await _startRunInternal(
      parentId: _parentIdFor(index),
      continueMessageId: message.id,
    );
  }

  // -------------------------------------------------------- speech & input

  Future<void> _speak(String messageId) async {
    final SpeechSynthesisAdapter? adapter = options.speech;
    if (adapter == null) return;
    final ThreadMessage? message = _messageById(messageId);
    if (message == null || message.isRunning) return;
    final String text = message.text.trim();
    if (text.isEmpty) return;

    await _stopSpeaking();
    _speakingMessageId = messageId;
    _emit();
    try {
      await adapter.speak(text);
    } finally {
      if (_speakingMessageId == messageId) {
        _speakingMessageId = null;
        _emit();
      }
    }
  }

  Future<void> _stopSpeaking() async {
    final SpeechSynthesisAdapter? adapter = options.speech;
    if (adapter == null) return;
    await adapter.stop();
    if (_speakingMessageId != null) {
      _speakingMessageId = null;
      _emit();
    }
  }

  Future<void> _submitFeedback({
    required String messageId,
    required FeedbackType type,
    String? comment,
  }) async {
    final FeedbackAdapter? adapter = options.feedback;
    if (adapter == null) return;
    await adapter.submit(
      FeedbackRequest(messageId: messageId, type: type, comment: comment),
    );
  }

  Future<void> _startDictation() async {
    final DictationAdapter? adapter = options.dictation;
    if (adapter == null || _composer.dictation != null) return;

    final DictationSession session = await adapter.start();
    _dictationStop = session.stop;
    _composer = _composer.copyWith(dictation: const DictationState());
    _emit();

    _dictationSubscription = session.transcripts.listen(
      (String transcript) {
        _composer = _composer.copyWith(
          text: transcript,
          dictation: DictationState(transcript: transcript),
        );
        _emit();
      },
      onDone: _clearDictation,
      onError: (Object _, StackTrace __) => _clearDictation(),
    );
  }

  Future<void> _stopDictation() async {
    final Future<void> Function()? stop = _dictationStop;
    _dictationStop = null;
    // State first: the UI must not wait on stream teardown.
    _clearDictation();
    unawaited(_dictationSubscription?.cancel());
    _dictationSubscription = null;
    await stop?.call();
  }

  void _clearDictation() {
    if (_composer.dictation == null) return;
    _composer = _composer.copyWith(clearDictation: true);
    _emit();
  }

  // ---------------------------------------------------------- conversations

  /// Saves the on-screen list back into its record. Callers mutate
  /// [_messages] in place, so this is only needed before swapping threads.
  void _syncActiveThread() => _emit();

  Future<void> _switchToThread(String threadId) async {
    final _ThreadRecord? record = _records[threadId];
    if (record == null || threadId == _mainThreadId) return;
    // A run belongs to the thread it started in; leaving cancels it.
    if (_activeRun != null) _cancelRun();
    await _chain;
    _syncActiveThread();
    _saveDraft();
    _mainThreadId = threadId;
    _messages = record.messages;
    _composer = ComposerState(text: _drafts[threadId] ?? '');
    _emit();
  }

  Future<String> _createThread({String? title}) async {
    if (_activeRun != null) _cancelRun();
    await _chain;
    _saveDraft();
    final String id = _nextThreadId();
    _records[id] = _ThreadRecord(
      item: ThreadListItem(
        id: id,
        title: title ?? '',
        createdAt: DateTime.now(),
      ),
      messages: <ThreadMessage>[],
    );
    _threadOrder.insert(0, id);
    _mainThreadId = id;
    _messages = _records[id]!.messages;
    _composer = const ComposerState();
    _emit();
    return id;
  }

  Future<void> _archiveThread(String threadId) async {
    final _ThreadRecord? record = _records[threadId];
    if (record == null || record.item.isArchived) return;
    _records[threadId] = record..item =
        record.item.copyWith(status: ThreadListItemStatus.archived);
    _threadOrder.remove(threadId);
    _archivedOrder.insert(0, threadId);
    if (threadId == _mainThreadId) {
      // Archiving what is on screen moves to the next thread, or a fresh one.
      if (_threadOrder.isNotEmpty) {
        await _switchToThread(_threadOrder.first);
      } else {
        await _createThread();
      }
    } else {
      _emit();
    }
  }

  Future<void> _unarchiveThread(String threadId) async {
    final _ThreadRecord? record = _records[threadId];
    if (record == null || !record.item.isArchived) return;
    _records[threadId] = record..item =
        record.item.copyWith(status: ThreadListItemStatus.regular);
    _archivedOrder.remove(threadId);
    _threadOrder.insert(0, threadId);
    _emit();
  }

  Future<void> _deleteThread(String threadId) async {
    if (!_records.containsKey(threadId)) return;
    _records.remove(threadId);
    _threadOrder.remove(threadId);
    _archivedOrder.remove(threadId);
    if (threadId == _mainThreadId) {
      if (_threadOrder.isNotEmpty) {
        await _switchToThread(_threadOrder.first);
      } else {
        await _createThread();
      }
    } else {
      _emit();
    }
  }

  Future<void> _renameThread(String threadId, String title) async {
    final _ThreadRecord? record = _records[threadId];
    if (record == null) return;
    _records[threadId] = record..item = record.item.copyWith(title: title);
    _emit();
  }

  /// Local runtimes hold every thread in memory, so there is nothing to page.
  /// A host that persists threads supplies its own implementation.
  Future<void> _loadMoreThreads() async {}

  /// Titles a fresh conversation from its first user message — the local
  /// stand-in for upstream's title-generation adapter.
  void _maybeTitleActiveThread(String firstMessage) {
    final _ThreadRecord? record = _records[_mainThreadId];
    if (record == null || record.item.hasTitle) return;
    final String line = firstMessage.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (line.isEmpty) return;
    final String title = line.length > 60 ? '${line.substring(0, 57)}…' : line;
    _records[_mainThreadId] = record..item = record.item.copyWith(title: title);
  }

  /// Rough context-window usage for the current thread.
  ///
  /// The default counter is a character heuristic (about four characters per
  /// token) so the ring works with no backend; hosts that know the real
  /// numbers pass a [ContextTokenCounter].
  ContextUsage _contextUsage() {
    final int max = options.contextWindowTokens;
    if (max <= 0) return ContextUsage.empty;
    final int used = options.tokenCounter?.call(_messages) ??
        _messages.fold<int>(
          0,
          (int sum, ThreadMessage message) =>
              sum + (message.text.length / 4).ceil() + 4,
        );
    return ContextUsage(usedTokens: used, maxTokens: max);
  }

  void _enqueue(List<MessagePart> parts, List<AuiAttachment> attachments) {
    _composer = _composer.copyWith(
      text: '',
      attachments: const <AuiAttachment>[],
      queue: <QueuedMessage>[
        ..._composer.queue,
        QueuedMessage(
          id: 'queued_${_queuedCounter++}',
          content: parts,
          attachments: attachments,
        ),
      ],
    );
    _emit();
  }

  void _removeQueued(String id) {
    _composer = _composer.copyWith(
      queue: _composer.queue
          .where((QueuedMessage message) => message.id != id)
          .toList(growable: false),
    );
    _emit();
  }

  void _clearQueued() {
    if (_composer.queue.isEmpty) return;
    _composer = _composer.copyWith(queue: const <QueuedMessage>[]);
    _emit();
  }

  /// Sends the next queued turn once the thread is idle.
  Future<void> _drainQueue() async {
    if (_activeRun != null || _composer.queue.isEmpty) return;
    final QueuedMessage next = _composer.queue.first;
    _composer = _composer.copyWith(
      queue: _composer.queue.skip(1).toList(growable: false),
    );
    _emit();
    await _sendMessage(parts: next.content, attachments: next.attachments);
  }

  /// Remembers the unsent text of the thread being left.
  void _saveDraft() {
    final String text = _composer.text;
    if (text.trim().isEmpty) {
      _drafts.remove(_mainThreadId);
    } else {
      _drafts[_mainThreadId] = text;
    }
  }

  // ------------------------------------------------------------- composer

  void _setText(String text) {
    if (_composer.text == text) return;
    _composer = _composer.copyWith(text: text);
    _emit();
  }

  void _addAttachment(AuiAttachment attachment) {
    _composer = _composer.copyWith(
      attachments: <AuiAttachment>[..._composer.attachments, attachment],
    );
    _emit();
  }

  Future<void> _addPendingAttachment(PendingAttachment file) async {
    final AttachmentAdapter? adapter = options.attachmentAdapter;
    if (adapter == null) {
      _addAttachment(_attachmentFromPending(file));
      return;
    }
    await for (final AttachmentAddResult result in adapter.add(file)) {
      if (result.status == AttachmentAddStatus.complete &&
          result.attachment != null) {
        _addAttachment(result.attachment!);
        return;
      }
      if (result.status == AttachmentAddStatus.incomplete) return;
    }
  }

  static AuiAttachment _attachmentFromPending(PendingAttachment file) {
    final bool isImage = file.mimeType.startsWith('image/');
    final String? payload = file.data == null
        ? file.url
        : 'data:${file.mimeType};base64,${base64Encode(file.data!)}';
    if (isImage) {
      return ImageAttachment(
        id: file.id,
        url: payload ?? '',
        filename: file.filename,
      );
    }
    return DocumentAttachment(
      id: file.id,
      mimeType: file.mimeType,
      data: payload,
      filename: file.filename,
    );
  }

  void _removeAttachment(String id) {
    AuiAttachment? removed;
    for (final AuiAttachment attachment in _composer.attachments) {
      if (attachment.id == id) removed = attachment;
    }
    if (removed != null) {
      unawaited(options.attachmentAdapter?.remove(removed));
    }
    _composer = _composer.copyWith(
      attachments: _composer.attachments
          .where((AuiAttachment a) => a.id != id)
          .toList(growable: false),
    );
    _emit();
  }

  Future<void> _submitComposer() async {
    if (_composer.isEditing) {
      await _commitEdit();
      return;
    }
    if (!_composer.canSend) return;
    final List<AuiAttachment> attachments = _composer.attachments;
    final List<MessagePart> parts = <MessagePart>[
      if (_composer.text.trim().isNotEmpty) TextPart(_composer.text.trim()),
      for (final AuiAttachment attachment in attachments) attachment.asPart,
    ];
    // Typing during a run stacks the turn instead of dropping it.
    if (_activeRun != null) {
      _enqueue(parts, attachments);
      return;
    }
    await _sendMessage(parts: parts, attachments: attachments);
  }

  void _cancelComposer() {
    if (_composer.isEditing) {
      _cancelEdit();
      return;
    }
    _composer = _composer.copyWith(
      text: '',
      attachments: const <AuiAttachment>[],
      clearDictation: true,
    );
    _emit();
  }
}

/// One conversation: its list item plus its messages.
class _ThreadRecord {
  _ThreadRecord({required this.item, required this.messages});

  ThreadListItem item;
  final List<ThreadMessage> messages;
}

/// Thread-list operations, delegating to the runtime.
class _LocalThreadsApi implements ThreadsRuntimeApi {
  _LocalThreadsApi(this._runtime);

  final LocalRuntime _runtime;

  @override
  ThreadsState get state => _runtime.threadsState;

  @override
  Future<void> switchToThread(String threadId) =>
      _runtime._switchToThread(threadId);

  @override
  Future<String> create({String? title}) => _runtime._createThread(title: title);

  @override
  Future<void> archive(String threadId) => _runtime._archiveThread(threadId);

  @override
  Future<void> unarchive(String threadId) => _runtime._unarchiveThread(threadId);

  @override
  Future<void> delete(String threadId) => _runtime._deleteThread(threadId);

  @override
  Future<void> rename(String threadId, String title) =>
      _runtime._renameThread(threadId, title);

  @override
  Future<void> loadMore() => _runtime._loadMoreThreads();
}

class _ActiveRun {
  _ActiveRun({required this.messageId, required this.controller});

  final String messageId;
  final AbortController controller;
}

class _LocalThreadApi implements ThreadRuntimeApi {
  _LocalThreadApi(this._runtime);

  final LocalRuntime _runtime;

  @override
  ThreadState get state => _runtime.threadState;

  @override
  void setSuggestions(List<ThreadSuggestion> suggestions) =>
      _runtime.updateSuggestions(suggestions);

  @override
  Future<void> get settled => _runtime.settled;

  @override
  Future<void> append(ThreadMessage message) => _runtime._append(message);

  @override
  Future<void> send({
    List<MessagePart>? content,
    List<AuiAttachment> attachments = const <AuiAttachment>[],
  }) {
    final List<MessagePart> parts = <MessagePart>[
      if (content != null && content.isNotEmpty) ...content,
      for (final AuiAttachment attachment in attachments) attachment.asPart,
    ];
    return _runtime._sendMessage(parts: parts, attachments: attachments);
  }

  @override
  Future<void> startRun({String? parentId}) => _runtime._startRun(parentId: parentId);

  @override
  void cancelRun() => _runtime._cancelRun();

  @override
  Future<void> reload({String? messageId}) => _runtime._reload(messageId: messageId);

  @override
  void beginEdit(String messageId) => _runtime._beginEdit(messageId);

  @override
  void cancelEdit() => _runtime._cancelEdit();

  @override
  Future<void> commitEdit({List<MessagePart>? content}) =>
      _runtime._commitEdit(content: content);

  @override
  void switchToBranch(String messageId, int branchIndex) =>
      _runtime._switchToBranch(messageId, branchIndex);

  @override
  Future<void> addToolResult({
    required String toolCallId,
    Object? result,
    bool isError = false,
  }) =>
      _runtime._addToolResult(
        toolCallId: toolCallId,
        result: result,
        isError: isError,
      );

  @override
  Future<void> speak(String messageId) => _runtime._speak(messageId);

  @override
  Future<void> stopSpeaking() => _runtime._stopSpeaking();

  @override
  Future<void> submitFeedback({
    required String messageId,
    required FeedbackType type,
    String? comment,
  }) =>
      _runtime._submitFeedback(
        messageId: messageId,
        type: type,
        comment: comment,
      );

  @override
  Future<void> startDictation() => _runtime._startDictation();

  @override
  Future<void> stopDictation() => _runtime._stopDictation();
}

class _LocalComposerApi implements ComposerRuntimeApi {
  _LocalComposerApi(this._runtime);

  final LocalRuntime _runtime;

  @override
  ComposerState get state => _runtime.composerState;

  @override
  void setText(String text) => _runtime._setText(text);

  @override
  void addAttachment(AuiAttachment attachment) =>
      _runtime._addAttachment(attachment);

  @override
  Future<void> addPendingAttachment(PendingAttachment file) =>
      _runtime._addPendingAttachment(file);

  @override
  void removeAttachment(String id) => _runtime._removeAttachment(id);

  @override
  Future<void> send() => _runtime._submitComposer();

  @override
  void removeQueued(String id) => _runtime._removeQueued(id);

  @override
  void clearQueued() => _runtime._clearQueued();

  @override
  void cancel() => _runtime._cancelComposer();
}
