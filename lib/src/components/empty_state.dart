import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// The greeting, suggestion pills and composer a thread shows before its
/// first message — the `empty-state` element.
///
/// Upstream ships this as five composable pieces (`EmptyState`,
/// `EmptyStateGreeting`, `EmptyStateSuggestions`, `EmptyStateSuggestion`,
/// `EmptyStateComposer`); the port keeps them as one widget plus a
/// [AssistantEmptyStateSuggestion] for hosts that build their own layout.
class AssistantEmptyState extends StatelessWidget {
  const AssistantEmptyState({
    super.key,
    required this.greeting,
    this.suggestions = const <String>[],
    this.onSuggestion,
    this.composerPlaceholder,
    this.onSend,
  });

  /// Headline, e.g. `How can I help you today?`.
  final String greeting;

  /// Prompt pills, in order.
  final List<String> suggestions;

  final ValueChanged<String>? onSuggestion;

  /// Placeholder of the stand-in composer; omit it to hide the row.
  final String? composerPlaceholder;

  /// Send affordance of the stand-in composer.
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 448),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              greeting,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                height: 1.25,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.5,
                color: theme.foreground,
              ),
            ),
            if (suggestions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 28),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final (int index, String suggestion)
                      in suggestions.indexed)
                    AssistantEmptyStateSuggestion(
                      label: suggestion,
                      index: index,
                      onTap: onSuggestion == null
                          ? null
                          : () => onSuggestion!(suggestion),
                    ),
                ],
              ),
            ],
            if (composerPlaceholder != null) ...<Widget>[
              const SizedBox(height: 28),
              Container(
                height: 52,
                decoration: auiPaper(theme, radius: 999),
                padding: const EdgeInsets.only(left: 20, right: 10),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        composerPlaceholder!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.3,
                          color: auiFg(theme, 0.35),
                        ),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Send',
                      child: GestureDetector(
                        onTap: onSend,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: onSend == null
                                ? theme.primary.withValues(alpha: 0.3)
                                : theme.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_upward,
                            size: 16,
                            color: theme.primaryForeground,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One prompt pill of an [AssistantEmptyState].
class AssistantEmptyStateSuggestion extends StatefulWidget {
  const AssistantEmptyStateSuggestion({
    super.key,
    required this.label,
    this.index = 0,
    this.onTap,
  });

  final String label;

  /// Position in the list; used by hosts that stagger the entrance.
  final int index;

  final VoidCallback? onTap;

  @override
  State<AssistantEmptyStateSuggestion> createState() =>
      _AssistantEmptyStateSuggestionState();
}

class _AssistantEmptyStateSuggestionState
    extends State<AssistantEmptyStateSuggestion> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          transform: Matrix4.translationValues(0, _hovered ? -1 : 0, 0),
          decoration: auiPaper(theme, radius: 999),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              color: theme.foreground,
            ),
          ),
        ),
      ),
    );
  }
}
