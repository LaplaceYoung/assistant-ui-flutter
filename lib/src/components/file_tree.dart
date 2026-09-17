import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One row of a file tree.
@immutable
class FileTreeNode {
  const FileTreeNode({
    required this.path,
    required this.name,
    required this.depth,
    this.isFolder = false,
    this.additions,
    this.deletions,
  });

  final String path;
  final String name;

  /// Nesting depth; each level indents by 13.5px.
  final int depth;

  /// Folder rows render with a chevron and a folder glyph.
  final bool isFolder;

  final int? additions;
  final int? deletions;

  const FileTreeNode.folder({
    required this.path,
    required this.name,
    required this.depth,
  })  : isFolder = true,
        additions = null,
        deletions = null;
}

/// The files a run touched, with their diff counts — the `file-tree` element.
class AssistantFileTree extends StatelessWidget {
  const AssistantFileTree({
    super.key,
    required this.nodes,
    required this.visibleCount,
    required this.totalAdditions,
    required this.totalDeletions,
    this.selectedPath,
    this.onSelect,
  });

  final List<FileTreeNode> nodes;

  /// How many rows have been revealed, in order.
  final int visibleCount;

  final int totalAdditions;
  final int totalDeletions;

  /// The row shown as picked.
  final String? selectedPath;

  /// Reports a pick; the row is a file the reader is looking at.
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color green =
        dark ? const Color(0xFF34D399) : const Color(0xFF059669);
    final Color red = dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    final int files =
        nodes.where((FileTreeNode node) => !node.isFolder).length;

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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '$files files changed',
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                          color: theme.foreground,
                        ),
                      ),
                    ),
                    Text(
                      '+$totalAdditions',
                      style: auiMono(context, color: green),
                    ),
                    Text(' ', style: auiMono(context)),
                    Text(
                      '−$totalDeletions',
                      style: auiMono(context, color: red),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              for (final FileTreeNode node in nodes.take(visibleCount))
                _Row(
                  selected: node.path == selectedPath,
                  onSelect: onSelect,
                  node: node,
                  green: green,
                  red: red,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    required this.node,
    required this.green,
    required this.red,
    required this.selected,
    this.onSelect,
  });

  final FileTreeNode node;
  final Color green;
  final Color red;
  final bool selected;
  final ValueChanged<String>? onSelect;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final FileTreeNode node = widget.node;
    return MouseRegion(
      cursor: widget.onSelect == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect == null
            ? null
            : () => widget.onSelect!(widget.node.path),
        child: Container(
        decoration: BoxDecoration(
          color: widget.selected
              ? auiFg(theme, 0.08)
              : (_hovered ? auiFg(theme, 0.03) : null),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: 4 + node.depth * 13.5,
          right: 4,
        ),
        child: Row(
          children: <Widget>[
            if (node.isFolder) ...<Widget>[
              Icon(
                Icons.expand_more,
                size: 12,
                color: auiFg(theme, 0.25),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.folder_outlined,
                size: 14,
                color: auiFg(theme, 0.35),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: auiFg(theme, 0.6),
                  ),
                ),
              ),
            ] else ...<Widget>[
              const SizedBox(width: 16),
              Icon(
                Icons.insert_drive_file_outlined,
                size: 14,
                color: auiFg(theme, 0.3),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  node.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: auiFg(theme, 0.85),
                  ),
                ),
              ),
              if (node.additions != null && node.additions != 0)
                Text(
                  '+${node.additions}',
                  style: auiMono(context, color: widget.green),
                ),
              if (node.additions != null && node.additions != 0)
                Text(' ', style: auiMono(context)),
              if (node.deletions != null && node.deletions != 0)
                Text(
                  '−${node.deletions}',
                  style: auiMono(context, color: widget.red),
                ),
            ],
          ],
        ),
        ),
      ),
    );
  }
}
