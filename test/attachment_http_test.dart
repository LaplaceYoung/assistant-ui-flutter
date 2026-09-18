import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// The HTTP attachment backend: what leaves the client, what the answer turns
/// into, and what a host that says no looks like.
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
        .add(
          PendingAttachment(
            id: 'local_1',
            filename: 'diagram.png',
            mimeType: 'image/png',
            data: Uint8List.fromList(<int>[1, 2, 3]),
          ),
        )
        .last;

    expect(result.status, AttachmentAddStatus.complete);
    final AuiAttachment attachment = result.attachment!;
    expect(attachment, isA<ImageAttachment>());
    expect(attachment.id, 'asset_7');
    expect((attachment as ImageAttachment).url, 'https://cdn.example/asset_7.png');

    // The request carried the filename and the bytes.
    expect(seen.single, contains('POST /upload'));
    expect(seen.single, contains('diagram.png'));
    expect(adapter.attachments, hasLength(1));
  });

  test('a host that refuses reports incomplete rather than a broken attachment', () async {
    final (HttpServer server, _) = await endpoint((
      HttpRequest request,
      List<String> seen,
    ) async {
      request.response.statusCode = 413;
      await request.response.close();
    });
    addTearDown(() => server.close(force: true));

    final HttpAttachmentAdapter adapter = HttpAttachmentAdapter(
      endpoint: Uri.parse('http://127.0.0.1:${server.port}/upload'),
    );
    final AttachmentAddResult result = await adapter
        .add(
          PendingAttachment(
            id: 'x',
            filename: 'big.bin',
            mimeType: 'application/octet-stream',
            data: Uint8List.fromList(<int>[9]),
          ),
        )
        .last;

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
    final AttachmentAddResult result = await adapter
        .add(
          PendingAttachment(
            id: 'p',
            filename: 'plain.txt',
            mimeType: 'text/plain',
            data: Uint8List.fromList(<int>[104, 105]),
          ),
        )
        .last;
    expect(result.attachment, isA<DocumentAttachment>());
    expect((result.attachment! as DocumentAttachment).data,
        'https://cdn.example/plain.txt');
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
    final AttachmentAddResult result = await adapter
        .add(
          PendingAttachment(
            id: 'local',
            filename: 'a.txt',
            mimeType: 'text/plain',
            data: Uint8List.fromList(<int>[1]),
          ),
        )
        .last;
    await adapter.remove(result.attachment!);

    expect(seen, contains('POST /upload'));
    // The delete goes to the endpoint resolved against the id the host gave.
    expect(seen, contains('DELETE /upload/asset_9'));
    expect(adapter.attachments, isEmpty);
  });
}

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
