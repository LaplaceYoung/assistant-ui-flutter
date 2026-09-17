import 'dart:convert';
import 'dart:io';

import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// A scripted AG-UI agent: reads one RunAgentInput and writes the events back
/// as an SSE stream, the way a real endpoint does.
Future<(HttpServer, List<Map<String, Object?>>)> _agent(
  List<Map<String, Object?>> events, {
  int status = 200,
  String body = '',
}) async {
  final HttpServer server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final List<Map<String, Object?>> requests = <Map<String, Object?>>[];
  server.listen((HttpRequest request) async {
    final String raw = await utf8.decoder.bind(request).join();
    requests.add(jsonDecode(raw) as Map<String, Object?>);
    if (status >= 400) {
      request.response.statusCode = status;
      request.response.write(body);
      await request.response.close();
      return;
    }
    request.response.headers
        .set(HttpHeaders.contentTypeHeader, 'text/event-stream');
    for (final Map<String, Object?> event in events) {
      request.response.write('data: ${jsonEncode(event)}\n\n');
      await request.response.flush();
    }
    request.response.write('data: [DONE]\n\n');
    await request.response.close();
  });
  return (server, requests);
}

void main() {
  group('parser', () {
    test('reads the text, tool and lifecycle events', () {
      expect(
        parseAgUiEvent(<String, Object?>{'type': 'RUN_STARTED', 'runId': 'r1'}),
        isA<AgUiRunStarted>().having((AgUiRunStarted e) => e.runId, 'runId', 'r1'),
      );
      expect(
        parseAgUiEvent(<String, Object?>{
          'type': 'TEXT_MESSAGE_CONTENT',
          'delta': 'hi',
          'messageId': 'm1',
        }),
        isA<AgUiTextMessageContent>()
            .having((AgUiTextMessageContent e) => e.delta, 'delta', 'hi')
            .having((AgUiTextMessageContent e) => e.messageId, 'messageId', 'm1'),
      );
      expect(
        parseAgUiEvent(<String, Object?>{
          'type': 'TOOL_CALL_START',
          'toolCallId': 'c1',
          'toolCallName': 'search',
        }),
        isA<AgUiToolCallStart>()
            .having((AgUiToolCallStart e) => e.toolCallId, 'id', 'c1')
            .having((AgUiToolCallStart e) => e.toolCallName, 'name', 'search'),
      );
      expect(
        parseAgUiEvent(<String, Object?>{'type': 'RUN_CANCELLED'}),
        isA<AgUiRunCancelled>(),
      );
    });

    test('rejects malformed events instead of throwing', () {
      expect(parseAgUiEvent(null), isNull);
      expect(parseAgUiEvent('not an object'), isNull);
      expect(parseAgUiEvent(<String, Object?>{'type': 42}), isNull);
      expect(parseAgUiEvent(<String, Object?>{'type': 'RUN_STARTED'}), isNull);
      // An empty delta carries no content.
      expect(
        parseAgUiEvent(<String, Object?>{'type': 'TEXT_MESSAGE_CONTENT', 'delta': ''}),
        isNull,
      );
      expect(
        parseAgUiEvent(<String, Object?>{'type': 'TOOL_CALL_ARGS'}),
        isNull,
      );
      expect(
        parseAgUiEvent(<String, Object?>{'type': 'ACTIVITY_SNAPSHOT', 'activityType': 'x'}),
        isNull,
      );
    });

    test('keeps an unknown type as a raw event with its source', () {
      final AgUiEvent? event = parseAgUiEvent(
        <String, Object?>{'type': 'SOMETHING_NEW', 'value': 7},
      );
      expect(event, isA<AgUiRaw>());
      final AgUiRaw raw = event! as AgUiRaw;
      expect(raw.source, 'SOMETHING_NEW');
      expect((raw.event! as Map<String, Object?>)['value'], 7);
    });

    test('parses interrupts and their schema', () {
      final AgUiEvent? event = parseAgUiEvent(<String, Object?>{
        'type': 'RUN_FINISHED',
        'runId': 'r1',
        'outcome': <String, Object?>{
          'type': 'interrupt',
          'interrupts': <Object?>[
            <String, Object?>{
              'id': 'i1',
              'reason': 'tool_call',
              'toolCallId': 'c9',
              'message': 'Approve the delete?',
              'responseSchema': <String, Object?>{'type': 'boolean'},
            },
            <String, Object?>{'id': 'broken'},
          ],
        },
      });
      expect(event, isA<AgUiRunFinished>());
      final AgUiRunOutcome? outcome = (event! as AgUiRunFinished).outcome;
      expect(outcome, isA<AgUiRunInterrupted>());
      final List<AgUiInterrupt> interrupts =
          (outcome! as AgUiRunInterrupted).interrupts;
      expect(interrupts.length, 1, reason: 'the malformed entry is dropped');
      expect(interrupts.single.id, 'i1');
      expect(interrupts.single.toolCallId, 'c9');
      expect(interrupts.single.responseSchema, <String, Object?>{'type': 'boolean'});
    });

    test('reads subagent lifecycle events', () {
      final AgUiEvent? started = parseAgUiEvent(<String, Object?>{
        'type': 'SUBAGENT_STARTED',
        'subagentRunId': 's1',
        'name': 'researcher',
        'description': 'Looks things up',
      });
      expect(started, isA<AgUiSubagentStarted>());
      expect((started! as AgUiSubagentStarted).name, 'researcher');

      final AgUiEvent? finished = parseAgUiEvent(<String, Object?>{
        'type': 'SUBAGENT_FINISHED',
        'subagentRunId': 's1',
        'outcome': <String, Object?>{
          'type': 'suspended',
          'interruptIds': <Object?>['i1'],
        },
      });
      expect(finished, isA<AgUiSubagentFinished>());
      final AgUiSubagentOutcome? outcome =
          (finished! as AgUiSubagentFinished).outcome;
      expect(outcome, isA<AgUiSubagentSuspended>());
      expect((outcome! as AgUiSubagentSuspended).interruptIds, <String>['i1']);
    });
  });

  group('adapter', () {
    test('accumulates text, thinking and tool calls into parts', () async {
      final (HttpServer server, List<Map<String, Object?>> requests) = await _agent(
        <Map<String, Object?>>[
          <String, Object?>{'type': 'RUN_STARTED', 'runId': 'r1'},
          <String, Object?>{'type': 'REASONING_MESSAGE_CONTENT', 'delta': 'checking '},
          <String, Object?>{'type': 'REASONING_MESSAGE_CONTENT', 'delta': 'the docs'},
          <String, Object?>{'type': 'TEXT_MESSAGE_CONTENT', 'delta': 'Two '},
          <String, Object?>{'type': 'TEXT_MESSAGE_CONTENT', 'delta': 'hooks.'},
          <String, Object?>{
            'type': 'TOOL_CALL_START',
            'toolCallId': 'c1',
            'toolCallName': 'search',
          },
          <String, Object?>{'type': 'TOOL_CALL_ARGS', 'toolCallId': 'c1', 'delta': '{"q":'},
          <String, Object?>{'type': 'TOOL_CALL_ARGS', 'toolCallId': 'c1', 'delta': ' "hooks"}'},
          <String, Object?>{
            'type': 'TOOL_CALL_RESULT',
            'toolCallId': 'c1',
            'content': '3 results',
          },
          <String, Object?>{
            'type': 'RUN_FINISHED',
            'runId': 'r1',
            'outcome': <String, Object?>{'type': 'success'},
          },
        ],
      );
      addTearDown(() => server.close(force: true));

      final AgUiChatModelAdapter adapter = AgUiChatModelAdapter(
        url: 'http://127.0.0.1:${server.port}/agent',
        tools: <String, Object?>{
          'search': <String, Object?>{'description': 'Search', 'parameters': <String, Object?>{}},
        },
      );
      final List<ChatModelRunResult> results = await adapter
          .run(_context(<ThreadMessage>[]))
          .toList();

      final List<MessagePart> last = results.last.content;
      expect(last.whereType<ReasoningPart>().single.text, 'checking the docs');
      expect(last.whereType<TextPart>().single.text, 'Two hooks.');
      final ToolCallPart call = last.whereType<ToolCallPart>().single;
      expect(call.toolName, 'search');
      expect(call.args, <String, Object?>{'q': 'hooks'});
      expect(call.result, '3 results');
      expect(call.status, PartStatus.complete);
      expect(results.last.status, isA<MessageStatusComplete>());

      // The request carries the run input the protocol asks for.
      expect(requests.single['threadId'], isNotNull);
      expect(requests.single['runId'], isNotNull);
      expect(
        (requests.single['tools']! as List<Object?>).single,
        containsPair('name', 'search'),
      );
    });

    test('a run that parks on an interrupt ends requires-action', () async {
      final (HttpServer server, _) = await _agent(<Map<String, Object?>>[
        <String, Object?>{'type': 'RUN_STARTED', 'runId': 'r1'},
        <String, Object?>{
          'type': 'TOOL_CALL_START',
          'toolCallId': 'c1',
          'toolCallName': 'delete_file',
        },
        <String, Object?>{'type': 'TOOL_CALL_END', 'toolCallId': 'c1'},
        <String, Object?>{
          'type': 'RUN_FINISHED',
          'runId': 'r1',
          'outcome': <String, Object?>{
            'type': 'interrupt',
            'interrupts': <Object?>[
              <String, Object?>{
                'id': 'i1',
                'reason': 'tool_call',
                'toolCallId': 'c1',
                'message': 'Delete build/?',
              },
            ],
          },
        },
      ]);
      addTearDown(() => server.close(force: true));

      final AgUiChatModelAdapter adapter = AgUiChatModelAdapter(
        url: 'http://127.0.0.1:${server.port}/agent',
      );
      final List<ChatModelRunResult> results =
          await adapter.run(_context(<ThreadMessage>[])).toList();

      expect(results.last.status, isA<MessageStatusRequiresAction>());
      expect(adapter.pendingInterrupts.single.id, 'i1');
      expect(adapter.pendingInterrupts.single.message, 'Delete build/?');
    });

    test('state, activity and custom events land in lastState', () async {
      final (HttpServer server, _) = await _agent(<Map<String, Object?>>[
        <String, Object?>{'type': 'STATE_SNAPSHOT', 'snapshot': <String, Object?>{'n': 1}},
        <String, Object?>{
          'type': 'STATE_DELTA',
          'delta': <Object?>[
            <String, Object?>{'op': 'replace', 'path': '/n', 'value': 2},
          ],
        },
        <String, Object?>{
          'type': 'ACTIVITY_SNAPSHOT',
          'activityType': 'plan',
          'content': <String, Object?>{'steps': 3},
        },
        <String, Object?>{'type': 'CUSTOM', 'name': 'citation', 'value': 'x'},
        <String, Object?>{'type': 'RUN_FINISHED', 'runId': 'r1'},
      ]);
      addTearDown(() => server.close(force: true));

      final AgUiChatModelAdapter adapter = AgUiChatModelAdapter(
        url: 'http://127.0.0.1:${server.port}/agent',
      );
      await adapter.run(_context(<ThreadMessage>[])).toList();

      expect(adapter.lastState['snapshot'], <String, Object?>{'n': 1});
      expect(adapter.lastState['plan'], <String, Object?>{'steps': 3});
      expect(adapter.lastState['citation'], 'x');
    });

    test('a run error surfaces as AgUiException', () async {
      final (HttpServer server, _) = await _agent(<Map<String, Object?>>[
        <String, Object?>{'type': 'RUN_STARTED', 'runId': 'r1'},
        <String, Object?>{
          'type': 'RUN_ERROR',
          'message': 'model unavailable',
          'code': 'unavailable',
        },
      ]);
      addTearDown(() => server.close(force: true));

      final AgUiChatModelAdapter adapter = AgUiChatModelAdapter(
        url: 'http://127.0.0.1:${server.port}/agent',
      );
      await expectLater(
        adapter.run(_context(<ThreadMessage>[])).toList(),
        throwsA(isA<AgUiException>().having(
          (AgUiException e) => e.message,
          'message',
          'model unavailable',
        )),
      );
    });

    test('an HTTP failure is reported with the status', () async {
      final (HttpServer server, _) = await _agent(
        const <Map<String, Object?>>[],
        status: 503,
        body: 'busy',
      );
      addTearDown(() => server.close(force: true));

      final AgUiChatModelAdapter adapter = AgUiChatModelAdapter(
        url: 'http://127.0.0.1:${server.port}/agent',
      );
      await expectLater(
        adapter.run(_context(<ThreadMessage>[])).toList(),
        throwsA(isA<AgUiException>().having(
          (AgUiException e) => e.message,
          'message',
          allOf(contains('503'), contains('busy')),
        )),
      );
    });

    test('the run input carries the conversation so far', () async {
      final (HttpServer server, List<Map<String, Object?>> requests) =
          await _agent(<Map<String, Object?>>[
        <String, Object?>{'type': 'RUN_FINISHED', 'runId': 'r1'},
      ]);
      addTearDown(() => server.close(force: true));

      final AgUiChatModelAdapter adapter = AgUiChatModelAdapter(
        url: 'http://127.0.0.1:${server.port}/agent',
        threadId: 'thread-fixed',
      );
      await adapter.run(_context(<ThreadMessage>[
        ThreadMessage.single(
          id: 'u1',
          role: MessageRole.user,
          content: const <MessagePart>[TextPart('Where are the hooks?')],
          createdAt: DateTime(2026, 9, 17),
        ),
      ])).toList();

      final Map<String, Object?> sent = requests.single;
      expect(sent['threadId'], 'thread-fixed');
      final Map<String, Object?> message =
          (sent['messages']! as List<Object?>).first! as Map<String, Object?>;
      expect(message['role'], 'user');
      expect(
        (message['content']! as List<Object?>).first,
        containsPair('type', 'text'),
      );
    });
  });
}

ChatModelRunContext _context(List<ThreadMessage> messages) {
  final AbortController controller = AbortController();
  addTearDown(controller.abort);
  return ChatModelRunContext(
    messages: messages,
    abortSignal: controller.signal,
    getMessage: () => messages.isEmpty
        ? ThreadMessage.single(
            id: 'a1',
            role: MessageRole.assistant,
            content: const <MessagePart>[],
            createdAt: DateTime(2026, 9, 17),
          )
        : messages.last,
  );
}
