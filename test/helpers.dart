import 'dart:async';

import 'package:assistant_ui/assistant_ui.dart';

/// Adapter a test drives by hand: every `run` hands back a controller, so the
/// test decides when each chunk lands and when the stream closes.
class ManualAdapter extends ChatModelAdapter {
  final List<StreamController<ChatModelRunResult>> runs =
      <StreamController<ChatModelRunResult>>[];
  final List<ChatModelRunContext> contexts = <ChatModelRunContext>[];
  bool aborted = false;

  StreamController<ChatModelRunResult> get current => runs.last;

  bool get hasRun => runs.isNotEmpty;

  @override
  Stream<ChatModelRunResult> run(ChatModelRunContext context) {
    contexts.add(context);
    final StreamController<ChatModelRunResult> controller =
        StreamController<ChatModelRunResult>();
    runs.add(controller);
    context.abortSignal.addListener(() {
      aborted = true;
      if (!controller.isClosed) controller.close();
    });
    return controller.stream;
  }

  /// Emits one cumulative-content chunk.
  void emit(List<MessagePart> content, {MessageStatus? status}) {
    current.add(ChatModelRunResult(content: content, status: status));
  }

  /// Ends the current run.
  Future<void> finish({MessageStatus? status}) async {
    if (status != null) emit(const <MessagePart>[], status: status);
    await current.close();
  }

  /// Emits text chunks that accumulate, then closes.
  Future<void> respondWith(List<String> chunks) async {
    String text = '';
    for (final String chunk in chunks) {
      text += chunk;
      emit(<MessagePart>[TextPart(text)]);
      await Future<void>.delayed(Duration.zero);
    }
    await finish();
  }
}

/// Adapter that answers immediately with fixed content.
class StaticAdapter extends ChatModelAdapter {
  StaticAdapter(this.content);

  final List<MessagePart> content;

  @override
  Stream<ChatModelRunResult> run(ChatModelRunContext context) async* {
    yield ChatModelRunResult(content: content);
  }
}

/// Waits for the runtime to settle, then returns.
Future<void> settle() => Future<void>.delayed(Duration.zero);

/// Polls [condition] until it holds, failing after [timeout].
///
/// Runs are asynchronous by design, so tests wait for observable state instead
/// of assuming a fixed number of microtask turns.
Future<void> waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
  String? reason,
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('waitUntil timed out${reason == null ? '' : ': $reason'}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}


/// Dictation backend a test drives by hand.
class FakeDictationAdapter implements DictationAdapter {
  final StreamController<String> _transcripts =
      StreamController<String>.broadcast();
  bool stopped = false;

  void emit(String transcript) => _transcripts.add(transcript);

  @override
  Future<DictationSession> start() async => DictationSession(
        transcripts: _transcripts.stream,
        stop: () async {
          stopped = true;
          await _transcripts.close();
        },
      );
}
