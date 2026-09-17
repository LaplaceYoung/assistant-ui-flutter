import 'dart:ui' show ImageFilter;

import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';

/// Gemini clone — the gemini.google.com layout, ported from the official
/// example page.
///
/// A single-line greeting over an ambient blue glow, one pill composer shared
/// by the empty and chat states, avatar-free assistant replies, a grey user
/// bubble, and the three send states (disabled grey, ready blue, stop).
class GeminiClone extends StatelessWidget {
  const GeminiClone({
    super.key,
    this.onPickAttachments,
    this.greeting = 'How can I help you today?',
  });

  final Future<List<PendingAttachment>> Function(BuildContext context)?
      onPickAttachments;
  final String greeting;

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
            onPickAttachments: onPickAttachments,
          ),
          child: _EmptyLayout(
            palette: palette,
            greeting: greeting,
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
    required this.text,
    required this.mutedText,
    required this.userBubble,
    required this.controlIcon,
  });

  factory _Palette.of(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return _Palette(
      isDark: isDark,
      // #0c0c0c is the dark background the official page pairs with #fdfcfc.
      background: isDark ? const Color(0xFF0C0C0C) : const Color(0xFFFDFCFC),
      surface: isDark ? const Color(0xFF1E1F20) : const Color(0xFFFFFFFF),
      text: isDark ? const Color(0xFFE3E3E3) : const Color(0xFF1F1F1F),
      mutedText: isDark ? const Color(0xFFC4C7C5) : const Color(0xFF444746),
      userBubble: isDark ? const Color(0xFF333537) : const Color(0xFFF2F0F0),
      controlIcon: isDark ? const Color(0xFFC4C7C5) : const Color(0xFF444746),
    );
  }

  final bool isDark;
  final Color background;
  final Color surface;
  final Color text;
  final Color mutedText;
  final Color userBubble;
  final Color controlIcon;

  /// `#1f3b9b` ready, `#e8eaed` disabled, per the official send button.
  static const Color sendReady = Color(0xFF1F3B9B);
  static const Color sendDisabledLight = Color(0xFFE8EAED);
  static const Color sendDisabledDark = Color(0xFF2B2C2E);
  static const Color glowLight = Color(0x99A9D1FB); // #a9d1fb at 60%
  static const Color glowDark = Color(0x801B2F9C); // #1b2f9c at 50%

  AssistantTheme get theme =>
      (isDark ? AssistantTheme.dark : AssistantTheme.light).copyWith(
        background: background,
        foreground: text,
        muted: userBubble,
        mutedForeground: mutedText,
        primary: sendReady,
        primaryForeground: const Color(0xFFFFFFFF),
      );
}

class _EmptyLayout extends StatelessWidget {
  const _EmptyLayout({
    required this.palette,
    required this.greeting,
    this.onPickAttachments,
  });

  final _Palette palette;
  final String greeting;
  final Future<List<PendingAttachment>> Function(BuildContext context)?
      onPickAttachments;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    // Ambient glow: 680x260, radius 140, blur 90.
                    IgnorePointer(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                        child: Container(
                          width: 680,
                          height: 260,
                          decoration: BoxDecoration(
                            color: palette.isDark
                                ? _Palette.glowDark
                                : _Palette.glowLight,
                            borderRadius: BorderRadius.circular(140),
                          ),
                        ),
                      ),
                    ),
                    Text(
                      greeting,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w400,
                        color: palette.text,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                SizedBox(height: 0),
                _Composer(palette: palette, onPickAttachments: onPickAttachments),
              ],
            ),
          ),
        ),
      );
}

class _ChatLayout extends StatelessWidget {
  const _ChatLayout({required this.palette, this.onPickAttachments});

  final _Palette palette;
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
                  constraints: const BoxConstraints(maxWidth: 760),
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
                constraints: const BoxConstraints(maxWidth: 760),
                child: _Composer(
                  palette: palette,
                  onPickAttachments: onPickAttachments,
                ),
              ),
            ),
          ),
        ],
      );
}

/// One-row pill: `+` menu, input, model picker, mic, send.
class _Composer extends StatelessWidget {
  const _Composer({required this.palette, this.onPickAttachments});

