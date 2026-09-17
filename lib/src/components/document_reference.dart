import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// A place in a document an answer points at.
@immutable
class DocumentAnchor {
  const DocumentAnchor({required this.page, required this.quote});

  final int page;
  final String quote;
}

/// The document behind an answer, with the cited pages and quotes — the
/// `document-reference` element.
class AssistantDocumentReference extends StatelessWidget {
  const AssistantDocumentReference({
    super.key,
    required this.title,
    required this.pages,
    required this.anchors,
    required this.activePage,
    this.onJump,
  });

  final String title;
  final int pages;
  final List<DocumentAnchor> anchors;

  /// Page the current citation sits on; several anchors may share it.
  final int activePage;

  /// Jumps to a page; rows without it are inert.
  final ValueChanged<int>? onJump;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final int currentIndex =
        anchors.indexWhere((DocumentAnchor anchor) => anchor.page == activePage);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: auiFg(theme, 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      size: 14,
                      color: auiFg(theme, 0.45),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                            color: theme.foreground,
                          ),
                        ),
                        Text(
                          '$pages pages · ${anchors.length} cited',
                          style:
                              auiMono(context, color: auiFg(theme, 0.3)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final (int index, DocumentAnchor anchor) in anchors.indexed)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: index == anchors.length - 1 ? 0 : 6,
                  ),
                  child: _Anchor(
                    anchor: anchor,
                    active: index == currentIndex,
                    onJump: onJump,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Anchor extends StatefulWidget {
  const _Anchor({
    required this.anchor,
    required this.active,
    required this.onJump,
  });

  final DocumentAnchor anchor;
  final bool active;
  final ValueChanged<int>? onJump;

  @override
  State<_Anchor> createState() => _AnchorState();
}

class _AnchorState extends State<_Anchor> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final VoidCallback? onTap = widget.onJump == null
        ? null
        : () => widget.onJump!(widget.anchor.page);
    return Semantics(
      button: onTap != null,
      selected: widget.active,
      child: MouseRegion(
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: widget.active
                  ? auiFieldColor(theme)
                  : (_hovered && onTap != null ? auiFg(theme, 0.035) : null),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'p. ${widget.anchor.page}',
                  style: auiMono(context, color: auiFg(theme, 0.3)),
                ),
                const SizedBox(height: 4),
                Container(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: auiFg(theme, 0.15), width: 2),
                    ),
                  ),
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    widget.anchor.quote,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: auiFg(theme, 0.65),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
