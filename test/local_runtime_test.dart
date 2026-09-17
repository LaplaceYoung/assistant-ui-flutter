import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('LocalRuntime', () {
    test('streams a reply into a running assistant message', () async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);

      // Mutations return once the run has started; `settled` waits for it.
      await runtime.thread.send(content: <MessagePart>[const TextPart('Hi')]);
      await settle();

      expect(runtime.state.thread.messages, hasLength(2));
      expect(runtime.state.thread.messages.first.role, MessageRole.user);
      final ThreadMessage assistant = runtime.state.thread.messages.last;
      expect(assistant.role, MessageRole.assistant);
      expect(assistant.status, isA<MessageStatusRunning>());
      expect(runtime.state.thread.isRunning, isTrue);
      expect(adapter.contexts.single.messages, hasLength(1),
          reason: 'the in-flight assistant message is not sent to the model');

      adapter.emit(<MessagePart>[const TextPart('Hel')]);
      adapter.emit(<MessagePart>[const TextPart('Hello')]);
      await settle();

      expect(runtime.state.thread.messages.last.text, 'Hello');

      await adapter.finish();
      await runtime.thread.settled;

      expect(runtime.state.thread.messages.last.status,
          isA<MessageStatusComplete>());
      expect(runtime.state.thread.isRunning, isFalse);
    });

    test('cancel keeps partial content and marks the run incomplete', () async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);

      await runtime.thread.send(content: <MessagePart>[const TextPart('Hi')]);
      adapter.emit(<MessagePart>[const TextPart('Half')]);
      await settle();

      runtime.thread.cancelRun();
      await runtime.thread.settled;

      final ThreadMessage assistant = runtime.state.thread.messages.last;
      expect(assistant.text, 'Half');
      expect(assistant.status, isA<MessageStatusIncomplete>());
      expect((assistant.status as MessageStatusIncomplete).reason,
          IncompleteReason.cancelled);
      expect(adapter.aborted, isTrue);
      expect(runtime.state.thread.isRunning, isFalse);
    });

    test('an adapter error surfaces as incomplete(error)', () async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);

      await runtime.thread.send(content: <MessagePart>[const TextPart('Hi')]);
      adapter.current.addError(StateError('boom'));
      await runtime.thread.settled;

      final ThreadMessage assistant = runtime.state.thread.messages.last;
      expect(assistant.status, isA<MessageStatusIncomplete>());
      expect((assistant.status as MessageStatusIncomplete).reason,
          IncompleteReason.error);
      expect((assistant.status as MessageStatusIncomplete).error,
          contains('boom'));
    });

    test('reload adds a branch and the picker flips between them', () async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);

      await runtime.thread.send(content: <MessagePart>[const TextPart('Hi')]);
      await adapter.respondWith(<String>['first']);
      await runtime.thread.settled;

      final String assistantId = runtime.state.thread.messages.last.id;
      expect(runtime.state.thread.messages.last.branchCount, 1);

      await runtime.thread.reload();
      await settle();
      expect(adapter.runs, hasLength(2));

      await adapter.respondWith(<String>['second']);
      await runtime.thread.settled;

      ThreadMessage assistant = runtime.state.thread.messages.last;
      expect(assistant.id, assistantId);
      expect(assistant.branchCount, 2);
      expect(assistant.branchIndex, 1);
      expect(assistant.text, 'second');

      runtime.thread.switchToBranch(assistantId, 0);
      assistant = runtime.state.thread.messages.last;
      expect(assistant.text, 'first');
      expect(assistant.branchIndex, 0);
    });

    test('editing a user message truncates the thread and re-runs', () async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);

      await runtime.thread.send(content: <MessagePart>[const TextPart('Hi')]);
      await adapter.respondWith(<String>['hello there']);
      await runtime.thread.settled;

      final String userId = runtime.state.thread.messages.first.id;
      runtime.thread.beginEdit(userId);
      expect(runtime.state.composer.text, 'Hi');
      expect(runtime.state.composer.isEditing, isTrue);
      expect(runtime.state.thread.messages.first.isEditing, isTrue);

      runtime.composer.setText('Hi, edited');
      await runtime.thread.commitEdit();
      await settle();

      expect(runtime.state.thread.messages, hasLength(2),
          reason: 'the previous answer is dropped while the new one streams');
      final ThreadMessage user = runtime.state.thread.messages.first;
      expect(user.text, 'Hi, edited');
      expect(user.branchCount, 2);
      expect(user.isEditing, isFalse);

      await adapter.respondWith(<String>['answer two']);
      await runtime.thread.settled;

      expect(runtime.state.thread.messages.last.text, 'answer two');

      runtime.thread.switchToBranch(userId, 0);
      expect(runtime.state.thread.messageById(userId)!.text, 'Hi');
    });

    test('executes registered tools and continues the run', () async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(
        adapter: adapter,
        options: LocalRuntimeOptions(
          maxSteps: 2,
          tools: <String, ToolDefinition>{
            'get_weather': ToolDefinition(
              description: 'Get the weather',
              execute: (Map<String, Object?> args) async =>
                  'sunny in ${args['city']}',
            ),
          },
        ),
      );

      await runtime.thread.send(
        content: <MessagePart>[const TextPart('weather?')],
      );

      adapter.emit(<MessagePart>[
        const TextPart('Checking…'),
        const ToolCallPart(
          toolCallId: 'call_1',
          toolName: 'get_weather',
          args: <String, Object?>{'city': 'SF'},
        ),
      ]);
      await adapter.finish();

      await waitUntil(
        () => adapter.runs.length == 2,
        reason: 'a continuation run starts after the tool result lands',
      );

      final ThreadMessage midRun = runtime.state.thread.messages.last;
      expect(
        midRun.content.whereType<ToolCallPart>().single.result,
        'sunny in SF',
      );
      // The continuation sees the tool result.
      expect(
        adapter.contexts.last.messages.last.content
            .whereType<ToolCallPart>()
            .single
            .hasResult,
        isTrue,
      );

      adapter.emit(<MessagePart>[const TextPart('It is sunny.')]);
      await adapter.finish();
      await runtime.thread.settled;

      final ThreadMessage assistant = runtime.state.thread.messages.last;
      expect((assistant.content.last as TextPart).text, 'It is sunny.');
      expect(assistant.content, hasLength(3),
          reason: 'text, tool call and answer stay ordered in one message');
      expect(assistant.status, isA<MessageStatusComplete>());
    });

    test('human tools pause the run until a result arrives', () async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(
        adapter: adapter,
        options: LocalRuntimeOptions(
          maxSteps: 2,
          tools: <String, ToolDefinition>{
            'send_email': ToolDefinition.human(description: 'Ask the user'),
          },
        ),
      );

      await runtime.thread.send(
        content: <MessagePart>[const TextPart('email?')],
      );

      adapter.emit(
        <MessagePart>[
          const ToolCallPart(
            toolCallId: 'call_9',
            toolName: 'send_email',
            args: <String, Object?>{'to': 'a@b.c'},
          ),
        ],
        status: const MessageStatusRequiresAction(),
      );
      await runtime.thread.settled;

      expect(adapter.runs, hasLength(1), reason: 'no second run while paused');
      expect(runtime.state.thread.messages.last.status,
          isA<MessageStatusRequiresAction>());

      await runtime.thread.addToolResult(toolCallId: 'call_9', result: 'sent');
      await waitUntil(() => adapter.runs.length == 2);

      adapter.emit(<MessagePart>[const TextPart('Email sent.')]);
      await adapter.finish();
      await runtime.thread.settled;

      expect(runtime.state.thread.messages.last.text, 'Email sent.');
      expect(runtime.state.thread.messages.last.status,
          isA<MessageStatusComplete>());
    });

    test('tracks composer state and clears it on send', () async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(adapter: adapter);

      expect(runtime.state.composer.canSend, isFalse);
      runtime.composer.setText('  ');
      expect(runtime.state.composer.canSend, isFalse);

      runtime.composer.setText('Hello');
      expect(runtime.state.composer.canSend, isTrue);

      await runtime.composer.send();
      await settle();
      expect(runtime.state.composer.text, '');
      expect(runtime.state.composer.canSend, isFalse);
      expect(runtime.state.thread.messages.first.text, 'Hello');

      await adapter.respondWith(<String>['hi']);
      await runtime.thread.settled;

      runtime.composer.setText('draft');
      runtime.composer.cancel();
      expect(runtime.state.composer.text, '');
    });

    test('exposes tools to the adapter as JSON schema', () async {
      final ManualAdapter adapter = ManualAdapter();
      final LocalRuntime runtime = LocalRuntime(
        adapter: adapter,
        options: const LocalRuntimeOptions(
          systemPrompt: 'Be brief.',
          tools: <String, ToolDefinition>{
            'lookup': ToolDefinition(
              description: 'Look something up',
              parameters: <String, Object?>{'type': 'object'},
            ),
          },
        ),
      );

      await runtime.thread.send(content: <MessagePart>[const TextPart('go')]);
      await settle();

      final ModelContext context = adapter.contexts.single.context;
      expect(context.systemPrompt, 'Be brief.');
      expect(context.tools.single['name'], 'lookup');
      expect(
        (context.tools.single['parameters']! as Map<String, Object?>)['type'],
        'object',
      );

      await adapter.finish();
      await runtime.thread.settled;
    });
  });
}
