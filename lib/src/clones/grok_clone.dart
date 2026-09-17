import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';

/// Grok clone — the grok.com layout, ported from the official example page.
///
/// Pill composer with a paperclip, a model pill that collapses to its icon
/// while typing, an animated Mic → Send → Stop slot with inverted colors, and
/// a hover-only action bar with a message timing chip.
class GrokClone extends StatelessWidget {
  const GrokClone({
    super.key,
    this.onPickAttachments,
    this.placeholder = 'What do you want to know?',
  });

  final Future<List<PendingAttachment>> Function(BuildContext context)?
      onPickAttachments;
  final String placeholder;

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
            placeholder: placeholder,
            onPickAttachments: onPickAttachments,
          ),
          child: _EmptyLayout(
            palette: palette,
            placeholder: placeholder,
            onPickAttachments: onPickAttachments,
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
    required this.userBubble,
    required this.userBubbleEdge,
    required this.icon,
    required this.iconHover,
  });

  factory _Palette.of(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return _Palette(
      isDark: isDark,
      background: isDark ? const Color(0xFF141414) : const Color(0xFFFDFDFD),
      surface: isDark ? const Color(0xFF212121) : const Color(0xFFF8F8F8),
      edge: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
      text: isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0D0D0D),
      mutedText: isDark ? const Color(0xFF9A9A9A) : const Color(0xFF6B6B6B),
      userBubble: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
      userBubbleEdge:
          isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
      icon: isDark ? const Color(0xFF9A9A9A) : const Color(0xFF6B6B6B),
      iconHover: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
    );
  }

  final bool isDark;
  final Color background;
  final Color surface;
  final Color edge;
  final Color text;
  final Color mutedText;
  final Color userBubble;
  final Color userBubbleEdge;
  final Color icon;
  final Color iconHover;

  /// Inverted primary: dark on light, light on dark.
  Color get primary => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0D0D0D);
  Color get primaryForeground =>
      isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFFFFFF);

  AssistantTheme get theme =>
      (isDark ? AssistantTheme.dark : AssistantTheme.light).copyWith(
        background: background,
        foreground: text,
        muted: userBubble,
        mutedForeground: mutedText,
        primary: primary,
        primaryForeground: primaryForeground,
      );
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.palette});

  final _Palette palette;

  @override
  Widget build(BuildContext context) => Text(
        // Fidelity gap: the official asset is an SVG wordmark; this is a
        // typographic approximation with the same weight and tracking.
        'grok',
        style: TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w800,
          letterSpacing: -2,
          color: palette.text,
        ),
      );
}

class _EmptyLayout extends StatelessWidget {
  const _EmptyLayout({
    required this.palette,
    required this.placeholder,
    this.onPickAttachments,
  });

  final _Palette palette;
  final String placeholder;
  final Future<List<PendingAttachment>> Function(BuildContext context)?
      onPickAttachments;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 768),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _Wordmark(palette: palette),
                const SizedBox(height: 24),
                _Composer(
                  palette: palette,
                  placeholder: placeholder,
                  onPickAttachments: onPickAttachments,
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
    required this.placeholder,
    this.onPickAttachments,
  });

  final _Palette palette;
  final String placeholder;
  final Future<List<PendingAttachment>> Function(BuildContext context)?
      onPickAttachments;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          Expanded(
            child: AuiThreadViewport(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 768),
                  child: AuiThreadMessages(
                    builder: (
                      BuildContext context,
                      ThreadMessage message,
                      bool isLast,
                    ) =>
                        Padding(
                      padding: const EdgeInsets.only(bottom: 18),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 768),
                child: _Composer(
                  palette: palette,
                  placeholder: placeholder,
                  onPickAttachments: onPickAttachments,
                ),
              ),
            ),
          ),
        ],
      );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.palette,
    required this.placeholder,
    this.onPickAttachments,
  });

  final _Palette palette;
  final String placeholder;
  final Future<List<PendingAttachment>> Function(BuildContext context)?
      onPickAttachments;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: palette.edge),
        ),
        padding: const EdgeInsets.all(6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            AssistantTooltipIconButton(
              icon: Icons.attach_file,
              tooltip: 'Attach files',
              size: 36,
              iconSize: 18,
              shape: AssistantIconButtonShape.circle,
              foregroundColor: palette.text,
              hoverColor: palette.iconHover,
              onPressed: onPickAttachments == null
                  ? null
                  : () async {
                      final List<PendingAttachment> files =
                          await onPickAttachments!(context);
                      if (!context.mounted) return;
                      for (final PendingAttachment file in files) {
                        await AuiRuntimeProvider.of(context)
                            .composer
                            .addPendingAttachment(file);
                      }
                    },
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: AuiComposerInput(
                  placeholder: placeholder,
                  maxLines: 6,
                  style: TextStyle(fontSize: 15, height: 1.4, color: palette.text),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: placeholder,
                    hintStyle: TextStyle(fontSize: 15, color: palette.mutedText),
                  ),
                ),
              ),
            ),
            _ModelPill(palette: palette),
            const SizedBox(width: 4),
            AssistantPrimaryAction(
              size: 36,
              iconSize: 18,
              backgroundColor: palette.primary,
              foregroundColor: palette.primaryForeground,
              disabledBackgroundColor: palette.iconHover,
              disabledForegroundColor: palette.mutedText,
            ),
          ],
        ),
      );
}

