import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves the handler without blocking the test body.
void unawaitedListen(
  HttpServer server,
  Future<void> Function(HttpRequest request, List<String> seen) handler,
  List<String> seen,
) {
  server.listen((HttpRequest request) async {
    await handler(request, seen);
  });
}

/// The HTTP attachment backend: what leaves the client, what the answer turns
/// into, what a host that says no looks like, and how a flaky host is handled.
void main() {
  /// A stand-in upload endpoint: records what arrived, answers what it is told.
  Future<(HttpServer, List<String>)> endpoint(
    Future<void> Function(HttpRequest request, List<String> seen) handler,
  ) async {
    final HttpServer server =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final List<String> seen = <String>[];
    unawaitedListen(server, handler, seen);
    return (server, seen);
  }

  PendingAttachment pick({
    String id = 'local',
    String filename = 'file.bin',
    String mime = 'application/octet-stream',
    int size = 3,
  }) =>
      PendingAttachment(
        id: id,
        filename: filename,
        mimeType: mime,
        data: Uint8List.fromList(List<int>.filled(size, 7)),
      );

  test('an upload posts the file and keeps the url that comes back', () async {
    final (HttpServer server, List<String> seen) = await endpoint((
      HttpRequest request,
      List<String> seen,
    ) async {
      final String body = await utf8.decoder.bind(request).join();
      seen.add('${request.method} ${request.uri.path} $body');
      request.response
        ..statusCode = 201
        ..write('{"id": "asset_7", "url": "https://cdn.example/asset_7.png"}');
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final HttpAttachmentAdapter adapter = HttpAttachmentAdapter(
      endpoint: Uri.parse('http://127.0.0.1:${server.port}/upload'),
    );
    final AttachmentAddResult result = await adapter
        .add(pick(id: 'local_1', filename: 'diagram.png', mime: 'image/png'))
        .last;

    expect(result.status, AttachmentAddStatus.complete);
    final AuiAttachment attachment = result.attachment!;
    expect(attachment, isA<ImageAttachment>());
    expect(attachment.id, 'asset_7');
    expect(
      (attachment as ImageAttachment).url,
      'https://cdn.example/asset_7.png',
    );

    // The request carried the filename and the bytes.
    expect(seen.single, contains('POST /upload'));
    expect(seen.single, contains('diagram.png'));
    expect(adapter.attachments, hasLength(1));
  });

  test('a host that refuses reports incomplete rather than a broken attachment',
      () async {
    final (HttpServer server, _) = await endpoint((
      HttpRequest request,
      List<String> seen,
    ) async {
      await utf8.decoder.bind(request).join();
      request.response.statusCode = 413;
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final HttpAttachmentAdapter adapter = HttpAttachmentAdapter(
      endpoint: Uri.parse('http://127.0.0.1:${server.port}/upload'),
    );
    final AttachmentAddResult result = await adapter.add(pick()).last;

    expect(result.status, AttachmentAddStatus.incomplete);
    expect(adapter.attachments, isEmpty);
  });

  test('a bare url answer is taken as the url', () async {
    final (HttpServer server, _) = await endpoint((
      HttpRequest request,
      List<String> seen,
    ) async {
      await utf8.decoder.bind(request).join();
      request.response.write('https://cdn.example/plain.txt');
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final HttpAttachmentAdapter adapter = HttpAttachmentAdapter(
      endpoint: Uri.parse('http://127.0.0.1:${server.port}/upload'),
    );
    final AttachmentAddResult result =
        await adapter.add(pick(mime: 'text/plain')).last;
    expect(result.attachment, isA<DocumentAttachment>());
    expect(
      (result.attachment! as DocumentAttachment).data,
      'https://cdn.example/plain.txt',
    );
  });

  test('removing asks the host to delete what it stored', () async {
    final (HttpServer server, List<String> seen) = await endpoint((
      HttpRequest request,
      List<String> seen,
    ) async {
      seen.add('${request.method} ${request.uri.path}');
      if (request.method == 'POST') {
        await utf8.decoder.bind(request).join();
        request.response.write('{"id": "asset_9", "url": "/files/asset_9"}');
      }
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final HttpAttachmentAdapter adapter = HttpAttachmentAdapter(
      endpoint: Uri.parse('http://127.0.0.1:${server.port}/upload'),
    );
    final AttachmentAddResult result =
        await adapter.add(pick(mime: 'text/plain')).last;
    await adapter.remove(result.attachment!);

    expect(seen, contains('POST /upload'));
    // The id hangs off the collection, not off the endpoint's last segment.
    expect(seen, contains('DELETE /upload/asset_9'));
    expect(adapter.attachments, isEmpty);
  });

  test('progress reports real bytes, not a timer', () async {
    final (HttpServer server, _) = await endpoint((
      HttpRequest request,
      List<String> seen,
    ) async {
      await utf8.decoder.bind(request).join();
      request.response.write('{"url": "/files/a"}');
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final List<String> steps = <String>[];
    final HttpAttachmentAdapter adapter = HttpAttachmentAdapter(
      endpoint: Uri.parse('http://127.0.0.1:${server.port}/upload'),
      onProgress: (int sent, int total) => steps.add('$sent/$total'),
    );

    await adapter.add(pick(id: 'big', size: 20000)).last;

    expect(steps, isNotEmpty);
    final List<int> sent = steps
        .map((String step) => int.parse(step.split('/').first))
        .toList();
    for (int i = 1; i < sent.length; i++) {
      expect(sent[i], greaterThanOrEqualTo(sent[i - 1]));
    }
    // The last report is the whole body.
    expect(steps.last.split('/').first, steps.last.split('/').last);
  });

  test('a transient failure is retried, a refusal is not', () async {
    int attempts = 0;
    final (HttpServer server, _) = await endpoint((
      HttpRequest request,
      List<String> seen,
    ) async {
      await utf8.decoder.bind(request).join();
      attempts++;
      request.response.statusCode = attempts <= 2 ? 503 : 200;
      if (attempts > 2) request.response.write('{"url": "/files/ok"}');
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final HttpAttachmentAdapter adapter = HttpAttachmentAdapter(
      endpoint: Uri.parse('http://127.0.0.1:${server.port}/upload'),
      retries: 3,
      retryDelay: const Duration(milliseconds: 10),
    );
    final AttachmentAddResult result = await adapter.add(pick()).last;
    expect(attempts, 3);
    expect(result.status, AttachmentAddStatus.complete);

    int refusals = 0;
    final (HttpServer second, _) = await endpoint((
      HttpRequest request,
      List<String> seen,
    ) async {
      await utf8.decoder.bind(request).join();
      refusals++;
      request.response.statusCode = 403;
      await request.response.close();
    });
    addTearDown(() => second.close(force: true));
    final HttpAttachmentAdapter refusing = HttpAttachmentAdapter(
      endpoint: Uri.parse('http://127.0.0.1:${second.port}/upload'),
      retries: 3,
      retryDelay: const Duration(milliseconds: 10),
    );
    final AttachmentAddResult refused = await refusing.add(pick()).last;
    // A 4xx is the host saying no: one attempt, no retries.
    expect(refusals, 1);
    expect(refused.status, AttachmentAddStatus.incomplete);
  });
}
