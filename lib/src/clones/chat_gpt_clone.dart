import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';

/// ChatGPT clone — the chatgpt.com layout, ported from the official example
/// page.
///
/// Palette (light / dark): background `#ffffff` / `#000000`, composer surface
/// `#ffffff` / `#212121`, composer edge `#e5e5e5` / white at 6%, primary text
/// `#0d0d0d` / `#ececec`, muted text `#5d5d5d` / `#afafaf`, user bubble
/// `#0d0d0d` on white / `#ececec` on near-black, action icons `#5d5d5d` /
/// `#cdcdcd`, icon hover black 7% / white 15%, send button `#0d0d0d` /
/// `#ffffff`.
class ChatGptClone extends StatelessWidget {
  const ChatGptClone({
    super.key,
    this.onPickAttachments,
    this.onVoiceMode,
    this.disclaimer = 'ChatGPT can make mistakes. Check important info.',
  });

  final Future<List<PendingAttachment>> Function(BuildContext context)?
      onPickAttachments;
  final VoidCallback? onVoiceMode;
  final String disclaimer;

  @override
  Widget build(BuildContext context) {
    final _Palette palette = _Palette.of(context);
    return AssistantThemeProvider(
      theme: palette.theme,
      child: ColoredBox(
        color: palette.background,
        child: AuiIf(
          condition: (AuiState state) => state.thread.isEmpty,
          fallback: _ChatLayout(
            palette: palette,
            disclaimer: disclaimer,
            onPickAttachments: onPickAttachments,
            onVoiceMode: onVoiceMode,
          ),
          child: _EmptyLayout(
            palette: palette,
            onPickAttachments: onPickAttachments,
            onVoiceMode: onVoiceMode,
          ),
        ),
      ),
    );
  }
}

class _Palette {
  const _Palette({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.edge,
    required this.text,
    required this.mutedText,
    required this.actionIcon,
    required this.hover,
    required this.userBubble,
    required this.userText,
    required this.primary,
    required this.primaryForeground,
  });

  factory _Palette.of(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return _Palette(
      isDark: isDark,
      background: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      surface: isDark ? const Color(0xFF212121) : const Color(0xFFFFFFFF),
      edge: isDark ? const Color(0x0FFFFFFF) : const Color(0xFFE5E5E5),
      text: isDark ? const Color(0xFFECECEC) : const Color(0xFF0D0D0D),
      mutedText: isDark ? const Color(0xFFAFAFAF) : const Color(0xFF5D5D5D),
      actionIcon: isDark ? const Color(0xFFCDCDCD) : const Color(0xFF5D5D5D),
      hover: isDark
          ? const Color(0x26FFFFFF) // white 15%
          : const Color(0x12000000), // black 7%
      userBubble: isDark ? const Color(0xFFECECEC) : const Color(0xFF0D0D0D),
      userText: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFFFFFF),
      primary: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0D0D0D),
      primaryForeground:
          isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFFFFFF),
    );
  }

  final bool isDark;
  final Color background;
  final Color surface;
  final Color edge;
  final Color text;
  final Color mutedText;
  final Color actionIcon;
  final Color hover;
  final Color userBubble;
  final Color userText;
  final Color primary;
  final Color primaryForeground;

  AssistantTheme get theme =>
      (isDark ? AssistantTheme.dark : AssistantTheme.light).copyWith(
        background: background,
        foreground: text,
        muted: isDark ? const Color(0xFF212121) : const Color(0xFFF5F5F5),
        mutedForeground: mutedText,
      );
}

class _EmptyLayout extends StatelessWidget {
  const _EmptyLayout({
    required this.palette,
    this.onPickAttachments,
    this.onVoiceMode,
  });

  final _Palette palette;
  final Future<List<PendingAttachment>> Function(BuildContext context)?
      onPickAttachments;
  final VoidCallback? onVoiceMode;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Where should we begin?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 24),
                _Composer(
                  palette: palette,
                  onPickAttachments: onPickAttachments,
                  onVoiceMode: onVoiceMode,
                ),
              ],
            ),
          ),
        ),
      );
}

class _ChatLayout extends StatelessWidget {
  const _ChatLayout({
    required this.palette,
    required this.disclaimer,
    this.onPickAttachments,
    this.onVoiceMode,
  });

