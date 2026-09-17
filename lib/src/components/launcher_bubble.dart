import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// The closed/open bubble a site embeds to summon the assistant — the
/// `launcher-bubble` element.
class AssistantLauncherBubble extends StatelessWidget {
  const AssistantLauncherBubble({
    super.key,
    this.open = false,
    this.unread = 0,
    required this.greeting,
    this.prompts = const <String>[],
    this.onToggle,
    this.onPick,
    this.onStart,
  });

  final bool open;

  /// Badge count, shown only while closed.
  final int unread;

  final String greeting;
  final List<String> prompts;

  final VoidCallback? onToggle;
  final ValueChanged<String>? onPick;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 304),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (open)
              Container(
                decoration: auiPaper(theme, radius: 20),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      greeting,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: theme.foreground,
                      ),
                    ),
                    Text(
                      'typically replies in a minute',
                      style: auiMono(context, color: auiFg(theme, 0.3)),
                    ),
                    const SizedBox(height: 12),
                    for (final String prompt in prompts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _PromptRow(
                          prompt: prompt,
                          onPick: onPick,
                        ),
                      ),
                    if (onStart != null) ...<Widget>[
                      const SizedBox(height: 6),
                      AuiPillButton(
                        label: 'Start a conversation',
                        height: 32,
                        variant: AuiPillButtonVariant.ink,
                        padding: 14,
                        onPressed: onStart,
                      ),
                    ],
                  ],
                ),
              ),
            if (open) const SizedBox(height: 10),
            _BubbleButton(
              open: open,
              unread: unread,
              onToggle: onToggle,
            ),
          ],
        ),
      ),
    );
  }
}

class _PromptRow extends StatefulWidget {
  const _PromptRow({required this.prompt, required this.onPick});

  final String prompt;
  final ValueChanged<String>? onPick;

  @override
  State<_PromptRow> createState() => _PromptRowState();
}

class _PromptRowState extends State<_PromptRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return MouseRegion(
      cursor: widget.onPick == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPick == null
            ? null
            : () => widget.onPick!(widget.prompt),
        child: Container(
          decoration: BoxDecoration(
            color: auiFieldColor(theme)
                .withValues(
                  alpha: _hovered && widget.onPick != null
                      ? (theme.brightness == Brightness.dark ? 0.09 : 0.07)
                      : (theme.brightness == Brightness.dark ? 0.06 : 0.04),
                ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            widget.prompt,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: auiFg(theme, 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

class _BubbleButton extends StatelessWidget {
  const _BubbleButton({
    required this.open,
    required this.unread,
    required this.onToggle,
  });

  final bool open;
  final int unread;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool interactive = onToggle != null;
    final Widget bubble = SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: interactive
                    ? theme.primary
                    : auiFg(theme, 0.9),
                shape: BoxShape.circle,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  open ? Icons.close : Icons.chat_bubble_outline,
                  key: ValueKey<bool>(open),
                  size: 20,
                  color: interactive
                      ? theme.primaryForeground
                      : theme.background,
                ),
              ),
            ),
          ),
          if (unread > 0 && !open)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16),
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: theme.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.border),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  '$unread',
                  style: auiMono(context, color: theme.foreground)
                      .copyWith(fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );

    if (!interactive) {
      return Semantics(
        label: open ? 'Close the assistant' : 'Open the assistant',
        child: bubble,
      );
    }
    return Semantics(
      button: true,
      expanded: open,
      label: open ? 'Close the assistant' : 'Open the assistant',
      child: GestureDetector(
        onTap: onToggle,
        child: bubble,
      ),
    );
  }
}
