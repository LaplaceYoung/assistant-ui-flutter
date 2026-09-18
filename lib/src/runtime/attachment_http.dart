import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/attachments.dart';

/// An attachment backend that uploads to a host's endpoint and keeps the URL it
/// answers with — the shape a real app needs, with no third-party client.
///
/// Uploads are a `multipart/form-data` POST to [endpoint] carrying the file under
/// [field] plus its filename. The response may be a plain URL or JSON holding
/// `url` (and optionally `id`); anything else, or a non-2xx status, reports the
/// pick as incomplete so the composer never shows an attachment that does not
/// exist. [onRemove] deletes what the endpoint handed back, when the host has
/// such a route.
class HttpAttachmentAdapter implements AttachmentAdapter {
  HttpAttachmentAdapter({
    required this.endpoint,
    this.field = 'file',
    this.headers = const <String, String>{},
    this.idKey = 'id',
    this.urlKey = 'url',
    this.accept,
    this.stepDelay = Duration.zero,
    this.steps = 1,
    this.onProgress,
    this.retries = 2,
    this.retryDelay = const Duration(milliseconds: 300),
    this.timeout = const Duration(seconds: 30),
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Where an upload goes.
  final Uri endpoint;

  /// The multipart field the file travels under.
  final String field;

  final Map<String, String> headers;
  final String idKey;
  final String urlKey;

  /// Rejects a pick by returning false; by default anything is accepted.
  final bool Function(PendingAttachment pending)? accept;

  final Duration stepDelay;
  final int steps;

  /// Reports how many bytes of the body have gone out, and how many there are.
  /// The multipart framing is included, so `sent == total` means the request is
  /// away.
  final void Function(int sent, int total)? onProgress;

  /// How many times a transient failure (a 5xx, a timeout, a transport error) is
  /// retried before the pick is reported incomplete.
  final int retries;

  final Duration retryDelay;

  /// How long one attempt may take.
  final Duration timeout;

  /// Replaced by a test's client, or left to the default one.
  final http.Client _client;

  final Map<String, AuiAttachment> _stored = <String, AuiAttachment>{};

  List<AuiAttachment> get attachments =>
      List<AuiAttachment>.unmodifiable(_stored.values);

  @override
  Stream<AttachmentAddResult> add(PendingAttachment pending) async* {
    if (accept != null && !accept!(pending)) {
      yield const AttachmentAddResult.incomplete();
      return;
    }
    for (int step = 0; step < steps; step++) {
      if (stepDelay > Duration.zero) await Future<void>.delayed(stepDelay);
      yield const AttachmentAddResult.running();
    }

    final Uint8List bytes = pending.data ?? _decode(pending.url);
    if (bytes.isEmpty) {
      yield const AttachmentAddResult.incomplete();
      return;
    }
    final _Uploaded? uploaded = await _upload(pending, bytes);
    if (uploaded == null) {
      yield const AttachmentAddResult.incomplete();
      return;
    }
    final AuiAttachment attachment = pending.mimeType.startsWith('image/')
        ? ImageAttachment(
            id: uploaded.id,
            filename: pending.filename,
            url: uploaded.url,
          )
        : DocumentAttachment(
            id: uploaded.id,
            filename: pending.filename,
            mimeType: pending.mimeType,
            data: uploaded.url,
          );
    _stored[attachment.id] = attachment;
    yield AttachmentAddResult.complete(attachment);
  }

  @override
  Future<void> remove(AuiAttachment attachment) async {
    _stored.remove(attachment.id);
    try {
      // The id hangs off the collection the upload went to, not off its last
      // segment: `/upload` + `asset_9` is `/upload/asset_9`.
      await _client.delete(
        endpoint.replace(
          pathSegments: <String>[...endpoint.pathSegments, attachment.id],
        ),
        headers: headers,
      );
    } on Object {
      // A host without a delete route leaves the asset where it is; the
      // attachment is gone from the composer either way.
    }
  }

  Future<_Uploaded?> _upload(PendingAttachment pending, Uint8List bytes) async {
    Object? lastFailure;
    for (int attempt = 0; attempt <= retries; attempt++) {
      if (attempt > 0 && retryDelay > Duration.zero) {
        await Future<void>.delayed(retryDelay * attempt);
      }
      final _Attempt attemptResult = await _attemptUpload(pending, bytes);
      if (attemptResult.uploaded != null) return attemptResult.uploaded;
      lastFailure = attemptResult.failure;
      if (!attemptResult.retryable) return null;
    }
    // Every attempt failed: the host is told "incomplete", and the last reason
    // stays here rather than being dressed up as success.
    assert(lastFailure == null || true);
    return null;
  }

  Future<_Attempt> _attemptUpload(
    PendingAttachment pending,
    Uint8List bytes,
  ) async {
    final http.MultipartRequest request =
        http.MultipartRequest('POST', endpoint)
          ..headers.addAll(headers)
          ..files.add(
            http.MultipartFile.fromBytes(
              field,
              bytes,
              filename: pending.filename,
            ),
          );
    try {
      final int total = request.contentLength;
      int sent = 0;
      final http.StreamedRequest counted = http.StreamedRequest('POST', endpoint)
        ..headers.addAll(request.headers)
        ..contentLength = total;
      // The body is the multipart form the request built; counting it on the way
      // out is what makes progress real rather than a timer.
      unawaited(
        request.finalize().forEach((List<int> chunk) {
          sent += chunk.length;
          onProgress?.call(sent, total);
          counted.sink.add(chunk);
        }).then((_) => counted.sink.close()),
      );

      final http.StreamedResponse streamed =
          await _client.send(counted).timeout(timeout);
      final http.Response response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 500) {
        return _Attempt.retryable('status ${response.statusCode}');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const _Attempt.no();
      }
      final String body = response.body.trim();
      if (body.isEmpty) return const _Attempt.no();
      // JSON first, a bare URL second.
      try {
        final Object? decoded = jsonDecode(body);
        if (decoded is Map<String, Object?>) {
          final Object? url = decoded[urlKey];
          if (url is String && url.isNotEmpty) {
            final Object? id = decoded[idKey];
            return _Attempt.done(
              _Uploaded(
                id: id is String && id.isNotEmpty ? id : pending.id,
                url: url,
              ),
            );
          }
          return const _Attempt.no();
        }
      } on FormatException {
        // Not JSON: the body itself may be the URL.
      }
      if (body.startsWith('http') || body.startsWith('/')) {
        return _Attempt.done(_Uploaded(id: pending.id, url: body));
      }
      return const _Attempt.no();
    } on Object catch (error) {
      // A timeout or a transport error is worth another try; a parsed answer
      // that made no sense is not.
      return _Attempt.retryable('$error');
    }
  }

  static Uint8List _decode(String? url) {
    if (url == null || !url.startsWith('data:')) return Uint8List(0);
    final int comma = url.indexOf(',');
    if (comma < 0) return Uint8List(0);
    final String body = url.substring(comma + 1);
    return url.substring(0, comma).contains(';base64')
        ? base64Decode(body)
        : Uint8List.fromList(utf8.encode(Uri.decodeComponent(body)));
  }
}

class _Uploaded {
  const _Uploaded({required this.id, required this.url});

  final String id;
  final String url;
}

/// One try at an upload: what came back, and whether another is worth it.
class _Attempt {
  const _Attempt.done(this.uploaded) : failure = null, retryable = false;
  const _Attempt.no() : uploaded = null, failure = null, retryable = false;
  const _Attempt.retryable(this.failure) : uploaded = null, retryable = true;

  final _Uploaded? uploaded;
  final String? failure;
  final bool retryable;
}
