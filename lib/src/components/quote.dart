import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// Quoted text at the top of a user message — the `quote` element's block.
class AssistantQuoteBlock extends StatelessWidget {
  const AssistantQuoteBlock({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.format_quote,
              size: 12,
              color: theme.mutedForeground.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontStyle: FontStyle.italic,
                color: theme.mutedForeground.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The floating toolbar that appears over selected text, with the quote
/// action — the `quote` element's selection toolbar.
class AssistantSelectionToolbar extends StatelessWidget {
  const AssistantSelectionToolbar({
    super.key,
    this.label = 'Quote',
    this.onQuote,
  });

  final String label;

  /// Without it the action is inert.
  final VoidCallback? onQuote;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.background,
        border: Border.all(color: theme.border),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(4),
      child: AuiPillButton(
        label: label,
        icon: Icons.format_quote,
        height: 28,
        padding: 10,
        onPressed: onQuote,
      ),
    );
  }
}

/// The quote waiting in the composer, with its dismiss control — the `quote`
/// element's composer preview.
class AssistantComposerQuotePreview extends StatelessWidget {
  const AssistantComposerQuotePreview({
    super.key,
    required this.text,
    this.onDismiss,
  });

  final String text;

  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.muted.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.format_quote,
              size: 14,
              color: theme.mutedForeground.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: theme.mutedForeground,
              ),
            ),
          ),
          if (onDismiss != null) ...<Widget>[
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Dismiss quote',
              child: GestureDetector(
                onTap: onDismiss,
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: theme.mutedForeground.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
