import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../core/attachments.dart';
import '../core/message_part.dart';
import 'defaults_stub.dart'
    if (dart.library.io) 'defaults_io.dart' as platform;

/// The port's default attachment backend: it keeps what the user picked in
/// memory and hands back an attachment the moment the "upload" finishes.
///
/// Upstream leaves storage to the app through [AttachmentAdapter]; this is the
/// one that works with no backend at all, so the attachment element is usable
/// out of the box and a host replaces it when it has somewhere to put files.
class InMemoryAttachmentAdapter implements AttachmentAdapter {
  InMemoryAttachmentAdapter({
    this.accept,
    this.stepDelay = const Duration(milliseconds: 120),
    this.steps = 3,
  });

  /// Rejects a pick by returning false; by default anything is accepted.
  final bool Function(PendingAttachment pending)? accept;

  /// How long each progress step takes; zero completes on the next microtask,
  /// which is what tests want.
  final Duration stepDelay;

  /// How many progress steps a pick reports before it resolves.
  final int steps;

  final Map<String, AuiAttachment> _stored = <String, AuiAttachment>{};
  final Map<String, Uint8List> _payloads = <String, Uint8List>{};

  /// Everything that finished uploading, newest last.
  List<AuiAttachment> get attachments =>
      List<AuiAttachment>.unmodifiable(_stored.values);

  /// The payload an attachment carries, as it was picked.
  Uint8List? payloadOf(String id) => _payloads[id];

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
    final String mime = pending.mimeType;
    final AuiAttachment attachment = mime.startsWith('image/')
        ? ImageAttachment(
            id: pending.id,
            filename: pending.filename,
            url: _dataUrl(mime, pending),
          )
        : DocumentAttachment(
            id: pending.id,
            filename: pending.filename,
            mimeType: mime,
            data: _dataUrl(mime, pending),
          );
    _stored[attachment.id] = attachment;
    if (pending.data != null) _payloads[attachment.id] = pending.data!;
    yield AttachmentAddResult.complete(attachment);
  }

  @override
  Future<void> remove(AuiAttachment attachment) async {
    _stored.remove(attachment.id);
    _payloads.remove(attachment.id);
  }

  /// A `data:` URL, which is how an attachment carries bytes with no server.
  static String _dataUrl(String mime, PendingAttachment pending) {
    final String? url = pending.url;
    if (url != null && url.startsWith('data:')) return url;
    final Uint8List bytes = pending.data ?? Uint8List(0);
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }
}

/// The port's default answer to "open this file": it decodes the payload and
/// saves it under the system's temporary directory, then reports the path.
///
/// The host still owns the real action — where files go, whether a picker opens
/// — but a message with a file chip does something sensible with no wiring.
/// On the web there is no file system, so this reports null and the caller
/// keeps whatever it does today.
class TempFileSaver {
  const TempFileSaver({this.directory});

  /// Where to write; the system temporary directory by default.
  final String? directory;

  Future<String?> save(FilePart part, {String? name}) async {
    final String? payload = part.data;
    if (payload == null || payload.isEmpty) return null;
    final String filename = name ?? part.filename ?? 'download';
    final Uint8List bytes = payload.startsWith('data:')
        ? _decodeDataUrl(payload)
        : Uint8List.fromList(utf8.encode(payload));
    return writeBytes(filename, bytes);
  }

  /// The platform half: a real write where there is a file system, null on the
  /// web, where the host decides what a download means.
  Future<String?> writeBytes(String filename, Uint8List bytes) =>
      platform.writeFileBytes(filename, bytes, directory: directory);

  static Uint8List _decodeDataUrl(String url) {
    final int comma = url.indexOf(',');
    if (comma < 0) return Uint8List(0);
    final String body = url.substring(comma + 1);
    if (url.substring(0, comma).contains(';base64')) {
      return base64Decode(body);
    }
    return Uint8List.fromList(utf8.encode(Uri.decodeComponent(body)));
  }
}
