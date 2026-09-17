import 'dart:convert';
import 'dart:io';

import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// A scripted A2A agent over real HTTP: card discovery, send, stream, tasks.
Future<(HttpServer, List<String>)> _agent({
  List<Map<String, Object?>> streamEvents = const <Map<String, Object?>>[],
  Map<String, Object?>? sendResult,
  Map<String, Object?>? taskResult,
  int sendStatus = 200,
  Map<String, Object?>? error,
  String? streamContentType,
}) async {
  final HttpServer server =
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final List<String> seen = <String>[];
  server.listen((HttpRequest request) async {
    final String body = await utf8.decoder.bind(request).join();
    seen.add('${request.method} ${request.uri.path}$body');
    final String path = request.uri.path;
    if (path == '/.well-known/agent-card.json') {
      request.response.headers
          .set(HttpHeaders.contentTypeHeader, 'application/a2a+json');
      request.response.write(jsonEncode(<String, Object?>{
        'name': 'demo-agent',
        'description': 'A test agent',
        'version': '1.2.3',
        'capabilities': <String, Object?>{'streaming': true},
        'skills': <Object?>[
          <String, Object?>{'id': 'search', 'name': 'Search'},
        ],
      }));
    } else if (path == '/message:stream') {
      request.response.headers.set(
        HttpHeaders.contentTypeHeader,
        streamContentType ?? 'text/event-stream',
      );
      if (error != null) {
        request.response.write('data: ${jsonEncode(<String, Object?>{'error': error})}\n\n');
      } else {
        for (final Map<String, Object?> event in streamEvents) {
          request.response.write('data: ${jsonEncode(event)}\n\n');
          await request.response.flush();
        }
      }
    } else if (path == '/message:send') {
      request.response.statusCode = sendStatus;
      request.response.headers
          .set(HttpHeaders.contentTypeHeader, 'application/a2a+json');
      request.response.write(jsonEncode(sendResult ?? <String, Object?>{}));
    } else if (path == '/tasks' || path.startsWith('/tasks/')) {
      request.response.headers
          .set(HttpHeaders.contentTypeHeader, 'application/a2a+json');
      request.response.write(jsonEncode(taskResult ?? <String, Object?>{}));
    } else {
      request.response.statusCode = 404;
    }
    await request.response.close();
  });
  return (server, seen);
}

Map<String, Object?> _artifactUpdate(
  String text, {
  String artifactId = 'a1',
  bool append = false,
  bool lastChunk = true,
}) =>
    <String, Object?>{
      'kind': 'artifact-update',
      'taskId': 't1',
      'contextId': 'c1',
      'artifact': <String, Object?>{
        'artifactId': artifactId,
        'name': 'answer',
        'parts': <Object?>[
          <String, Object?>{'text': text},
        ],
      },
      'append': append,
      'lastChunk': lastChunk,
    };

Map<String, Object?> _statusUpdate(String state, {String? messageText}) =>
    <String, Object?>{
      'kind': 'status-update',
      'taskId': 't1',
      'contextId': 'c1',
      'status': <String, Object?>{
        'state': state,
        'timestamp': '2026-09-17T10:00:00Z',
        if (messageText != null)
          'message': <String, Object?>{
            'messageId': 'm-status',
            'role': 'agent',
            'parts': <Object?>[
              <String, Object?>{'text': messageText},
            ],
          },
      },
    };

