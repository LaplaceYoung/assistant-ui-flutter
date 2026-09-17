import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// A run that failed, with a retry — the `error-state` element.
class AssistantErrorState extends StatelessWidget {
  const AssistantErrorState({
    super.key,
    required this.title,
    required this.detail,
    this.retrying = false,
    this.onRetry,
  });

  final String title;

  /// What went wrong, in one line.
  final String detail;

  /// Swaps the card for a shimmering `Retrying` line.
  final bool retrying;

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;

    if (retrying) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 384),
        child: SizedBox(
          width: double.infinity,
          child: Semantics(
            container: true,
            liveRegion: true,
            label: 'Retrying',
            child: Row(
              children: <Widget>[
                AuiSpinner(size: 14, color: auiFg(theme, 0.45)),
                const SizedBox(width: 10),
                AuiShimmerLabel(
                  text: 'Retrying',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.3,
                    color: auiFg(theme, 0.55),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final Color strong =
        dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    final Color soft = strong.withValues(alpha: 0.6);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Semantics(
          container: true,
          liveRegion: true,
          label: 'Error: $title',
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444)
                  .withValues(alpha: dark ? 0.10 : 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.error_outline,
                    size: 16,
                    color: const Color(0xFFEF4444).withValues(alpha: 0.8),
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
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: strong,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        detail,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: soft,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRetry != null) ...<Widget>[
                  const SizedBox(width: 8),
                  _RetryButton(onRetry: onRetry!, color: strong),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RetryButton extends StatefulWidget {
  const _RetryButton({required this.onRetry, required this.color});

  final VoidCallback onRetry;
  final Color color;

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Retry',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onRetry,
          child: Container(
            decoration: BoxDecoration(
              color: _hovered
                  ? const Color(0xFFEF4444).withValues(alpha: 0.10)
                  : null,
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.refresh, size: 12, color: widget.color),
                const SizedBox(width: 6),
                Text(
                  'Retry',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: widget.color,
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
