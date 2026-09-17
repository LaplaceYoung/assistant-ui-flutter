import 'dart:convert';
import 'dart:io';

import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// A scripted ADK server: session creation and a `/run_sse` stream.
Future<(HttpServer, List<String>)> _server({
  List<Map<String, Object?>> events = const <Map<String, Object?>>[],
  int runStatus = 200,
  String? runContentType,
  String? rawEventLine,
  int sessionStatus = 200,
}) async {
  final HttpServer server =
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final List<String> seen = <String>[];
  server.listen((HttpRequest request) async {
    final String body = await utf8.decoder.bind(request).join();
    seen.add('${request.method} ${request.uri.path} $body');
    if (request.uri.path == '/run_sse') {
      request.response.statusCode = runStatus;
      if (runStatus >= 400) {
        request.response.write('{"detail": "run failed"}');
      } else {
        request.response.headers.set(
          HttpHeaders.contentTypeHeader,
          runContentType ?? 'text/event-stream',
        );
        if (rawEventLine != null) {
          request.response.write('data: $rawEventLine\n\n');
        }
        for (final Map<String, Object?> event in events) {
          request.response.write('data: ${jsonEncode(event)}\n\n');
          await request.response.flush();
        }
      }
    } else {
      request.response.statusCode = sessionStatus;
      request.response.headers
          .set(HttpHeaders.contentTypeHeader, 'application/json');
      request.response.write(jsonEncode(<String, Object?>{'id': 'session-1'}));
    }
    await request.response.close();
  });
  return (server, seen);
}

Map<String, Object?> _textEvent(
  String text, {
  bool partial = false,
  bool turnComplete = false,
  String author = 'agent',
}) =>
    <String, Object?>{
      'author': author,
      'partial': partial,
      'turnComplete': turnComplete,
      'content': <String, Object?>{
        'role': 'model',
        'parts': <Object?>[
          <String, Object?>{'text': text},
        ],
      },
    };

