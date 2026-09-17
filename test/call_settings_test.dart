import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Upstream's `ModelContext.callSettings`: the run parameters the host sets have
/// to reach the adapter, and clearing one must not fall back to the seed.
void main() {
  test('the adapter sees the settings the host picked', () async {
    final List<ModelContext> seen = <ModelContext>[];
    final LocalRuntime runtime = LocalRuntime(
      adapter: _RecordingAdapter(seen),
      options: const LocalRuntimeOptions(temperature: 0.2, maxTokens: 512),
    );

    expect(runtime.modelContext.temperature, 0.2);
    expect(runtime.modelContext.maxTokens, 512);
    expect(runtime.modelContext.topP, isNull);
    expect(runtime.modelContext.seed, isNull);

    runtime.setTemperature(0.9);
    runtime.setMaxTokens(2048);
    expect(runtime.modelContext.temperature, 0.9);
    expect(runtime.modelContext.maxTokens, 2048);

    await runtime.thread.send(content: <MessagePart>[const TextPart('go')]);
    await runtime.thread.settled;
    expect(seen.single.temperature, 0.9);
    expect(seen.single.maxTokens, 2048);
  });

  test('clearing a setting does not resurrect the seed', () async {
    final LocalRuntime runtime = LocalRuntime(
      adapter: _RecordingAdapter(<ModelContext>[]),
      options: const LocalRuntimeOptions(temperature: 0.2),
    );
    runtime.setTemperature(null);
    expect(runtime.modelContext.temperature, isNull);
    expect(runtime.temperature, isNull);
  });
}

class _RecordingAdapter implements ChatModelAdapter {
  _RecordingAdapter(this.seen);

  final List<ModelContext> seen;

  @override
  Stream<ChatModelRunResult> run(ChatModelRunContext context) async* {
    seen.add(context.context);
    yield const ChatModelRunResult(
      content: <MessagePart>[TextPart('ok')],
      status: MessageStatusComplete(),
    );
  }
}
