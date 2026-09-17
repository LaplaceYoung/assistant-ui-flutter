import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';

/// Claude clone — the claude.ai layout, ported from the official example page.
///
/// Warm cream `#F0ECE0` (dark `#2b2a27`), serif typography everywhere, an
/// orange `#c96442` accent, no shadows, and action bars that only appear on
/// hover.
class ClaudeClone extends StatelessWidget {
  const ClaudeClone({
    super.key,
    this.onPickAttachments,
    this.disclaimer =
        'Claude can make mistakes. Please double-check responses.',
  });

  final Future<List<PendingAttachment>> Function(BuildContext context)?
      onPickAttachments;
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
          ),
          child: _EmptyLayout(palette: palette, onPickAttachments: onPickAttachments),
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
  });

  factory _Palette.of(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return _Palette(
      isDark: isDark,
      background: isDark ? const Color(0xFF2B2A27) : const Color(0xFFF0ECE0),
      surface: isDark ? const Color(0xFF1F1E1B) : const Color(0xFFFFFFFF),
      edge: isDark ? const Color(0xFF3D3A35) : const Color(0xFFE5E0D6),
      text: isDark ? const Color(0xFFEEEEEE) : const Color(0xFF1A1A18),
      mutedText: isDark ? const Color(0xFFA3A098) : const Color(0xFF5B5950),
      userBubble: isDark ? const Color(0xFF393937) : const Color(0xFFE5E0D6),
    );
  }

  final bool isDark;
  final Color background;
  final Color surface;
  final Color edge;
  final Color text;
  final Color mutedText;
  final Color userBubble;

  static const Color accent = Color(0xFFC96442);

  /// Serif everywhere, with 1.65 line height on assistant text.
  static const List<String> _serif = <String>['Georgia', 'Times New Roman', 'serif'];

  TextStyle textStyle(double size, {FontWeight? weight, double height = 1.65}) =>
      TextStyle(
        fontFamily: _serif.first,
        fontFamilyFallback: _serif.sublist(1),
        fontSize: size,
        height: height,
        color: text,
        fontWeight: weight,
      );

  AssistantTheme get theme =>
      (isDark ? AssistantTheme.dark : AssistantTheme.light).copyWith(
        background: background,
        foreground: text,
        muted: userBubble,
        mutedForeground: mutedText,
        primary: accent,
        primaryForeground: const Color(0xFFFFFFFF),
        bodyStyle: textStyle(15),
      );
}

class _EmptyLayout extends StatelessWidget {
  const _EmptyLayout({required this.palette, this.onPickAttachments});

