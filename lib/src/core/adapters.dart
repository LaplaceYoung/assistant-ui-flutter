import 'abort.dart';
import 'message.dart';
import 'message_part.dart';

/// System prompt plus the tool schemas the app exposes to the model.
class ModelContext {
  const ModelContext({
    this.systemPrompt,
    this.tools = const <Map<String, Object?>>[],
    this.model,
    this.effort,
  });

  final String? systemPrompt;

  /// The model the run should use, when the host picked one.
  final String? model;

  /// Its reasoning effort (`low` / `medium` / `high`), when the model takes one.
  final String? effort;

  /// JSON Schema descriptions of the available tools, ready to be sent to the
  /// backend (`[{name, description, parameters}, ...]`).
  final List<Map<String, Object?>> tools;
}

/// Everything an adapter gets for one run.
class ChatModelRunContext {
  const ChatModelRunContext({
    required this.messages,
    required this.abortSignal,
    this.context = const ModelContext(),
    required this.getMessage,
  });

  /// Conversation so far, excluding the assistant message being generated.
  final List<ThreadMessage> messages;

  final AbortSignal abortSignal;
  final ModelContext context;

  /// The assistant message this run is filling in, as it currently stands.
  ///
  /// Adapters that implement human-in-the-loop read tool results from it
  /// before deciding whether the run can continue.
  final ThreadMessage Function() getMessage;
}

/// One chunk of a streamed response.
///
/// Each event carries the **full cumulative content** of the message, not a
/// delta: yielding replaces what came before. Returning `[reasoning, text('')]`
/// to reserve a text slot makes the reasoning part read as finished, so guard
/// every text and reasoning part behind a non-empty check.
class ChatModelRunResult {
  const ChatModelRunResult({
    required this.content,
    this.status,
    this.metadata,
  });

  final List<MessagePart> content;

  /// Ending the run with a status — `requires-action` for human tools is the
  /// one adapters normally set. Defaults to `complete`.
  final MessageStatus? status;

  final MessageMetadata? metadata;
}

/// The one function a `LocalRuntime` needs from the app.
abstract class ChatModelAdapter {
  /// Streams the response. Declare it `async*` and yield cumulative content.
  Stream<ChatModelRunResult> run(ChatModelRunContext context);
}

/// Adapter that answers in a single event, for non-streaming backends.
class SingleShotChatModelAdapter extends ChatModelAdapter {
  SingleShotChatModelAdapter(this._respond);

  final Future<ChatModelRunResult> Function(ChatModelRunContext context) _respond;

  @override
  Stream<ChatModelRunResult> run(ChatModelRunContext context) async* {
    yield await _respond(context);
  }
}

/// Text shown in a tool call's UI while it runs and once it finishes.
class ToolRenderText {
  const ToolRenderText({this.running, this.complete});

  final String? running;
  final String? complete;
}

/// A callable capability handed to the model.
class ToolDefinition {
  const ToolDefinition({
    required this.description,
    this.parameters = const <String, Object?>{},
    this.execute,
    this.renderText,
    this.human = false,
  });

  /// Declares a tool a human answers, not code. Runs that ask for it end with
  /// `requires-action` until the app supplies a result.
  const ToolDefinition.human({
    required this.description,
    this.parameters = const <String, Object?>{},
    this.renderText,
  })  : execute = null,
        human = true;

  final String description;

  /// JSON Schema for the arguments.
  final Map<String, Object?> parameters;

  /// Runs the tool. Null for human tools.
  final Future<Object?> Function(Map<String, Object?> args)? execute;

  final ToolRenderText? renderText;
  final bool human;

  Map<String, Object?> toJsonSchema(String name) => <String, Object?>{
        'name': name,
        'description': description,
        'parameters': parameters,
      };
}

/// Tools keyed by name, as registered on a runtime.
typedef Toolkit = Map<String, ToolDefinition>;

/// Text-to-speech backend behind `ActionBarPrimitive.Speak`.
///
/// Upstream gates the button on the adapter being configured, and so does this
/// port: without a [SpeechSynthesisAdapter] the speak action stays disabled.
abstract class SpeechSynthesisAdapter {
  /// Starts speaking [text]; the returned future completes when playback ends.
  Future<void> speak(String text);

  /// Stops playback of the current utterance.
  Future<void> stop();
}

/// Speech-to-text backend behind `ComposerPrimitive.Dictate`.
abstract class DictationAdapter {
  /// Starts a session; the returned stream emits the transcript so far and
  /// completes when the session ends.
  Future<DictationSession> start();
}

class DictationSession {
  const DictationSession({required this.transcripts, required this.stop});

  /// Partial and final transcripts, in order.
  final Stream<String> transcripts;

  /// Ends the session and settles any final transcript.
  final Future<void> Function() stop;
}

/// Message rating, behind the thumbs in an action bar.
abstract class FeedbackAdapter {
  Future<void> submit(FeedbackRequest request);
}

class FeedbackRequest {
  const FeedbackRequest({
    required this.messageId,
    required this.type,
    this.comment,
  });

  final String messageId;
  final FeedbackType type;
  final String? comment;
}

enum FeedbackType { positive, negative }
