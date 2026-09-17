import 'package:flutter/material.dart';

import '../core/attachments.dart';
import '../core/message_part.dart';
import '../primitives/message.dart';
import 'message_attachment.dart';
import 'motion.dart';
import 'theme.dart';

/// Attachment rendered as a card or thumbnail — the `attachment` element.
///
/// Upstream renders images as a preview with a remove button and everything
/// else as a chip with a type icon, name and, when known, size.
class AssistantAttachmentCard extends StatelessWidget {
  const AssistantAttachmentCard({
    super.key,
    required this.attachment,
    this.onRemove,
    this.progress,
    this.width = 180,
  });

  final AuiAttachment attachment;

  /// Shows a remove button when set.
  final VoidCallback? onRemove;

  /// Upload progress, 0..1. Draws an overlay bar while it is below 1.
  final double? progress;

  final double width;

  bool get _isImage => attachment is ImageAttachment;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    if (_isImage) {
      return _ImageThumbnail(
        attachment: attachment as ImageAttachment,
        onRemove: onRemove,
        progress: progress,
        width: width,
      );
    }
    final DocumentAttachment document = attachment as DocumentAttachment;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.muted,
        borderRadius: BorderRadius.circular(theme.cardRadius),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: <Widget>[
          _TypeIcon(mimeType: document.mimeType, theme: theme),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  attachment.filename ?? 'Attachment',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.small(context).copyWith(
                    color: theme.foreground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  document.mimeType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.small(context).copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(Icons.close, size: 14, color: theme.mutedForeground),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({
    required this.attachment,
    required this.onRemove,
    required this.progress,
    required this.width,
  });

  final ImageAttachment attachment;
  final VoidCallback? onRemove;
  final double? progress;
  final double width;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return SizedBox(
      width: width,
      height: width * 0.75,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(theme.cardRadius),
              child: AuiMessagePartImage(
                part: ImagePart(image: attachment.url),
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (progress != null && progress! < 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              // `transition-[width] duration-300` on the upload line.
              child: AuiAnimatedProgressBar(
                value: progress!,
                height: 3,
                duration: const Duration(milliseconds: 300),
                track: theme.border,
                color: theme.primary,
              ),
            ),
          if (onRemove != null)
            Positioned(
              right: 6,
              top: 6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: theme.background.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close, size: 12, color: theme.foreground),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Attachments attached to a user message: the runtime's [AuiAttachment]s
/// rendered through the `message-attachment` element's list.
class AssistantMessageAttachments extends StatelessWidget {
  const AssistantMessageAttachments({
    super.key,
    required this.attachments,
    this.onOpen,
  });

  final List<AuiAttachment> attachments;

  /// Opens one, by id.
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();
    // The runtime attachment carries no byte size, so the mime type fills the
    // secondary line the element keeps for it.
    return AssistantMessageAttachmentList(
      onOpen: onOpen,
      attachments: <MessageAttachmentItem>[
        for (final AuiAttachment attachment in attachments)
          MessageAttachmentItem(
            id: attachment.id,
            name: attachment.filename ?? 'attachment',
            size: switch (attachment) {
              ImageAttachment() => 'image',
              DocumentAttachment(mimeType: final String mime) => mime,
            },
            kind: switch (attachment) {
              ImageAttachment() => AttachmentKind.image,
              DocumentAttachment() => AttachmentKind.document,
            },
          ),
      ],
    );
  }
}

class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.mimeType, required this.theme});

  final String mimeType;
  final AssistantTheme theme;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    if (mimeType.startsWith('image/')) {
      icon = Icons.image_outlined;
    } else if (mimeType.contains('pdf')) {
      icon = Icons.picture_as_pdf_outlined;
    } else if (mimeType.contains('json') ||
        mimeType.contains('javascript') ||
        mimeType.contains('typescript') ||
        mimeType.startsWith('text/')) {
      icon = Icons.description_outlined;
    } else if (mimeType.contains('zip') || mimeType.contains('tar')) {
      icon = Icons.folder_zip_outlined;
    } else {
      icon = Icons.insert_drive_file_outlined;
    }
    return Icon(icon, size: 18, color: theme.mutedForeground);
  }
}