  final _Palette palette;
  final Future<List<PendingAttachment>> Function(BuildContext context)?
      onPickAttachments;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(Icons.auto_awesome, size: 26, color: _Palette.accent),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'How can I help you today?',
                        textAlign: TextAlign.center,
                        style: palette.textStyle(28, height: 1.3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                _Composer(palette: palette, onPickAttachments: onPickAttachments),
                const SizedBox(height: 18),
                _ModeTabs(palette: palette),
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
  });

  final _Palette palette;
  final String disclaimer;
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
                  constraints: const BoxConstraints(maxWidth: 720),
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
          ColoredBox(
            color: palette.background,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Column(
                    children: <Widget>[
                      _Composer(
                        palette: palette,
                        onPickAttachments: onPickAttachments,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        disclaimer,
                        textAlign: TextAlign.center,
                        style: palette.textStyle(12, height: 1.4).copyWith(
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

/// Borderless-feeling composer: a single border, no shadow.
class _Composer extends StatelessWidget {
  const _Composer({required this.palette, this.onPickAttachments});

  final _Palette palette;
  final Future<List<PendingAttachment>> Function(BuildContext context)?
      onPickAttachments;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.edge),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AuiComposerInput(
              placeholder: 'How can I help you today?',
              maxLines: 8,
              style: palette.textStyle(15, height: 1.5),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'How can I help you today?',
                hintStyle: palette
                    .textStyle(15, height: 1.5)
                    .copyWith(color: palette.mutedText),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                if (onPickAttachments != null)
                  AssistantTooltipIconButton(
                    icon: Icons.add,
                    tooltip: 'Add content',
                    size: 32,
                    iconSize: 18,
                    foregroundColor: palette.mutedText,
                    hoverColor: palette.userBubble,
                    onPressed: () async {
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
                const Spacer(),
                _ModelPicker(palette: palette),
                const SizedBox(width: 8),
                AssistantPrimaryAction(
                  size: 32,
                  iconSize: 18,
                  backgroundColor: _Palette.accent,
                  foregroundColor: const Color(0xFFFFFFFF),
                  disabledBackgroundColor: palette.userBubble,
                  disabledForegroundColor: palette.mutedText,
                ),
              ],
            ),
          ],
        ),
      );
}


/// Sonnet / Opus / Haiku picker with descriptions and a "More options" row.
class _ModelPicker extends StatelessWidget {
  const _ModelPicker({required this.palette});

  final _Palette palette;

  @override
  Widget build(BuildContext context) => AssistantMenuButton(
        width: 280,
        items: <AssistantMenuItem>[
          AssistantMenuItem(
            label: 'Claude Sonnet 4.5',
            description: 'Balanced speed and intelligence',
            selected: true,
            onSelected: () {},
          ),
          AssistantMenuItem(
            label: 'Claude Opus 4.7',
            description: 'Most capable for complex work',
            onSelected: () {},
          ),
          AssistantMenuItem(
            label: 'Claude Haiku 4.5',
            description: 'Fastest for quick answers',
            onSelected: () {},
          ),
          const AssistantMenuItem.separator(),
          AssistantMenuItem(label: 'More options', onSelected: () {}),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Sonnet 4.5',
                style: palette.textStyle(13, height: 1.2).copyWith(
                  color: palette.mutedText,
                ),
              ),
              const Icon(Icons.keyboard_arrow_down, size: 16, color: _Palette.accent),
            ],
          ),
        ),
      );
}

/// Write / Learn / Code / From Drive / From Calendar chips.
class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.palette});

  final _Palette palette;

  static const List<(IconData, String)> _tabs = <(IconData, String)>[
    (Icons.edit_outlined, 'Write'),
    (Icons.school, 'Learn'),
    (Icons.code, 'Code'),
    (Icons.folder_open, 'From Drive'),
    (Icons.calendar_today, 'From Calendar'),
  ];

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: <Widget>[
          for (final (IconData icon, String label) in _tabs)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.edge),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 14, color: palette.mutedText),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: palette
                        .textStyle(13, height: 1.2)
                        .copyWith(color: palette.mutedText),
                  ),
                ],
              ),
            ),
        ],
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
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: palette.userBubble,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: AssistantMessageParts(
                  isUser: true,
                  spacing: 8,
                ),
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

/// Full-width plain serif, no bubble and no avatar.
class _AssistantMessage extends StatelessWidget {
  const _AssistantMessage({required this.palette});

  final _Palette palette;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const AssistantMessageParts(),
          AuiActionBar(
            hideWhenRunning: true,
            autohide: AuiActionBarAutohide.notLast,
            floatWhenHidden: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
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
                  builder: (BuildContext context, bool enabled, bool submitted) =>
                      _actionIcon(
                    Icons.thumb_up_outlined,
                    'Helpful',
                    palette,
                    enabled,
                  ),
                ),
                AuiActionBarFeedback(
                  type: FeedbackType.negative,
                  builder: (BuildContext context, bool enabled, bool submitted) =>
                      _actionIcon(
                    Icons.thumb_down_outlined,
                    'Not helpful',
                    palette,
                    enabled,
                  ),
                ),
                AuiActionBarReload(
                  builder: (BuildContext context, bool enabled) =>
                      _actionIcon(Icons.refresh, 'Retry', palette, enabled),
                ),
              ],
            ),
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
      radius: 8,
      foregroundColor: palette.mutedText,
      hoverColor: palette.isDark
          ? const Color(0x0DFFFFFF)
          : const Color(0x0D1A1A18),
      disabledColor: palette.mutedText,
      onPressed: enabled ? () {} : null,
    );
