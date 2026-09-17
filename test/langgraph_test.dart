import 'dart:convert';
import 'dart:io';

import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// A scripted LangGraph Platform server: thread creation and an SSE run.
Future<(HttpServer, List<String>)> _server({
  List<(String, Object?)> events = const <(String, Object?)>[],
  String threadId = 'thread-1',
  int runStatus = 200,
  Map<String, Object?>? state,
}) async {
  final HttpServer server =
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final List<String> seen = <String>[];
  server.listen((HttpRequest request) async {
    final String body = await utf8.decoder.bind(request).join();
    seen.add('${request.method} ${request.uri.path} $body');
    final String path = request.uri.path;
    if (path == '/threads') {
      request.response.headers
          .set(HttpHeaders.contentTypeHeader, 'application/json');
      request.response.write(jsonEncode(<String, Object?>{'thread_id': threadId}));
    } else if (path.endsWith('/runs/stream')) {
      request.response.statusCode = runStatus;
      if (runStatus >= 400) {
        request.response.write('{"detail": "not found"}');
      } else {
        request.response.headers
            .set(HttpHeaders.contentTypeHeader, 'text/event-stream');
        for (final (String name, Object? data) in events) {
          request.response.write('event: $name\n');
          request.response.write('data: ${jsonEncode(data)}\n\n');
          await request.response.flush();
        }
      }
    } else if (path.endsWith('/state')) {
      request.response.headers
          .set(HttpHeaders.contentTypeHeader, 'application/json');
      request.response.write(jsonEncode(state ?? <String, Object?>{}));
    } else {
      request.response.statusCode = 404;
    }
    await request.response.close();
  });
  return (server, seen);
}

Map<String, Object?> _aiChunk(String text, {String id = 'm1'}) =>
    <String, Object?>{
      'type': 'AIMessageChunk',
      'id': id,
      'content': text,
    };

