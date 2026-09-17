import 'package:flutter/foundation.dart';

import 'message_part.dart';

/// Attachments shown in the composer until they are sent, and then on the
/// message they were sent with.
sealed class AuiAttachment {
  const AuiAttachment({required this.id, this.filename});

  final String id;
  final String? filename;

  AttachmentType get type;

  /// The message part this attachment becomes when the message is sent.
  MessagePart get asPart;
}

class ImageAttachment extends AuiAttachment {
  const ImageAttachment({
    required super.id,
    required this.url,
    super.filename,
  });

  final String url;

  @override
  AttachmentType get type => AttachmentType.image;

  @override
  MessagePart get asPart => ImagePart(image: url, filename: filename);
}

class DocumentAttachment extends AuiAttachment {
  const DocumentAttachment({
    required super.id,
    required this.mimeType,
    this.data,
    super.filename,
  });

  final String mimeType;
  final String? data;

  @override
  AttachmentType get type => AttachmentType.document;

  @override
  MessagePart get asPart =>
      FilePart(data: data, mimeType: mimeType, filename: filename);
}

enum AttachmentType { image, document }

/// Uploads files the user picked and turns them into attachments.
///
/// Return [AttachmentAddResult.incomplete] for a file that cannot be accepted
/// (too large, wrong type).
abstract class AttachmentAdapter {
  /// Queues a file for upload; the stream reports progress and finally
  /// resolves to the ready attachment.
  Stream<AttachmentAddResult> add(PendingAttachment attachment);

  /// Releases uploaded assets when the user removes an attachment.
  Future<void> remove(AuiAttachment attachment);
}

enum AttachmentAddStatus { running, complete, incomplete }

class AttachmentAddResult {
  const AttachmentAddResult.running()
      : status = AttachmentAddStatus.running,
        attachment = null;

  const AttachmentAddResult.complete(AuiAttachment this.attachment)
      : status = AttachmentAddStatus.complete;

  const AttachmentAddResult.incomplete()
      : status = AttachmentAddStatus.incomplete,
        attachment = null;

  final AttachmentAddStatus status;
  final AuiAttachment? attachment;
}

/// A file picked by the user before the adapter turns it into an attachment.
class PendingAttachment {
  const PendingAttachment({
    required this.id,
    required this.filename,
    required this.mimeType,
    this.data,
    this.url,
  });

  final String id;
  final String filename;
  final String mimeType;
  final Uint8List? data;
  final String? url;
}