void main() {
  group('conversions', () {
    test('maps A2A parts onto message parts', () {
      expect(a2aPartToContent(const A2APart(text: 'hello')), isA<TextPart>());
      expect(
        a2aPartToContent(const A2APart(url: 'https://x/y.png', mediaType: 'image/png')),
        isA<ImagePart>(),
      );
      final MessagePart file = a2aPartToContent(
        const A2APart(url: 'https://x/y.pdf', mediaType: 'application/pdf', filename: 'y.pdf'),
      );
      expect(file, isA<FilePart>());
      expect((file as FilePart).filename, 'y.pdf');
      expect(
        a2aPartToContent(const A2APart(raw: 'AAAA', mediaType: 'image/jpeg')),
        isA<ImagePart>().having(
          (ImagePart part) => part.image,
          'image',
          'data:image/jpeg;base64,AAAA',
        ),
      );
      // Structured data renders as pretty JSON text, as upstream does.
      final MessagePart data =
          a2aPartToContent(const A2APart(data: <String, Object?>{'n': 1}));
      expect(data, isA<TextPart>());
      expect((data as TextPart).text, contains('"n": 1'));
      expect(a2aPartToContent(const A2APart()), isA<TextPart>());
    });

    test('maps thread messages onto A2A parts', () {
      final A2AMessage message = threadMessageToA2AMessage(
        ThreadMessage.single(
          id: 'u1',
          role: MessageRole.user,
          createdAt: DateTime(2026, 9, 17),
          content: const <MessagePart>[
            TextPart('look this up'),
            ImagePart(image: 'data:image/png;base64,QUJD'),
            FilePart(data: 'https://x/y.pdf', mimeType: 'application/pdf'),
          ],
        ),
        contextId: 'c1',
      );
      expect(message.messageId, 'u1');
      expect(message.role, A2ARole.user);
      expect(message.contextId, 'c1');
      expect(message.parts[0].text, 'look this up');
      expect(message.parts[1].raw, 'QUJD');
      expect(message.parts[1].mediaType, 'image/png');
      expect(message.parts[2].url, 'https://x/y.pdf');
      expect(message.parts[2].filename, isNull);
    });

    test('maps task states onto message statuses', () {
      expect(a2aTaskStateToMessageStatus(A2ATaskState.working),
          isA<MessageStatusRunning>());
      expect(a2aTaskStateToMessageStatus(A2ATaskState.completed),
          isA<MessageStatusComplete>());
      expect(a2aTaskStateToMessageStatus(A2ATaskState.failed),
          isA<MessageStatusIncomplete>());
      expect(a2aTaskStateToMessageStatus(A2ATaskState.canceled),
          isA<MessageStatusIncomplete>());
      expect(a2aTaskStateToMessageStatus(A2ATaskState.inputRequired),
          isA<MessageStatusRequiresAction>());
      expect(a2aTaskStateToMessageStatus(A2ATaskState.authRequired),
          isA<MessageStatusRequiresAction>());
      expect(A2ATaskState.inputRequired.isInterrupted, isTrue);
      expect(A2ATaskState.completed.isTerminal, isTrue);
      expect(A2ATaskState.working.isTerminal, isFalse);
    });

    test('reads the wrapped and flat stream shapes', () {
      final A2AStreamEvent? flat = A2AStreamEvent.fromJson(_artifactUpdate('x'));
      expect(flat, isA<A2AArtifactUpdateEvent>());
      expect((flat! as A2AArtifactUpdateEvent).artifact.artifactId, 'a1');

      final A2AStreamEvent? wrapped = A2AStreamEvent.fromJson(<String, Object?>{
        'artifactUpdate': <String, Object?>{
          'taskId': 't1',
          'contextId': 'c1',
          'artifact': <String, Object?>{
            'artifactId': 'a2',
            'parts': <Object?>[
              <String, Object?>{'text': 'wrapped'},
            ],
          },
        },
      });
      expect(wrapped, isA<A2AArtifactUpdateEvent>());
      expect((wrapped! as A2AArtifactUpdateEvent).contextId, 'c1');

      expect(A2AStreamEvent.fromJson(<String, Object?>{'kind': 'nope'}), isNull);
      expect(A2AStreamEvent.fromJson('text'), isNull);
      expect(
        A2AStreamEvent.fromJson(<String, Object?>{
          'kind': 'status-update',
          'taskId': 't1',
          'status': <String, Object?>{'state': 'working'},
        }),
        isA<A2AStatusUpdateEvent>(),
      );
    });
  });

  group('client', () {
    test('reads the agent card', () async {
      final (HttpServer server, _) = await _agent();
      addTearDown(() => server.close(force: true));
      final A2AClient client =
          A2AClient(baseUrl: 'http://127.0.0.1:${server.port}');
      final A2AAgentCard card = await client.getAgentCard();
      expect(card.name, 'demo-agent');
      expect(card.version, '1.2.3');
      expect(card.skills.single['id'], 'search');
    });

    test('sendMessage returns the task, then the reply', () async {
      final (HttpServer server, _) = await _agent(
        sendResult: <String, Object?>{
          'kind': 'task',
          'id': 't1',
          'contextId': 'c1',
          'status': <String, Object?>{'state': 'working'},
        },
      );
      addTearDown(() => server.close(force: true));
      final A2AClient client =
          A2AClient(baseUrl: 'http://127.0.0.1:${server.port}');
      final Object result = await client.sendMessage(
        const A2AMessage(
          messageId: 'm1',
          role: A2ARole.user,
          parts: <A2APart>[A2APart(text: 'hi')],
        ),
      );
      expect(result, isA<A2ATask>());
      expect((result as A2ATask).id, 't1');
      expect(result.status.state, A2ATaskState.working);
    });

    test('a JSON-RPC error becomes an A2AException', () async {
      final (HttpServer server, _) = await _agent(
        error: <String, Object?>{
          'code': -32602,
          'status': 'INVALID_ARGUMENT',
          'message': 'message is required',
        },
      );
      addTearDown(() => server.close(force: true));
      final A2AClient client =
          A2AClient(baseUrl: 'http://127.0.0.1:${server.port}');
      await expectLater(
        client
            .streamMessage(const A2AMessage(
              messageId: 'm1',
              role: A2ARole.user,
              parts: <A2APart>[A2APart(text: 'hi')],
            ))
            .toList(),
        throwsA(isA<A2AException>()
            .having((A2AException e) => e.code, 'code', -32602)
            .having((A2AException e) => e.message, 'message', 'message is required')),
      );
    });

    test('a non-SSE stream reply is refused with the content type', () async {
      final (HttpServer server, _) = await _agent(streamContentType: 'application/json');
      addTearDown(() => server.close(force: true));
      final A2AClient client =
          A2AClient(baseUrl: 'http://127.0.0.1:${server.port}');
      await expectLater(
        client
            .streamMessage(const A2AMessage(
              messageId: 'm1',
              role: A2ARole.user,
              parts: <A2APart>[A2APart(text: 'hi')],
            ))
            .toList(),
        throwsA(isA<A2AException>().having(
          (A2AException e) => e.message,
          'message',
          contains('text/event-stream'),
        )),
      );
    });

    test('getTask and cancelTask reach the task endpoints', () async {
      final (HttpServer server, _) = await _agent(
        taskResult: <String, Object?>{
          'id': 't1',
          'status': <String, Object?>{'state': 'completed'},
        },
      );
      addTearDown(() => server.close(force: true));
      final A2AClient client =
          A2AClient(baseUrl: 'http://127.0.0.1:${server.port}');
      expect((await client.getTask('t1')).status.state, A2ATaskState.completed);
      expect((await client.cancelTask('t1')).id, 't1');
    });
  });

  group('adapter', () {
    test('accumulates streamed artifacts into parts', () async {
      final (HttpServer server, _) = await _agent(
        streamEvents: <Map<String, Object?>>[
          _statusUpdate('submitted'),
          _statusUpdate('working'),
          _artifactUpdate('Two ', append: false, lastChunk: false),
          _artifactUpdate('hooks.', append: true, lastChunk: false),
          _artifactUpdate('', append: true),
          _statusUpdate('completed'),
        ],
      );
      addTearDown(() => server.close(force: true));

      final A2AChatModelAdapter adapter = A2AChatModelAdapter(
        client: A2AClient(baseUrl: 'http://127.0.0.1:${server.port}'),
      );
      final List<ChatModelRunResult> results = await adapter
          .run(_context(<ThreadMessage>[]))
          .toList();

      final List<MessagePart> last = results.last.content;
      expect(last.whereType<TextPart>().map((TextPart p) => p.text).join(), 'Two hooks.');
      expect(results.last.status, isA<MessageStatusComplete>());
      expect(adapter.lastTask, isNull, reason: 'no task snapshot was sent');
    });

    test('input_required parks the run', () async {
      final (HttpServer server, _) = await _agent(
        streamEvents: <Map<String, Object?>>[
          _statusUpdate('working'),
          _statusUpdate('input_required', messageText: 'Which file?'),
        ],
      );
      addTearDown(() => server.close(force: true));

      final A2AChatModelAdapter adapter = A2AChatModelAdapter(
        client: A2AClient(baseUrl: 'http://127.0.0.1:${server.port}'),
      );
      final List<ChatModelRunResult> results =
          await adapter.run(_context(<ThreadMessage>[])).toList();

      expect(results.last.status, isA<MessageStatusRequiresAction>());
      expect(
        results.last.content.whereType<TextPart>().single.text,
        'Which file?',
      );
    });

    test('a failed task throws with the agent message', () async {
      final (HttpServer server, _) = await _agent(
        streamEvents: <Map<String, Object?>>[
          _statusUpdate('working'),
          _statusUpdate('failed', messageText: 'tool crashed'),
        ],
      );
      addTearDown(() => server.close(force: true));

      final A2AChatModelAdapter adapter = A2AChatModelAdapter(
        client: A2AClient(baseUrl: 'http://127.0.0.1:${server.port}'),
      );
      await expectLater(
        adapter.run(_context(<ThreadMessage>[])).toList(),
        throwsA(isA<A2AException>()
            .having((A2AException e) => e.code, 'code', 'failed')
            .having((A2AException e) => e.message, 'message', 'tool crashed')),
      );
    });

    test('a task snapshot lands in lastTask and in the content', () async {
      final (HttpServer server, _) = await _agent(
        streamEvents: <Map<String, Object?>>[
          <String, Object?>{
            'kind': 'task',
            'id': 't9',
            'contextId': 'c9',
            'status': <String, Object?>{'state': 'working'},
            'artifacts': <Object?>[
              <String, Object?>{
                'artifactId': 'a9',
                'name': 'report',
                'parts': <Object?>[
                  <String, Object?>{'text': 'draft'},
                ],
              },
            ],
          },
          _statusUpdate('completed'),
        ],
      );
      addTearDown(() => server.close(force: true));

      final A2AChatModelAdapter adapter = A2AChatModelAdapter(
        client: A2AClient(baseUrl: 'http://127.0.0.1:${server.port}'),
      );
      final List<ChatModelRunResult> results =
          await adapter.run(_context(<ThreadMessage>[])).toList();

      expect(adapter.lastTask!.id, 't9');
      expect(adapter.lastTask!.artifacts.single.artifactId, 'a9');
      expect(
        results.last.content.whereType<TextPart>().single.text,
        'draft',
      );
      expect(results.last.status, isA<MessageStatusComplete>());
    });

    test('the last user turn travels as an A2A message', () async {
      final HttpServer server =
          await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      String body = '';
      server.listen((HttpRequest request) async {
        body = await utf8.decoder.bind(request).join();
        request.response.headers
            .set(HttpHeaders.contentTypeHeader, 'text/event-stream');
        request.response
            .write('data: ${jsonEncode(_statusUpdate('completed'))}\n\n');
        await request.response.close();
      });
      addTearDown(() => server.close(force: true));

      final A2AChatModelAdapter adapter = A2AChatModelAdapter(
        client: A2AClient(baseUrl: 'http://127.0.0.1:${server.port}'),
        contextId: 'ctx-1',
      );
      await adapter.run(_context(<ThreadMessage>[
        ThreadMessage.single(
          id: 'u1',
          role: MessageRole.user,
          createdAt: DateTime(2026, 9, 17),
          content: const <MessagePart>[TextPart('Where are the hooks?')],
        ),
      ])).toList();

      final Map<String, Object?> sent =
          jsonDecode(body) as Map<String, Object?>;
      final Map<String, Object?> message =
          sent['message']! as Map<String, Object?>;
      expect(message['messageId'], 'u1');
      expect(message['role'], 'user');
      expect(message['contextId'], 'ctx-1');
      expect(
        (message['parts']! as List<Object?>).first,
        containsPair('text', 'Where are the hooks?'),
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
            content: const <MessagePart>[TextPart('continue')],
            createdAt: DateTime(2026, 9, 17),
          )
        : messages.last,
  );
}