void main() {
  group('accumulator', () {
    test('concatenates streamed text and thinking by index', () {
      Map<String, Object?> acc = langGraphAppendChunk(
        null,
        <String, Object?>{
          'type': 'AIMessageChunk',
          'id': 'm1',
          'content': <Object?>[
            <String, Object?>{'type': 'thinking', 'index': 0, 'thinking': 'pon'},
          ],
        },
      );
      acc = langGraphAppendChunk(acc, <String, Object?>{
        'type': 'AIMessageChunk',
        'id': 'm1',
        'content': <Object?>[
          <String, Object?>{'type': 'thinking', 'index': 0, 'thinking': 'der'},
        ],
      });
      acc = langGraphAppendChunk(acc, _aiChunk('The '));
      acc = langGraphAppendChunk(acc, _aiChunk('answer.'));

      final List<Object?> content = acc['content']! as List<Object?>;
      expect((content[0]! as Map<String, Object?>)['thinking'], 'ponder');
      expect((content[1]! as Map<String, Object?>)['text'], 'The answer.');
    });

    test('concatenates tool-call arguments into partial JSON', () {
      Map<String, Object?> acc = langGraphAppendChunk(null, <String, Object?>{
        'type': 'AIMessageChunk',
        'id': 'm1',
        'content': '',
        'tool_call_chunks': <Object?>[
          <String, Object?>{'id': 'c1', 'name': 'search', 'args': '{"q":', 'index': 0},
        ],
      });
      acc = langGraphAppendChunk(acc, <String, Object?>{
        'type': 'AIMessageChunk',
        'id': 'm1',
        'content': '',
        'tool_call_chunks': <Object?>[
          <String, Object?>{'id': 'c1', 'args': ' "hooks"}', 'index': 0},
        ],
      });

      final Map<String, Object?> call =
          (acc['tool_calls']! as List<Object?>).single! as Map<String, Object?>;
      expect(call['id'], 'c1');
      expect(call['name'], 'search');
      expect(call['partial_json'], '{"q": "hooks"}');
      expect(call['args'], <String, Object?>{'q': 'hooks'});
    });

    test('a complete message keeps the streamed partial JSON', () {
      final Map<String, Object?> streamed = langGraphAppendChunk(
        null,
        <String, Object?>{
          'type': 'AIMessageChunk',
          'id': 'm1',
          'content': '',
          'tool_call_chunks': <Object?>[
            <String, Object?>{'id': 'c1', 'name': 'weather', 'args': '{"city": "Tokyo"}', 'index': 0},
          ],
        },
      );
      final Map<String, Object?> complete = langGraphAppendChunk(
        streamed,
        <String, Object?>{
          'type': 'ai',
          'id': 'm1',
          'content': 'checking',
          'tool_calls': <Object?>[
            <String, Object?>{
              'id': 'c1',
              'name': 'weather',
              'args': <String, Object?>{'city': 'Tokyo'},
            },
          ],
        },
      );
      final Map<String, Object?> call =
          (complete['tool_calls']! as List<Object?>).single! as Map<String, Object?>;
      expect(call['partial_json'], '{"city": "Tokyo"}');
    });

    test('the accumulator upserts by id and honours remove', () {
      final LangGraphMessageAccumulator accumulator = LangGraphMessageAccumulator(
        initialMessages: <Map<String, Object?>>[
          <String, Object?>{'type': 'human', 'id': 'u1', 'content': 'hi'},
        ],
      );
      accumulator.addMessages(<Map<String, Object?>>[_aiChunk('a')]);
      accumulator.addMessages(<Map<String, Object?>>[_aiChunk('b')]);
      expect(accumulator.messages.length, 2);
      expect(
        (accumulator.byId('m1')!['content']! as List<Object?>).single,
        containsPair('text', 'ab'),
      );

      accumulator.addMessages(<Map<String, Object?>>[
        <String, Object?>{'type': 'remove', 'id': 'm1'},
      ]);
      expect(accumulator.messages.length, 1);
      expect(accumulator.byId('m1'), isNull);

      accumulator.addMessages(<Map<String, Object?>>[
        <String, Object?>{'type': 'remove', 'id': LangGraphMessageAccumulator.removeAllSentinel},
      ]);
      expect(accumulator.messages, isEmpty);
    });

    test('reads messages and interrupts out of updates payloads', () {
      expect(
        langGraphMessagesOf(<String, Object?>{
          'agent': <String, Object?>{
            'messages': <Object?>[
              <String, Object?>{'type': 'ai', 'id': 'm1', 'content': 'x'},
            ],
          },
        }).single['id'],
        'm1',
      );
      expect(
        langGraphInterruptsOf(<String, Object?>{
          'agent': <String, Object?>{
            '__interrupt__': <Object?>[
              <String, Object?>{'value': 'Approve?', 'id': 'i1'},
            ],
          },
        }).single['id'],
        'i1',
      );
      expect(langGraphInterruptsOf(<String, Object?>{'agent': 1}), isEmpty);
    });
  });

  group('conversions', () {
    test('maps LangChain messages onto parts', () {
      final List<MessagePart> human = langChainMessageToParts(<String, Object?>{
        'type': 'human',
        'content': <Object?>[
          <String, Object?>{'type': 'text', 'text': 'look at '},
          <String, Object?>{'type': 'image', 'image': 'data:image/png;base64,AA'},
        ],
      });
      expect(human.whereType<TextPart>().single.text, 'look at ');
      expect(human.whereType<ImagePart>().single.image, 'data:image/png;base64,AA');

      final List<MessagePart> ai = langChainMessageToParts(<String, Object?>{
        'type': 'ai',
        'content': 'done',
        'additional_kwargs': <String, Object?>{'reasoning': 'because'},
        'tool_calls': <Object?>[
          <String, Object?>{
            'id': 'c1',
            'name': 'search',
            'args': <String, Object?>{'q': 'x'},
          },
        ],
      });
      expect(ai.whereType<ReasoningPart>().single.text, 'because');
      expect(ai.whereType<TextPart>().single.text, 'done');
      expect(ai.whereType<ToolCallPart>().single.toolName, 'search');
    });

    test('tool results land on the call they answer', () {
      final List<MessagePart> parts = <MessagePart>[
        const ToolCallPart(toolCallId: 'c1', toolName: 'search'),
        const TextPart('note'),
      ];
      final List<MessagePart> patched = applyLangChainToolResult(
        parts,
        <String, Object?>{
          'type': 'tool',
          'tool_call_id': 'c1',
          'content': '3 results',
        },
      );
      final ToolCallPart call = patched.whereType<ToolCallPart>().single;
      expect(call.result, '3 results');
      expect(call.status, PartStatus.complete);
      expect(patched.whereType<TextPart>().single.text, 'note');
    });

    test('a thread message becomes a wire message', () {
      final Map<String, Object?> wire = threadMessageToLangChain(
        ThreadMessage.single(
          id: 'u1',
          role: MessageRole.user,
          createdAt: DateTime(2026, 9, 17),
          content: const <MessagePart>[TextPart('hello')],
        ),
      );
      expect(wire['type'], 'human');
      expect(wire['id'], 'u1');
      expect((wire['content']! as List<Object?>).single, containsPair('text', 'hello'));
    });

    test('partial JSON parses whole, prefix and not at all', () {
      expect(parsePartialJsonObject('{"a": 1}'), <String, Object?>{'a': 1});
      expect(parsePartialJsonObject('{"a": '), isNull);
      expect(parsePartialJsonObject(''), isNull);
    });
  });

  group('client and adapter', () {
    test('creates a thread and streams a run into parts', () async {
      final (HttpServer server, List<String> seen) = await _server(
        events: <(String, Object?)>[
          ('metadata', <String, Object?>{'run_id': 'r1'}),
          ('messages/partial', <Object?>[_aiChunk('The ')]),
          ('messages/partial', <Object?>[_aiChunk('answer.')]),
          (
            'updates',
            <String, Object?>{
              'agent': <String, Object?>{
                'messages': <Object?>[
                  <String, Object?>{'type': 'ai', 'id': 'm1', 'content': 'The answer.'},
                ],
              },
            },
          ),
          ('custom', <String, Object?>{'step': 'done'}),
          ('messages/complete', <Object?>[
            <String, Object?>{'type': 'ai', 'id': 'm1', 'content': 'The answer.'},
          ]),
          ('end', null),
        ],
      );
      addTearDown(() => server.close(force: true));

      final LangGraphChatModelAdapter adapter = LangGraphChatModelAdapter(
        client: LangGraphClient(baseUrl: 'http://127.0.0.1:${server.port}'),
        assistantId: 'agent',
      );
      final List<ChatModelRunResult> results =
          await adapter.run(_context(<ThreadMessage>[])).toList();

      expect(
        results.last.content.whereType<TextPart>().single.text,
        'The answer.',
      );
      expect(results.last.status, isA<MessageStatusComplete>());
      expect(adapter.lastMetadata!['run_id'], 'r1');
      expect(adapter.customEvents.single, <String, Object?>{'step': 'done'});
      expect(seen.first, contains('POST /threads'));
      expect(seen.last, contains('/threads/thread-1/runs/stream'));
      expect(seen.last, contains('"assistant_id":"agent"'));
    });

    test('an interrupt parks the run', () async {
      final (HttpServer server, _) = await _server(
        events: <(String, Object?)>[
          (
            'updates',
            <String, Object?>{
              'tools': <String, Object?>{
                '__interrupt__': <Object?>[
                  <String, Object?>{'value': 'Delete build/?', 'id': 'i1'},
                ],
              },
            },
          ),
        ],
      );
      addTearDown(() => server.close(force: true));

      final LangGraphChatModelAdapter adapter = LangGraphChatModelAdapter(
        client: LangGraphClient(baseUrl: 'http://127.0.0.1:${server.port}'),
        assistantId: 'agent',
      );
      final List<ChatModelRunResult> results =
          await adapter.run(_context(<ThreadMessage>[])).toList();

      expect(results.last.status, isA<MessageStatusRequiresAction>());
      expect(adapter.pendingInterrupts.single['value'], 'Delete build/?');
    });

    test('values fill lastState and tool results attach', () async {
      final (HttpServer server, _) = await _server(
        events: <(String, Object?)>[
          (
            'messages/partial',
            <Object?>[
              <String, Object?>{
                'type': 'AIMessageChunk',
                'id': 'm1',
                'content': '',
                'tool_call_chunks': <Object?>[
                  <String, Object?>{
                    'id': 'c1',
                    'name': 'search',
                    'args': '{"q": "hooks"}',
                    'index': 0,
                  },
                ],
              },
            ],
          ),
          (
            'messages/complete',
            <Object?>[
              <String, Object?>{
                'type': 'tool',
                'id': 't1',
                'tool_call_id': 'c1',
                'content': '3 results',
              },
            ],
          ),
          (
            'values',
            <String, Object?>{'messages': <Object?>[], 'plan': 'ship it'},
          ),
          ('end', null),
        ],
      );
      addTearDown(() => server.close(force: true));

      final LangGraphChatModelAdapter adapter = LangGraphChatModelAdapter(
        client: LangGraphClient(baseUrl: 'http://127.0.0.1:${server.port}'),
        assistantId: 'agent',
      );
      final List<ChatModelRunResult> results =
          await adapter.run(_context(<ThreadMessage>[])).toList();

      final ToolCallPart call = results.last.content.whereType<ToolCallPart>().single;
      expect(call.toolName, 'search');
      expect(call.args, <String, Object?>{'q': 'hooks'});
      expect(call.result, '3 results');
      expect(adapter.lastState!['plan'], 'ship it');
    });

    test('an error event throws with the server message', () async {
      final (HttpServer server, _) = await _server(
        events: <(String, Object?)>[
          (
            'error',
            <String, Object?>{'error': 'GraphInterrupt', 'message': 'boom'},
          ),
        ],
      );
      addTearDown(() => server.close(force: true));

      final LangGraphChatModelAdapter adapter = LangGraphChatModelAdapter(
        client: LangGraphClient(baseUrl: 'http://127.0.0.1:${server.port}'),
        assistantId: 'agent',
      );
      await expectLater(
        adapter.run(_context(<ThreadMessage>[])).toList(),
        throwsA(isA<LangGraphException>()
            .having((LangGraphException e) => e.message, 'message', 'boom')),
      );
    });

    test('a run HTTP failure is reported', () async {
      final (HttpServer server, _) = await _server(runStatus: 404);
      addTearDown(() => server.close(force: true));

      final LangGraphChatModelAdapter adapter = LangGraphChatModelAdapter(
        client: LangGraphClient(baseUrl: 'http://127.0.0.1:${server.port}'),
        assistantId: 'agent',
      );
      await expectLater(
        adapter.run(_context(<ThreadMessage>[])).toList(),
        throwsA(isA<LangGraphException>().having(
          (LangGraphException e) => e.message,
          'message',
          allOf(contains('404'), contains('not found')),
        )),
      );
    });

    test('the run input carries the conversation and the state', () async {
      final (HttpServer server, List<String> seen) = await _server(
        events: <(String, Object?)>[('end', null)],
      );
      addTearDown(() => server.close(force: true));

      final LangGraphChatModelAdapter adapter = LangGraphChatModelAdapter(
        client: LangGraphClient(
          baseUrl: 'http://127.0.0.1:${server.port}',
          apiKey: 'key-1',
        ),
        assistantId: 'agent',
        threadId: 'thread-fixed',
        state: <String, Object?>{'plan': 'draft'},
      );
      await adapter.run(_context(<ThreadMessage>[
        ThreadMessage.single(
          id: 'u1',
          role: MessageRole.user,
          createdAt: DateTime(2026, 9, 17),
          content: const <MessagePart>[TextPart('Plan it')],
        ),
      ])).toList();

      final String run = seen.last;
      expect(run, contains('"assistant_id":"agent"'));
      expect(run, contains('"plan":"draft"'));
      expect(run, contains('"messages"'));
      expect(run, contains('thread-fixed'));
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
            content: const <MessagePart>[TextPart('continue')],
            createdAt: DateTime(2026, 9, 17),
          )
        : messages.last,
  );
}
