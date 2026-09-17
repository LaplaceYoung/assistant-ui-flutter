import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One attachment on a message.
@immutable
class MessageAttachmentItem {
  const MessageAttachmentItem({
    required this.id,
    required this.name,
    required this.size,
    this.kind = AttachmentKind.file,
    this.pages,
    this.thumbnail,
  });

  final String id;
  final String name;

  /// Human size, e.g. `1.2 MB`.
  final String size;

  final AttachmentKind kind;

  /// Page count of a document.
  final int? pages;

  /// The picture for [AttachmentKind.image].
  final Widget? thumbnail;
}

/// How an attachment is presented.
enum AttachmentKind { image, document, file }

/// The attachments carried by a message — the `message-attachment` element.
///
/// Named `...List` because `attachment.dart` already exports the runtime-bound
/// `AssistantMessageAttachments` wrapper, which renders through this widget.
class AssistantMessageAttachmentList extends StatelessWidget {
  const AssistantMessageAttachmentList({
    super.key,
    this.attachments = const <MessageAttachmentItem>[],
    this.onOpen,
  });

  final List<MessageAttachmentItem> attachments;

  /// Opens one; without it the rows are inert.
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (int index, MessageAttachmentItem item)
                in attachments.indexed)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == attachments.length - 1 ? 0 : 6,
                ),
                child: _Row(item: item, onOpen: onOpen),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({required this.item, required this.onOpen});

  final MessageAttachmentItem item;
  final ValueChanged<String>? onOpen;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final MessageAttachmentItem item = widget.item;
    final bool image = item.kind == AttachmentKind.image;
    final bool tappable = widget.onOpen != null;

    return MouseRegion(
      cursor: tappable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tappable ? () => widget.onOpen!(item.id) : null,
        child: Container(
          decoration: image
              ? auiPaper(theme, radius: 16)
              : BoxDecoration(
                  color: _hovered && tappable
                      ? auiFg(theme, 0.07)
                      : auiFieldColor(theme),
                  borderRadius: BorderRadius.circular(16),
                ),
          padding: image
              ? const EdgeInsets.all(8)
              : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: <Widget>[
              if (image)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: item.thumbnail ??
                        ColoredBox(
                          color: auiFg(theme, 0.6),
                          child: const SizedBox.expand(),
                        ),
                  ),
                )
              else
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.background.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    item.kind == AttachmentKind.document
                        ? Icons.description_outlined
                        : Icons.attach_file,
                    size: 14,
                    color: auiFg(theme, 0.45),
                  ),
                ),
              SizedBox(width: image ? 12 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.3,
                        color: auiFg(theme, 0.9),
                      ),
                    ),
                    Text(
                      item.pages == null
                          ? item.size
                          : '${item.size} · ${item.pages} pages',
                      style: auiMono(context, color: auiFg(theme, 0.35)),
                    ),
                  ],
                ),
              ),
              if (image) ...<Widget>[
                Icon(
                  Icons.image_outlined,
                  size: 14,
                  color: auiFg(theme, 0.25),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
