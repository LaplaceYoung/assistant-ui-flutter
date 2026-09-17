import 'package:flutter/material.dart';

import 'theme.dart';

/// The sentence a reader wrote and never sent, waiting at the top of the
/// composer bar — the `draft-restore` element.
///
/// The runtime keeps drafts per thread; the timestamp and the text are the
/// host's to supply, so the same card works for a draft kept in memory, on disk
/// or by a backend.
class AssistantDraftRestore extends StatelessWidget {
  const AssistantDraftRestore({
    super.key,
    required this.text,
    required this.savedAt,
    this.onRestore,
    this.onDismiss,
    this.maxLines = 1,
  });

  final String text;

  /// When the draft was written, so the card can say how stale it is.
  final DateTime savedAt;

  final VoidCallback? onRestore;
  final VoidCallback? onDismiss;
  final int maxLines;

  /// `2 minutes ago`, `3 hours ago`, `yesterday` — the phrasing the live card
  /// uses.
  static String describe(DateTime savedAt, {DateTime? now}) {
    final Duration age = (now ?? DateTime.now()).difference(savedAt);
    if (age.inMinutes < 1) return 'just now';
    if (age.inMinutes < 60) {
      final int minutes = age.inMinutes;
      return '$minutes minute${minutes == 1 ? '' : 's'} ago';
    }
    if (age.inHours < 24) {
      final int hours = age.inHours;
      return '$hours hour${hours == 1 ? '' : 's'} ago';
    }
    final int days = age.inDays;
    return '$days day${days == 1 ? '' : 's'} ago';
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.muted,
        borderRadius: BorderRadius.circular(theme.cardRadius),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.edit_outlined, size: 15, color: theme.mutedForeground),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  text,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: theme.body(context).copyWith(color: theme.foreground),
                ),
                const SizedBox(height: 2),
                Text(
                  'unsent draft · ${describe(savedAt)}',
                  style: theme.small(context).copyWith(
                    color: theme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (onRestore != null) ...<Widget>[
            const SizedBox(width: 12),
            _Action(label: 'Restore', onTap: onRestore!, theme: theme),
          ],
          if (onDismiss != null) ...<Widget>[
            const SizedBox(width: 4),
            Semantics(
              button: true,
              label: 'Dismiss the draft',
              child: IconButton(
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close,
                  size: 16,
                  color: theme.mutedForeground,
                ),
                splashRadius: 14,
                constraints: const BoxConstraints.tightFor(
                  width: 28,
                  height: 28,
                ),
                padding: EdgeInsets.zero,
                tooltip: null,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.onTap,
    required this.theme,
  });

  final String label;
  final VoidCallback onTap;
  final AssistantTheme theme;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.muted,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: theme.border),
              ),
              child: Text(
                label,
                style: theme.small(context).copyWith(
                  color: theme.foreground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
}
