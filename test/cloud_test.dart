import 'dart:convert';
import 'dart:io';

import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// A scripted cloud API: threads CRUD and thread messages.
Future<(HttpServer, List<String>)> _api({
  Map<String, Object?>? listReply,
  Map<String, Object?>? createReply,
  Object? messagesReply,
  int status = 200,
  Map<String, Object?>? errorBody,
}) async {
  final HttpServer server =
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final List<String> seen = <String>[];
  server.listen((HttpRequest request) async {
    final String body = await utf8.decoder.bind(request).join();
    seen.add(
      '${request.method} ${request.uri.path}${request.uri.query.isEmpty ? '' : '?${request.uri.query}'} '
      'auth=${request.headers.value('authorization')} $body',
    );
    request.response.statusCode = status;
    request.response.headers
        .set(HttpHeaders.contentTypeHeader, 'application/json');
    if (status >= 400) {
      request.response.write(jsonEncode(errorBody ?? <String, Object?>{
        'error': <String, Object?>{'message': 'nope'},
      }));
    } else if (request.uri.path.endsWith('/messages')) {
      if (request.method == 'GET') {
        request.response.write(jsonEncode(messagesReply ?? <String, Object?>{
          'messages': <Object?>[],
        }));
      } else {
        request.response.write(jsonEncode(<String, Object?>{'id': 'm-new'}));
      }
    } else if (request.method == 'POST') {
      request.response.write(jsonEncode(createReply ?? <String, Object?>{
        'thread_id': 't-new',
      }));
    } else if (request.method == 'GET') {
      request.response.write(jsonEncode(listReply ?? <String, Object?>{
        'threads': <Object?>[],
      }));
    } else {
      request.response.write('{}');
    }
    await request.response.close();
  });
  return (server, seen);
}

CloudClient _client(HttpServer server, {String? token = 'tok-1'}) => CloudClient(
      baseUrl: 'http://127.0.0.1:${server.port}/v1',
      token: token == null ? null : () => token,
      projectId: 'proj-1',
    );

void main() {
  test('lists threads with query parameters and auth', () async {
    final (HttpServer server, List<String> seen) = await _api(
      listReply: <String, Object?>{
        'threads': <Object?>[
          <String, Object?>{
            'id': 't1',
            'title': 'Release notes',
            'external_id': 'ext-1',
            'is_archived': false,
            'last_message_at': '2026-09-17T10:00:00Z',
            'created_at': 1794900000,
          },
        ],
        'next_cursor': 'c2',
      },
    );
    addTearDown(() => server.close(force: true));

    final CloudThreadPage page = await _client(server)
        .listThreads(isArchived: false, limit: 20, after: 'c1');

    expect(page.threads.single.id, 't1');
    expect(page.threads.single.title, 'Release notes');
    expect(page.threads.single.externalId, 'ext-1');
    expect(page.threads.single.lastMessageAt, DateTime.utc(2026, 9, 17, 10));
    // Epoch seconds are read as well as ISO strings.
    expect(
      page.threads.single.createdAt,
      DateTime.fromMillisecondsSinceEpoch(1794900000 * 1000, isUtc: true),
    );
    expect(page.nextCursor, 'c2');
    expect(seen.single, contains('is_archived=false'));
    expect(seen.single, contains('limit=20'));
    expect(seen.single, contains('after=c1'));
    expect(seen.single, contains('auth=Bearer tok-1'));
    expect(seen.single, contains('/v1/projects/proj-1/threads'));
  });

  test('creates, updates and deletes a thread', () async {
    final (HttpServer server, List<String> seen) = await _api();
    addTearDown(() => server.close(force: true));
    final CloudClient client = _client(server);

    expect(
      await client.createThread(
        title: 'New',
        externalId: 'ext-9',
        metadata: <String, Object?>{'source': 'test'},
      ),
      't-new',
    );
    await client.updateThread('t-new', title: 'Renamed', isArchived: true);
    await client.deleteThread('t-new');

    expect(seen[0], contains('POST /v1/projects/proj-1/threads'));
    expect(seen[0], contains('"external_id":"ext-9"'));
    expect(seen[0], contains('"last_message_at"'));
    expect(seen[1], contains('PATCH /v1/projects/proj-1/threads/t-new'));
    expect(seen[1], contains('"is_archived":true'));
    expect(seen[2], contains('DELETE /v1/projects/proj-1/threads/t-new'));
  });

  test('reads and appends thread messages', () async {
    final (HttpServer server, List<String> seen) = await _api(
      messagesReply: <String, Object?>{
        'messages': <Object?>[
          <String, Object?>{'id': 'm1', 'role': 'user', 'content': 'hi'},
        ],
      },
    );
    addTearDown(() => server.close(force: true));
    final CloudClient client = _client(server);

    final List<Map<String, Object?>> messages =
        await client.listMessages('t1', format: 'aui/v0');
    expect(messages.single['id'], 'm1');
    expect(seen.last, contains('format=aui%2Fv0'));

    final Map<String, Object?> appended = await client.appendMessage(
      't1',
      <String, Object?>{'role': 'user', 'content': 'hello'},
    );
    expect(appended['id'], 'm-new');
    expect(seen.last, contains('"message"'));
  });

  test('an API error surfaces the server message', () async {
    final (HttpServer server, _) = await _api(status: 403);
    addTearDown(() => server.close(force: true));
    await expectLater(
      _client(server).listThreads(),
      throwsA(isA<CloudException>()
          .having((CloudException e) => e.status, 'status', 403)
          .having((CloudException e) => e.message, 'message', 'nope')),
    );
  });

  test('a body without a thread id is refused', () async {
    final (HttpServer server, _) = await _api(createReply: <String, Object?>{});
    addTearDown(() => server.close(force: true));
    await expectLater(
      _client(server).createThread(),
      throwsA(isA<CloudException>().having(
        (CloudException e) => e.message,
        'message',
        contains('thread_id'),
      )),
    );
  });

  test('no token means no authorization header', () async {
    final (HttpServer server, List<String> seen) = await _api();
    addTearDown(() => server.close(force: true));
    await _client(server, token: null).listThreads();
    expect(seen.single, contains('auth=null'));
  });
}
