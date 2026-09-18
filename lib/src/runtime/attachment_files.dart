import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../core/attachments.dart';
import 'defaults_stub.dart'
    if (dart.library.io) 'defaults_io.dart' as platform;

/// An attachment backend that keeps the bytes on disk instead of in memory.
///
/// Uploads land under a directory the adapter owns, and each attachment carries
/// a `file:` URL, so a host that later saves or re-uploads the attachment has a
/// path to read rather than a copy in the heap. On the web there is no file
/// system: [add] reports the pick as incomplete instead of pretending.
class FileAttachmentAdapter implements AttachmentAdapter {
  FileAttachmentAdapter({
    this.directory,
    this.accept,
    this.stepDelay = const Duration(milliseconds: 120),
    this.steps = 2,
  });

  /// Where the files go; a directory of the adapter's own by default.
  final String? directory;

  /// Rejects a pick by returning false; by default anything is accepted.
  final bool Function(PendingAttachment pending)? accept;

  final Duration stepDelay;
  final int steps;

  final Map<String, AuiAttachment> _stored = <String, AuiAttachment>{};
  final Map<String, String> _paths = <String, String>{};

  List<AuiAttachment> get attachments =>
      List<AuiAttachment>.unmodifiable(_stored.values);

  /// Where an attachment's bytes live, when it was stored here.
  String? pathOf(String id) => _paths[id];

  @override
  Stream<AttachmentAddResult> add(PendingAttachment pending) async* {
    if (accept != null && !accept!(pending)) {
      yield const AttachmentAddResult.incomplete();
      return;
    }
    final Uint8List bytes = pending.data ?? _decode(pending.url);
    if (bytes.isEmpty) {
      yield const AttachmentAddResult.incomplete();
      return;
    }
    for (int step = 0; step < steps; step++) {
      if (stepDelay > Duration.zero) await Future<void>.delayed(stepDelay);
      yield const AttachmentAddResult.running();
    }
    final String? path = await platform.writeFileBytes(
      pending.filename,
      bytes,
      directory: directory,
    );
    if (path == null) {
      // No file system here: the memory adapter is the one for this platform.
      yield const AttachmentAddResult.incomplete();
      return;
    }
    final String url = Uri.file(path).toString();
    final AuiAttachment attachment = pending.mimeType.startsWith('image/')
        ? ImageAttachment(id: pending.id, filename: pending.filename, url: url)
        : DocumentAttachment(
            id: pending.id,
            filename: pending.filename,
            mimeType: pending.mimeType,
            data: url,
          );
    _stored[attachment.id] = attachment;
    _paths[attachment.id] = path;
    yield AttachmentAddResult.complete(attachment);
  }

  @override
  Future<void> remove(AuiAttachment attachment) async {
    final String? path = _paths.remove(attachment.id);
    _stored.remove(attachment.id);
    if (path != null) await platform.deleteFile(path);
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