  final _Palette palette;
  final String disclaimer;
  final Future<List<PendingAttachment>> Function(BuildContext context)?
      onPickAttachments;
  final VoidCallback? onVoiceMode;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Expanded(
            child: AuiThreadViewport(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: AuiThreadMessages(
                    builder: (
                      BuildContext context,
                      ThreadMessage message,
                      bool isLast,
                    ) =>
                        Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: AuiMessage(
                        message: message,
                        isLast: isLast,
                        child: message.isUser
                            ? _UserMessage(palette: palette)
                            : _AssistantMessage(palette: palette),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          ColoredBox(
            color: palette.background,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    children: <Widget>[
                      _Composer(
                        palette: palette,
                        onPickAttachments: onPickAttachments,
                        onVoiceMode: onVoiceMode,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        disclaimer,
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

/// Rounded-28 composer with the circular attach control and the four-state
/// primary action.
class _Composer extends StatelessWidget {
  const _Composer({
    required this.palette,
    this.onPickAttachments,
    this.onVoiceMode,
  });

  final _Palette palette;
  final Future<List<PendingAttachment>> Function(BuildContext context)?
      onPickAttachments;
  final VoidCallback? onVoiceMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.edge),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (onPickAttachments != null)
            AssistantComposerAttachButton(
              onPick: onPickAttachments!,
              icon: Icons.add,
              tooltip: 'Add photos & files',
              size: 36,
              backgroundColor: Colors.transparent,
              foregroundColor: palette.text,
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: AuiComposerInput(
                placeholder: 'Ask anything',
                maxLines: 8,
                style: TextStyle(fontSize: 16, height: 1.5, color: palette.text),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: 'Ask anything',
                  hintStyle: TextStyle(color: palette.mutedText, fontSize: 16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          AssistantPrimaryAction(
            size: 36,
            iconSize: 20,
            showVoiceModeButton: true,
            onVoiceMode: onVoiceMode,
            backgroundColor: palette.primary,
            foregroundColor: palette.primaryForeground,
            disabledBackgroundColor: palette.hover,
            disabledForegroundColor: palette.mutedText,
          ),
        ],
      ),
    );
  }
}

class _UserMessage extends StatelessWidget {
  const _UserMessage({required this.palette});

  final _Palette palette;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.7),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: palette.userBubble,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: AssistantThemeProvider(
                  theme: palette.theme.copyWith(foreground: palette.userText),
                  child: const AssistantMessageParts(isUser: true),
                ),
              ),
            ),
            AuiActionBar(
              autohide: AuiActionBarAutohide.always,
              floatWhenHidden: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AuiActionBarCopy(
                    builder: (BuildContext context, bool enabled, bool copied) =>
                        _actionIcon(
                      icon: copied ? Icons.check : Icons.copy,
                      tooltip: 'Copy',
                      palette: palette,
                      enabled: enabled,
                    ),
                  ),
                  AuiActionBarEdit(
                    builder: (BuildContext context, bool enabled) => _actionIcon(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit',
                      palette: palette,
                      enabled: enabled,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _AssistantMessage extends StatelessWidget {
  const _AssistantMessage({required this.palette});

  final _Palette palette;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AssistantMessageParts(
            toolUIs: <String, AuiToolUIBuilder>{},
          ),
          const SizedBox(height: 2),
          AuiActionBar(
            hideWhenRunning: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AuiActionBarCopy(
                  copiedDuration: const Duration(seconds: 2),
                  builder: (BuildContext context, bool enabled, bool copied) =>
                      _actionIcon(
                    icon: copied ? Icons.check : Icons.copy,
                    tooltip: 'Copy',
                    palette: palette,
                    enabled: enabled,
                  ),
                ),
                AuiActionBarFeedback(
                  type: FeedbackType.positive,
                  builder: (BuildContext context, bool enabled, bool submitted) =>
                      _actionIcon(
                    icon: Icons.thumb_up_outlined,
                    tooltip: 'Good response',
                    palette: palette,
                    enabled: enabled,
                    highlight: submitted,
                  ),
                ),
                AuiActionBarFeedback(
                  type: FeedbackType.negative,
                  builder: (BuildContext context, bool enabled, bool submitted) =>
                      _actionIcon(
                    icon: Icons.thumb_down_outlined,
                    tooltip: 'Bad response',
                    palette: palette,
                    enabled: enabled,
                    highlight: submitted,
                  ),
                ),
                AuiActionBarSpeak(
                  builder: (BuildContext context, bool enabled, bool speaking) =>
                      _actionIcon(
                    icon: speaking ? Icons.stop : Icons.volume_up_outlined,
                    tooltip: 'Read aloud',
                    palette: palette,
                    enabled: enabled,
                  ),
                ),
                // Fidelity gap: Share copies a hosted conversation link
                // upstream; there is no URL to share without a host backend.
                _actionIcon(
                  icon: Icons.ios_share,
                  tooltip: 'Share',
                  palette: palette,
                  enabled: false,
                ),
                AuiActionBarReload(
                  builder: (BuildContext context, bool enabled) => _actionIcon(
                    icon: Icons.refresh,
                    tooltip: 'Regenerate',
                    palette: palette,
                    enabled: enabled,
                  ),
                ),
                // Fidelity gap: the upstream "More" menu opens app-level
                // actions that have no counterpart in the port yet.
                _actionIcon(
                  icon: Icons.more_horiz,
                  tooltip: 'More',
                  palette: palette,
                  enabled: false,
                ),
              ],
            ),
          ),
        ],
      );
}

Widget _actionIcon({
  required IconData icon,
  required String tooltip,
  required _Palette palette,
  required bool enabled,
  bool highlight = false,
}) =>
    AssistantTooltipIconButton(
      icon: icon,
      tooltip: tooltip,
      size: 32,
      iconSize: 16,
      onPressed: enabled ? () {} : null,
      foregroundColor: highlight ? palette.text : palette.actionIcon,
      hoverColor: palette.hover,
      disabledColor: palette.actionIcon,
    );