void main() {
  group('events', () {
    test('normalizes snake_case and camelCase', () {
      final AdkEvent snake = AdkEvent.fromJson(<String, Object?>{
        'author': 'agent',
        'turn_complete': true,
        'long_running_tool_ids': <Object?>['t1'],
        'content': <String, Object?>{
          'parts': <Object?>[
            <String, Object?>{'text': 'hi'},
          ],
        },
      });
      expect(snake.turnComplete, isTrue);
      expect(snake.longRunningToolIds, <String>['t1']);
      expect(snake.parts.single['text'], 'hi');

      final AdkEvent camel = AdkEvent.fromJson(<String, Object?>{
        'turnComplete': false,
        'longRunningToolIds': <Object?>['t2'],
        'partial': true,
      });
      expect(camel.partial, isTrue);
      expect(camel.longRunningToolIds, <String>['t2']);
      expect(camel.parts, isEmpty);
    });
  });

  group('accumulator', () {
    test('a final event replaces the streamed partial text', () {
      final AdkEventAccumulator accumulator = AdkEventAccumulator()
        ..add(AdkEvent.fromJson(_textEvent('The ')))
        ..add(AdkEvent.fromJson(_textEvent('The answer', partial: true)))
        ..add(AdkEvent.fromJson(_textEvent('The answer.', turnComplete: true)));

      expect(
        accumulator.parts.whereType<TextPart>().single.text,
        'The answer.',
      );
      expect(accumulator.turnComplete, isTrue);
    });

    test('a second turn appends instead of replacing', () {
      final AdkEventAccumulator accumulator = AdkEventAccumulator()
        ..add(AdkEvent.fromJson(_textEvent('first', turnComplete: true)))
        ..add(AdkEvent.fromJson(_textEvent('second', turnComplete: true)));
      expect(
        accumulator.parts.whereType<TextPart>().map((TextPart p) => p.text).toList(),
        <String>['first', 'second'],
      );
    });

    test('function calls and responses pair up', () {
      final AdkEventAccumulator accumulator = AdkEventAccumulator()
        ..add(AdkEvent.fromJson(<String, Object?>{
          'author': 'agent',
          'content': <String, Object?>{
            'parts': <Object?>[
              <String, Object?>{
                'functionCall': <String, Object?>{
                  'id': 'c1',
                  'name': 'get_weather',
                  'args': <String, Object?>{'city': 'Tokyo'},
                },
              },
            ],
          },
        }))
        ..add(AdkEvent.fromJson(<String, Object?>{
          'author': 'agent',
          'content': <String, Object?>{
            'parts': <Object?>[
              <String, Object?>{
                'functionResponse': <String, Object?>{
                  'id': 'c1',
                  'name': 'get_weather',
                  'response': <String, Object?>{'tempC': 21},
                },
              },
            ],
          },
        }));

      final ToolCallPart call = accumulator.parts.whereType<ToolCallPart>().single;
      expect(call.toolName, 'get_weather');
      expect(call.args, <String, Object?>{'city': 'Tokyo'});
      expect(call.result, contains('21'));
      expect(call.status, PartStatus.complete);
    });

    test('an error response marks the call failed', () {
      final AdkEventAccumulator accumulator = AdkEventAccumulator()
        ..add(AdkEvent.fromJson(<String, Object?>{
          'content': <String, Object?>{
            'parts': <Object?>[
              <String, Object?>{
                'functionCall': <String, Object?>{
                  'id': 'c2',
                  'name': 'delete_file',
                  'args': <String, Object?>{},
                },
              },
            ],
          },
        }))
        ..add(AdkEvent.fromJson(<String, Object?>{
          'content': <String, Object?>{
            'parts': <Object?>[
              <String, Object?>{
                'functionResponse': <String, Object?>{
                  'id': 'c2',
                  'name': 'delete_file',
                  'response': <String, Object?>{'error': 'permission denied'},
                },
              },
            ],
          },
        }));

      expect(
        accumulator.parts.whereType<ToolCallPart>().single.status,
        PartStatus.incomplete,
      );
    });

    test('state and artifact deltas accumulate', () {
      final AdkEventAccumulator accumulator = AdkEventAccumulator()
        ..add(AdkEvent.fromJson(<String, Object?>{
          'actions': <String, Object?>{
            'stateDelta': <String, Object?>{'plan': 'draft'},
            'artifactDelta': <String, Object?>{'report.txt': 2},
          },
        }))
        ..add(AdkEvent.fromJson(<String, Object?>{
          'actions': <String, Object?>{
            'state_delta': <String, Object?>{'step': 3},
          },
        }));
      expect(accumulator.state, <String, Object?>{'plan': 'draft', 'step': 3});
      expect(accumulator.artifacts['report.txt'], 2);
    });

    test('long-running ids and interrupts park the run', () {
      final AdkEventAccumulator accumulator = AdkEventAccumulator()
        ..add(AdkEvent.fromJson(<String, Object?>{
          'longRunningToolIds': <Object?>['t1', 't1'],
        }))
        ..add(AdkEvent.fromJson(<String, Object?>{'interrupted': true}));
      expect(accumulator.pendingLongRunningToolIds, <String>['t1']);
      expect(accumulator.interrupted, isTrue);
    });
  });

  group('content', () {
    test('parts become ADK content', () {
      final Map<String, Object?> content = adkContentFromParts(
        const <MessagePart>[
          TextPart('hello'),
          ImagePart(image: 'https://x/y.png', filename: 'y.png'),
          FilePart(data: 'https://x/z.pdf', mimeType: 'application/pdf'),
        ],
      );
      expect(content['role'], 'user');
      final List<Object?> parts = content['parts']! as List<Object?>;
      expect(parts.length, 3);
      expect(parts[0], containsPair('text', 'hello'));
      expect(
        (parts[1]! as Map<String, Object?>)['fileData'],
        containsPair('fileUri', 'https://x/y.png'),
      );
    });

    test('ADK parts become content', () {
      final List<MessagePart> parts = adkPartsToContent(<Map<String, Object?>>[
        <String, Object?>{'text': 'hi'},
        <String, Object?>{
          'functionCall': <String, Object?>{'id': 'c1', 'name': 'search'},
        },
      ]);
      expect(parts.whereType<TextPart>().single.text, 'hi');
      expect(parts.whereType<ToolCallPart>().single.toolCallId, 'c1');
    });
  });

  group('confirmations, auth and transfer', () {
    Map<String, Object?> confirmationEvent({String id = 'conf-1'}) =>
        <String, Object?>{
          'author': 'agent',
          'content': <String, Object?>{
            'parts': <Object?>[
              <String, Object?>{
                'functionCall': <String, Object?>{
                  'id': id,
                  'name': adkRequestConfirmation,
                  'args': <String, Object?>{
                    'originalFunctionCall': <String, Object?>{
                      'id': 'gated-1',
                      'name': 'delete_file',
                      'args': <String, Object?>{'path': 'build/'},
                    },
                  },
                },
              },
            ],
          },
        };

    test('a confirmation call opens a gate naming the gated tool', () {
      final AdkEventAccumulator accumulator = AdkEventAccumulator()
        ..add(AdkEvent.fromJson(confirmationEvent()));

      final AdkToolConfirmation gate = accumulator.pendingConfirmations.single;
      expect(gate.approvalId, 'conf-1');
      expect(gate.gatedCallId, 'gated-1');
      expect(gate.toolName, 'delete_file');
      expect(gate.approved, isNull);
      // The synthetic call is still a part, so a UI can render the request.
      final ToolCallPart call = accumulator.parts.whereType<ToolCallPart>().single;
      expect(call.toolName, adkRequestConfirmation);

      accumulator.answerConfirmation('conf-1', true);
      expect(accumulator.pendingConfirmations, isEmpty);
      expect(accumulator.confirmations['conf-1']!.approved, isTrue);
      // Answering twice does not flip a settled gate.
      accumulator.answerConfirmation('conf-1', false);
      expect(accumulator.confirmations['conf-1']!.approved, isTrue);
    });

    test('the reply message quotes the synthetic id', () {
      final Map<String, Object?> reply = adkConfirmationReply('conf-1', false);
      expect(reply['type'], 'tool');
      expect(reply['tool_call_id'], 'conf-1');
      expect(reply['name'], adkRequestConfirmation);
      expect(
        (reply['content']! as Map<String, Object?>)['confirmed'],
        isFalse,
      );
      expect(adkConfirmationTarget(reply), 'conf-1');
      expect(adkConfirmationDecision(reply['content']), isFalse);
    });

    test('decisions read through the nesting ADK uses', () {
      expect(adkConfirmationDecision('{"confirmed": true}'), isTrue);
      expect(
        adkConfirmationDecision(
          '{"response": "{\\"confirmed\\": false}"}',
        ),
        isNull,
      );
      expect(
        adkConfirmationDecision(<String, Object?>{'confirmed': false}),
        isFalse,
      );
      expect(adkConfirmationDecision('not json'), isNull);
      expect(adkConfirmationDecision(null), isNull);
    });

    test('a transcript projects open and answered gates', () {
      final Map<String, AdkToolConfirmation> approvals =
          projectAdkToolConfirmations(<Map<String, Object?>>[
        <String, Object?>{
          'type': 'ai',
          'tool_calls': <Object?>[
            <String, Object?>{
              'id': 'conf-9',
              'name': adkRequestConfirmation,
              'args': <String, Object?>{
                'original_function_call': <String, Object?>{
                  'id': 'gated-9',
                  'name': 'send_email',
                },
              },
            },
          ],
        },
        adkConfirmationReply('conf-9', true),
      ]);
      expect(approvals['conf-9']!.toolName, 'send_email');
      expect(approvals['conf-9']!.gatedCallId, 'gated-9');
      expect(approvals['conf-9']!.approved, isTrue);
    });

    test('auth requests, transfer and escalation are tracked', () {
      final AdkEventAccumulator accumulator = AdkEventAccumulator()
        ..add(AdkEvent.fromJson(<String, Object?>{
          'author': 'agent',
          'actions': <String, Object?>{
            'transferToAgent': 'planner',
            'escalate': true,
            'requestedAuthConfigs': <String, Object?>{
              'tc-1': <String, Object?>{'provider': 'google'},
            },
          },
        }));
      expect(accumulator.transferToAgent, 'planner');
      expect(accumulator.escalated, isTrue);
      expect(accumulator.authRequests.single.toolCallId, 'tc-1');
      expect(
        (accumulator.authRequests.single.authConfig! as Map<String, Object?>)['provider'],
        'google',
      );
    });

    test('a confirmation parks the adapter run', () async {
      final (HttpServer server, _) = await _server(
        events: <Map<String, Object?>>[confirmationEvent()],
      );
      addTearDown(() => server.close(force: true));

      final AdkChatModelAdapter adapter = AdkChatModelAdapter(
        client: AdkClient(
          api: 'http://127.0.0.1:${server.port}',
          appName: 'app',
          userId: 'user-1',
        ),
      );
      final List<ChatModelRunResult> results =
          await adapter.run(_context(<ThreadMessage>[])).toList();

      expect(results.last.status, isA<MessageStatusRequiresAction>());
      expect(adapter.lastAccumulator!.pendingConfirmations.single.gatedCallId, 'gated-1');
    });
  });

  group('client and adapter', () {
    test('creates a session and streams a turn into parts', () async {
      final (HttpServer server, List<String> seen) = await _server(
        events: <Map<String, Object?>>[
          _textEvent('The '),
          _textEvent('The answer', partial: true),
          _textEvent('The answer.', turnComplete: true),
        ],
      );
      addTearDown(() => server.close(force: true));

      final AdkChatModelAdapter adapter = AdkChatModelAdapter(
        client: AdkClient(
          api: 'http://127.0.0.1:${server.port}',
          appName: 'app',
          userId: 'user-1',
        ),
      );
      final List<ChatModelRunResult> results = await adapter
          .run(_context(<ThreadMessage>[]))
          .toList();

      expect(
        results.last.content.whereType<TextPart>().single.text,
        'The answer.',
      );
      expect(results.last.status, isA<MessageStatusComplete>());
      expect(seen.first, contains('/apps/app/users/user-1/sessions/'));
      expect(seen.last, contains('"appName":"app"'));
      expect(seen.last, contains('"streaming":true'));
      expect(adapter.lastAccumulator!.turnComplete, isTrue);
    });

    test('a long-running tool id parks the run', () async {
      final (HttpServer server, _) = await _server(
        events: <Map<String, Object?>>[
          <String, Object?>{
            'author': 'agent',
            'longRunningToolIds': <Object?>['t9'],
            'content': <String, Object?>{
              'parts': <Object?>[
                <String, Object?>{
                  'functionCall': <String, Object?>{
                    'id': 't9',
                    'name': 'deploy',
                    'args': <String, Object?>{'env': 'prod'},
                  },
                },
              ],
            },
          },
        ],
      );
      addTearDown(() => server.close(force: true));

      final AdkChatModelAdapter adapter = AdkChatModelAdapter(
        client: AdkClient(
          api: 'http://127.0.0.1:${server.port}',
          appName: 'app',
          userId: 'user-1',
        ),
      );
      final List<ChatModelRunResult> results =
          await adapter.run(_context(<ThreadMessage>[])).toList();

      expect(results.last.status, isA<MessageStatusRequiresAction>());
      expect(results.last.content.whereType<ToolCallPart>().single.toolName, 'deploy');
      expect(adapter.lastAccumulator!.pendingLongRunningToolIds, <String>['t9']);
    });

    test('a non-SSE reply is refused with the content type', () async {
      final (HttpServer server, _) = await _server(runContentType: 'application/json');
      addTearDown(() => server.close(force: true));

      final AdkChatModelAdapter adapter = AdkChatModelAdapter(
        client: AdkClient(
          api: 'http://127.0.0.1:${server.port}',
          appName: 'app',
          userId: 'user-1',
        ),
      );
      await expectLater(
        adapter.run(_context(<ThreadMessage>[])).toList(),
        throwsA(isA<AdkException>().having(
          (AdkException e) => e.message,
          'message',
          allOf(contains('text/event-stream'), contains('application/json')),
        )),
      );
    });

    test('an HTTP failure is reported', () async {
      final (HttpServer server, _) = await _server(runStatus: 500);
      addTearDown(() => server.close(force: true));

      final AdkChatModelAdapter adapter = AdkChatModelAdapter(
        client: AdkClient(
          api: 'http://127.0.0.1:${server.port}',
          appName: 'app',
          userId: 'user-1',
        ),
      );
      await expectLater(
        adapter.run(_context(<ThreadMessage>[])).toList(),
        throwsA(isA<AdkException>().having(
          (AdkException e) => e.message,
          'message',
          allOf(contains('500'), contains('run failed')),
        )),
      );
    });

    test('a malformed event frame fails loudly', () async {
      final (HttpServer server, _) = await _server(rawEventLine: 'not json');
      addTearDown(() => server.close(force: true));

      final AdkChatModelAdapter adapter = AdkChatModelAdapter(
        client: AdkClient(
          api: 'http://127.0.0.1:${server.port}',
          appName: 'app',
          userId: 'user-1',
        ),
      );
      await expectLater(
        adapter.run(_context(<ThreadMessage>[])).toList(),
        throwsA(isA<AdkException>().having(
          (AdkException e) => e.message,
          'message',
          contains('Invalid ADK stream event'),
        )),
      );
    });

    test('the new message carries the last user turn', () async {
      final (HttpServer server, List<String> seen) = await _server(
        events: <Map<String, Object?>>[_textEvent('ok', turnComplete: true)],
      );
      addTearDown(() => server.close(force: true));

      final AdkChatModelAdapter adapter = AdkChatModelAdapter(
        client: AdkClient(
          api: 'http://127.0.0.1:${server.port}',
          appName: 'app',
          userId: 'user-1',
        ),
      );
      await adapter.run(_context(<ThreadMessage>[
        ThreadMessage.single(
          id: 'u1',
          role: MessageRole.user,
          createdAt: DateTime(2026, 9, 17),
          content: const <MessagePart>[TextPart('Where are the hooks?')],
        ),
      ])).toList();

      expect(seen.last, contains('"newMessage":{"role":"user"'));
      expect(seen.last, contains('Where are the hooks?'));
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