  final _Palette palette;
  final Future<List<PendingAttachment>> Function(BuildContext context)?
      onPickAttachments;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const <BoxShadow>[
            // shadow-[0_2px_10px_-2px_rgba(0,0,0,0.18)]
            BoxShadow(
              color: Color(0x2E000000),
              blurRadius: 10,
              offset: Offset(0, 2),
              spreadRadius: -2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            _PlusMenu(palette: palette, onPickAttachments: onPickAttachments),
            const SizedBox(width: 4),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: AuiComposerInput(
                  placeholder: 'Ask Gemini',
                  maxLines: 6,
                  style: TextStyle(fontSize: 17, height: 1.4, color: palette.text),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Ask Gemini',
                    hintStyle: TextStyle(fontSize: 17, color: palette.mutedText),
                  ),
                ),
              ),
            ),
            const _ModelPicker(),
            const SizedBox(width: 4),
            AssistantPrimaryAction(
              size: 36,
              iconSize: 20,
              backgroundColor: _Palette.sendReady,
              foregroundColor: const Color(0xFFFFFFFF),
              disabledBackgroundColor: palette.isDark
                  ? _Palette.sendDisabledDark
                  : _Palette.sendDisabledLight,
              disabledForegroundColor: const Color(0x661F1F1F),
            ),
          ],
        ),
      );
}

/// `+` menu: attachments next to the Gemini tools.
class _PlusMenu extends StatelessWidget {
  const _PlusMenu({required this.palette, this.onPickAttachments});

  final _Palette palette;
  final Future<List<PendingAttachment>> Function(BuildContext context)?
      onPickAttachments;

  @override
  Widget build(BuildContext context) => AssistantMenuButton(
        width: 280,
        items: <AssistantMenuItem>[
          AssistantMenuItem(
            label: 'Add photos & files',
            icon: Icons.add_photo_alternate_outlined,
            onSelected: () async {
              if (onPickAttachments == null) return;
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
          const AssistantMenuItem.separator(),
          AssistantMenuItem(
            label: 'Deep Research',
            description: 'Get a detailed report on any topic',
            icon: Icons.travel_explore,
            onSelected: () {},
          ),
          AssistantMenuItem(
            label: 'Canvas',
            description: 'Write and edit in a shared space',
            icon: Icons.draw_outlined,
            onSelected: () {},
          ),
          AssistantMenuItem(
            label: 'Create image',
            description: 'Generate an image from a description',
            icon: Icons.image_outlined,
            onSelected: () {},
          ),
          AssistantMenuItem(
            label: 'Guided Learning',
            description: 'Work through a topic step by step',
            icon: Icons.school_outlined,
            onSelected: () {},
          ),
        ],
        // The anchor must not handle taps itself, or the menu never opens;
        // AssistantMenuButton owns the gesture and opens on tap.
        child: Tooltip(
          message: 'Add files and tools',
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: Icon(Icons.add, size: 20, color: palette.controlIcon),
          ),
        ),
      );
}

/// Fast / Thinking, each with a description and a check on the active model.
class _ModelPicker extends StatefulWidget {
  const _ModelPicker();

  @override
  State<_ModelPicker> createState() => _ModelPickerState();
}

class _ModelPickerState extends State<_ModelPicker> {
  String _model = 'Fast';

  @override
  Widget build(BuildContext context) {
    final _Palette palette = _Palette.of(context);
    return AssistantMenuButton(
      width: 260,
      items: <AssistantMenuItem>[
        AssistantMenuItem(
          label: 'Fast',
          description: 'Answers quickly',
          selected: _model == 'Fast',
          onSelected: () => setState(() => _model = 'Fast'),
        ),
        AssistantMenuItem(
          label: 'Thinking',
          description: 'Solves complex problems step by step',
          selected: _model == 'Thinking',
          onSelected: () => setState(() => _model = 'Thinking'),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _model,
              style: TextStyle(fontSize: 14, color: palette.controlIcon),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: Color(0xFF444746),
            ),
          ],
        ),
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
              constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.75),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: palette.userBubble,
                  borderRadius: BorderRadius.circular(24),
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
                  AuiActionBarCopy(
                    builder: (BuildContext context, bool enabled, bool copied) =>
                        _actionIcon(
                      copied ? Icons.check : Icons.content_paste,
                      'Copy',
                      palette,
                      enabled,
                    ),
                  ),
                  AuiActionBarEdit(
                    builder: (BuildContext context, bool enabled) => _actionIcon(
                      Icons.edit_outlined,
                      'Edit',
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
                    copied ? Icons.check : Icons.content_paste,
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
                    'Good response',
                    palette,
                    enabled,
                  ),
                ),
                AuiActionBarFeedback(
                  type: FeedbackType.negative,
                  builder: (BuildContext context, bool enabled, bool submitted) =>
                      _actionIcon(
                    Icons.thumb_down_outlined,
                    'Bad response',
                    palette,
                    enabled,
                  ),
                ),
                AuiActionBarReload(
                  builder: (BuildContext context, bool enabled) =>
                      _actionIcon(Icons.refresh, 'Regenerate', palette, enabled),
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
      iconSize: 18,
      shape: AssistantIconButtonShape.circle,
      foregroundColor: palette.controlIcon,
      hoverColor: palette.userBubble,
      disabledColor: palette.controlIcon,
      onPressed: enabled ? () {} : null,
    );