/// Shows the model name while the composer is empty and collapses to the icon
/// while typing, the way the official pill does.
class _ModelPill extends StatefulWidget {
  const _ModelPill({required this.palette});

  final _Palette palette;

  @override
  State<_ModelPill> createState() => _ModelPillState();
}

class _ModelPillState extends State<_ModelPill> {
  String _model = 'Grok 4.1';

  @override
  Widget build(BuildContext context) => AuiStateBuilder<bool>(
        selector: (AuiState state) => state.composer.isEmpty,
        builder: (BuildContext context, bool isEmpty) => AssistantMenuButton(
          width: 280,
          items: <AssistantMenuItem>[
            AssistantMenuItem(
              label: 'Fast',
              description: 'Quick answers',
              selected: _model == 'Fast',
              onSelected: () => setState(() => _model = 'Fast'),
            ),
            AssistantMenuItem(
              label: 'Grok 4.1',
              description: 'Balanced',
              selected: _model == 'Grok 4.1',
              onSelected: () => setState(() => _model = 'Grok 4.1'),
            ),
            AssistantMenuItem(
              label: 'Think',
              description: 'Reasons before answering',
              selected: _model == 'Think',
              onSelected: () => setState(() => _model = 'Think'),
            ),
            const AssistantMenuItem.separator(),
            AssistantMenuItem(
              label: 'Subscribe to SuperGrok',
              icon: Icons.bolt,
              onSelected: () {},
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.bolt, size: 16, color: widget.palette.text),
                AnimatedSize(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  alignment: Alignment.centerLeft,
                  child: isEmpty
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const SizedBox(width: 8),
                            Text(
                              _model,
                              style: TextStyle(
                                fontSize: 14,
                                color: widget.palette.text,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
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
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.9),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: palette.userBubble,
                  border: Border.all(color: palette.userBubbleEdge),
                  // rounded-3xl with the bottom-right corner pulled in.
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: const AssistantMessageParts(isUser: true),
              ),
            ),
            AuiActionBar(
              hideWhenRunning: true,
              autohide: AuiActionBarAutohide.notLast,
              floatWhenHidden: true,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AuiActionBarEdit(
                    builder: (BuildContext context, bool enabled) =>
                        _actionIcon(Icons.edit_outlined, 'Edit', palette, enabled),
                  ),
                  AuiActionBarCopy(
                    builder: (BuildContext context, bool enabled, bool copied) =>
                        _actionIcon(
                      copied ? Icons.check : Icons.copy,
                      'Copy',
                      palette,
                      enabled,
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
          const AssistantMessageParts(),
          Row(
            children: <Widget>[
              AuiActionBar(
                hideWhenRunning: true,
                autohide: AuiActionBarAutohide.notLast,
                floatWhenHidden: true,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    AuiActionBarReload(
                      builder: (BuildContext context, bool enabled) =>
                          _actionIcon(Icons.refresh, 'Regenerate', palette, enabled),
                    ),
                    AuiActionBarCopy(
                      builder: (BuildContext context, bool enabled, bool copied) =>
                          _actionIcon(
                        copied ? Icons.check : Icons.copy,
                        'Copy',
                        palette,
                        enabled,
                      ),
                    ),
                    AuiActionBarFeedback(
                      type: FeedbackType.positive,
                      builder:
                          (BuildContext context, bool enabled, bool submitted) =>
                              _actionIcon(
                        Icons.thumb_up_outlined,
                        'Good response',
                        palette,
                        enabled,
                      ),
                    ),
                    AuiActionBarFeedback(
                      type: FeedbackType.negative,
                      builder:
                          (BuildContext context, bool enabled, bool submitted) =>
                              _actionIcon(
                        Icons.thumb_down_outlined,
                        'Bad response',
                        palette,
                        enabled,
                      ),
                    ),
                  ],
                ),
              ),
              // The timing chip sits beside the actions, like upstream.
              AuiIf(
                condition: (AuiState state) =>
                    state.message?.message.metadata.timing != null,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: AssistantMessageTiming(iconSize: 13),
                ),
              ),
            ],
          ),
        ],
      );
}

Widget _actionIcon(
  IconData icon,
  String tooltip,
  _Palette palette,
  bool enabled,
) =>
    AssistantTooltipIconButton(
      icon: icon,
      tooltip: tooltip,
      size: 32,
      iconSize: 16,
      shape: AssistantIconButtonShape.circle,
      foregroundColor: palette.icon,
      hoverColor: palette.iconHover,
      disabledColor: palette.icon,
      onPressed: enabled ? () {} : null,
    );
