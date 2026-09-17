import 'dart:async';

import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the context every run receives.
class _RecordingAdapter implements ChatModelAdapter {
  final List<ModelContext> contexts = <ModelContext>[];

  @override
  Stream<ChatModelRunResult> run(ChatModelRunContext context) async* {
    contexts.add(context.context);
    yield const ChatModelRunResult(content: <MessagePart>[TextPart('ok')]);
  }
}

void main() {
  test('the run context carries the picked model and effort', () async {
    final _RecordingAdapter adapter = _RecordingAdapter();
    final LocalRuntime runtime = LocalRuntime(adapter: adapter);

    await runtime.thread.send(content: <MessagePart>[const TextPart('hi')]);
    await runtime.thread.settled;
    expect(adapter.contexts.single.model, isNull);

    runtime.setModel('gpt-5.6-luna');
    runtime.setEffort('high');
    await runtime.thread.send(content: <MessagePart>[const TextPart('again')]);
    await runtime.thread.settled;

    expect(adapter.contexts.last.model, 'gpt-5.6-luna');
    expect(adapter.contexts.last.effort, 'high');
  });

  test('options seed the selection and the state reports it', () {
    final LocalRuntime runtime = LocalRuntime(
      adapter: _RecordingAdapter(),
      options: const LocalRuntimeOptions(model: 'claude-opus-4.7', effort: 'low'),
    );
    expect(runtime.modelContext.model, 'claude-opus-4.7');
    expect(runtime.modelContext.effort, 'low');
    expect(runtime.state.thread.model, 'claude-opus-4.7');
    expect(runtime.state.thread.effort, 'low');

    runtime.setModel('gpt-5.6-luna');
    expect(runtime.state.thread.model, 'gpt-5.6-luna');
    // The effort is independent of the model switch.
    expect(runtime.state.thread.effort, 'low');
    runtime.setEffort(null);
    expect(runtime.state.thread.effort, isNull);
    expect(runtime.modelContext.effort, isNull);
  });

  test('the selector reports picks and effort changes', () {
    String? model;
    String? effort;
    final AssistantModelSelector selector = AssistantModelSelector(
      models: const <ModelOption>[
        ModelOption(
          id: 'gpt-5.6-luna',
          name: 'GPT-5.6 Luna',
          usesDefaultEfforts: true,
        ),
        ModelOption(id: 'claude-opus-4.7', name: 'Claude Opus 4.7'),
      ],
      value: 'claude-opus-4.7',
      onValueChange: (String id) => model = id,
      onEffortChange: (String id) => effort = id,
    );
    // The defaults upstream ships.
    expect(auiDefaultEffortOptions.map((ModelSelectorEffortOption o) => o.id),
        <String>['low', 'medium', 'high', 'max']);
    expect(
      selector.models.first.effortOptions!.map((ModelSelectorEffortOption o) => o.name),
      <String>['Low', 'Med', 'High', 'Max'],
    );
    // A model without `efforts` offers none.
    expect(selector.models.last.effortOptions, isNull);
    // The resolver drops an effort the new model does not take.
    // The resolver drops an effort the model does not take, and keeps one it does.
    expect(
      auiResolveModelEffort(selector.models, 'claude-opus-4.7', 'high'),
      isNull,
    );
    expect(
      auiResolveModelEffort(selector.models, 'gpt-5.6-luna', 'high'),
      'high',
    );
    expect(auiResolveModelEffort(selector.models, 'gpt-5.6-luna', null), isNull);
    // The callbacks are wired even before a pick happens.
    expect(model, isNull);
    expect(effort, isNull);
  });
}
