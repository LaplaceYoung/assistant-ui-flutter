import 'package:flutter/material.dart';

import 'theme.dart';

/// The thread list in a sidebar shell, with the product header and a source
/// link — the `threadlist-sidebar` element.
class AssistantThreadListSidebar extends StatelessWidget {
  const AssistantThreadListSidebar({
    super.key,
    this.threadList,
    this.title = 'assistant-ui',
    this.footerTitle = 'GitHub',
    this.footerSubtitle = 'View Source',
    this.onOpenSite,
    this.onOpenSource,
    this.width = 260,
  });

  /// Usually `AssistantThreadList`; the sidebar only frames it.
  final Widget? threadList;

  final String title;
  final String footerTitle;
  final String footerSubtitle;

  final VoidCallback? onOpenSite;
  final VoidCallback? onOpenSource;

  final double width;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return SizedBox(
      width: width,
      child: Container(
        decoration: BoxDecoration(
          color: theme.muted,
          border: Border(right: BorderSide(color: theme.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.border)),
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              child: _TileRow(
                icon: Icons.forum_outlined,
                title: title,
                theme: theme,
                onTap: onOpenSite,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                child: threadList ?? const SizedBox.shrink(),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.border)),
              ),
              padding: const EdgeInsets.all(12),
              child: _TileRow(
                icon: Icons.code,
                title: footerTitle,
                subtitle: footerSubtitle,
                theme: theme,
                onTap: onOpenSource,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileRow extends StatelessWidget {
  const _TileRow({
    required this.icon,
    required this.title,
    required this.theme,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final AssistantTheme theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget content = Row(
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: theme.primaryForeground),
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
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  color: theme.foreground,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: theme.mutedForeground,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}
