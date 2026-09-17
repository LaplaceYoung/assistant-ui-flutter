import 'package:flutter/material.dart';

import 'indicators.dart';
import 'surfaces.dart';
import 'theme.dart';

/// A compact chat surface for embeds and sidebars — the `chat-panel` element.
///
/// Upstream ships this as six pieces (`ChatPanel`, `ChatPanelMessages`,
/// `ChatPanelUserMessage`, `ChatPanelAssistantMessage`, `ChatPanelTyping`,
/// `ChatPanelComposer`); the port exposes them as one widget plus
/// [AssistantChatPanelMessage] and [AssistantChatPanelTyping] for hosts that
/// build their own layout.
class AssistantChatPanel extends StatefulWidget {
  const AssistantChatPanel({
    super.key,
    this.messages = const <AssistantChatPanelMessage>[],
    this.typing = false,
    this.composerPlaceholder,
    this.onSend,
    this.height = 270,
  });

  final List<AssistantChatPanelMessage> messages;

  /// Draws the three bouncing dots as the last row.
  final bool typing;

  /// Placeholder of the stand-in composer; omit it to hide the row.
  final String? composerPlaceholder;

  final VoidCallback? onSend;
  final double height;

  @override
  State<AssistantChatPanel> createState() => _AssistantChatPanelState();

  Widget _buildPanel(BuildContext context, _AssistantChatPanelState? state) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 448),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: Container(
          decoration: auiPaper(theme, radius: 24),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final AssistantChatPanelMessage message
                          in messages)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: message,
                        ),
                      if (typing) const AssistantChatPanelTyping(),
                    ],
                  ),
                ),
              ),
              if (composerPlaceholder != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Container(
                    height: 40,
                    decoration: auiField(theme, radius: 999),
                    padding: const EdgeInsets.only(left: 16, right: 6),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          // A host that sends gets a field to type in; without
                          // one the composer stays the static strip upstream
                          // shows.
                          child: state == null
                              ? Text(
                                  composerPlaceholder!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.3,
                                    color: auiFg(theme, 0.35),
                                  ),
                                )
                              : TextField(
                                  controller: state._controller,
                                  onSubmitted: (_) => state._submit(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.3,
                                    color: auiFg(theme, 0.9),
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    isCollapsed: true,
                                    border: InputBorder.none,
                                    hintText: composerPlaceholder!,
                                    hintStyle: TextStyle(
                                      fontSize: 13,
                                      height: 1.3,
                                      color: auiFg(theme, 0.35),
                                    ),
                                  ),
                                ),
                        ),
                        Semantics(
                          button: true,
                          label: 'Send',
                          child: GestureDetector(
                            onTap: () => state?._submit(),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: state == null
                                    ? theme.primary.withValues(alpha: 0.3)
                                    : theme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.arrow_upward,
                                size: 14,
                                color: theme.primaryForeground,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row of an [AssistantChatPanel].
class AssistantChatPanelMessage extends StatelessWidget {
  const AssistantChatPanelMessage({
    super.key,
    required this.text,
    this.fromUser = false,
  });

  final String text;

  /// User rows render right-aligned in a field bubble.
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    if (!fromUser) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 288),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: auiFg(theme, 0.7),
            ),
          ),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        decoration: auiField(theme, radius: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: theme.foreground,
          ),
        ),
      ),
    );
  }
}

/// The three-dot typing row of an [AssistantChatPanel].
class AssistantChatPanelTyping extends StatelessWidget {
  const AssistantChatPanelTyping({super.key});

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4),
        child: AssistantTypingIndicator(dotSize: 4, spacing: 4),
      ),
    );
  }
}

class _AssistantChatPanelState extends State<AssistantChatPanel> {
  final TextEditingController _controller = TextEditingController();

  void _submit() {
    if (widget.onSend == null) return;
    if (_controller.text.trim().isEmpty) return;
    _controller.clear();
    widget.onSend!();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget._buildPanel(context, this);
}
