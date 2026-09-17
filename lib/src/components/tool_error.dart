import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// A tool call that failed, with its retry budget and the two ways out —
/// the `tool-error` element.
class AssistantToolError extends StatelessWidget {
  const AssistantToolError({
    super.key,
    required this.name,
    required this.target,
    required this.message,
    required this.attempt,
    required this.maxAttempts,
    this.retrying = false,
    this.onRetry,
    this.onSkip,
  });

  final String name;
  final String target;

  /// The failure text, shown in full: upstream does not truncate it.
  final String message;

  final int attempt;
  final int maxAttempts;

  /// Swaps the retry glyph for a spinner and the label for `Retrying`.
  final bool retrying;

  /// Both affordances disable themselves when their callback is absent.
  final VoidCallback? onRetry;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
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
                  const Icon(
                    Icons.error_outline,
                    size: 14,
                    color: _red500,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    name,
                    style: auiMono(context, color: auiFg(theme, 0.55)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      target,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.2,
                        color: auiFg(theme, 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '$attempt/$maxAttempts',
                    style: auiMono(context, color: auiFg(theme, 0.3)).copyWith(
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: auiField(theme, radius: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  message,
                  style: auiMono(
                    context,
                    color: dark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C),
                  ).copyWith(height: 1.5),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  AuiPillButton(
                    label: 'Skip',
                    onPressed: onSkip,
                  ),
                  const SizedBox(width: 8),
                  AuiPillButton(
                    label: retrying ? 'Retrying' : 'Retry',
                    leading: retrying ? const AuiSpinner(size: 12) : null,
                    icon: retrying ? null : Icons.refresh,
                    onPressed: retrying ? null : onRetry,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Note: tailwind red-500 for the alert glyph, red-700 / red-300 for the
// message text — the theme has no error-text token at this size.
const Color _red500 = Color(0xFFEF4444);
