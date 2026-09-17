import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One action offered on a text selection.
@immutable
class QuoteAction {
  const QuoteAction({
    required this.key,
    required this.label,
    required this.icon,
  });

  final String key;
  final String label;
  final IconData icon;
}

/// A passage the reader highlighted, with the actions they can take on it —
/// the `quote-reply` element.
class AssistantQuoteReply extends StatelessWidget {
  const AssistantQuoteReply({
    super.key,
    required this.before,
    required this.selection,
    required this.after,
    this.actions = const <QuoteAction>[],
    this.toolbarVisible = false,
    this.quoted,
    this.onAction,
  });

  /// Text around the selection, kept verbatim.
  final String before;
  final String selection;
  final String after;

  final List<QuoteAction> actions;

  /// Shows the floating toolbar; without [onAction] it stays hidden.
  final bool toolbarVisible;

  /// The quote a reply is being written against.
  final String? quoted;

  final ValueChanged<String>? onAction;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final bool showToolbar = toolbarVisible && onAction != null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text.rich(
              TextSpan(
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: auiFg(theme, 0.7),
                ),
                children: <TextSpan>[
                  TextSpan(text: before),
                  TextSpan(
                    text: selection,
                    style: TextStyle(
                      color: auiFg(theme, 0.95),
                      background: Paint()
                        ..color = const Color(0xFF3B82F6)
                            .withValues(alpha: dark ? 0.25 : 0.18),
                    ),
                  ),
                  TextSpan(text: after),
                ],
              ),
            ),
            SizedBox(
              height: 36,
              child: showToolbar
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        decoration: auiPaper(theme, radius: 999),
                        padding: const EdgeInsets.all(4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (final QuoteAction action in actions)
                              AuiPillButton(
                                label: action.label,
                                icon: action.icon,
                                height: 28,
                                padding: 10,
                                onPressed: () => onAction!(action.key),
                              ),
                          ],
                        ),
                      ),
                    )
                  : null,
            ),
            if (quoted != null) ...<Widget>[
              Text(
                'replying to',
                style: auiMono(context, color: auiFg(theme, 0.3)),
              ),
              const SizedBox(height: 4),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: auiFg(theme, 0.15), width: 2),
                  ),
                ),
                padding: const EdgeInsets.only(left: 10),
                child: Text(
                  quoted!,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: auiFg(theme, 0.55),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
