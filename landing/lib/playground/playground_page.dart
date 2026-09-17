import 'dart:async';

import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../landing_theme.dart';
import 'playground_config.dart';

/// The builder playground, in the shape of the live one: presets on the left,
/// the preview in the middle under a viewport preset, the component and style
/// controls on the right, and the code the configuration amounts to.
///
/// Every control maps to a real constructor argument or theme value — the
/// preview is the styled threads element this package ships, not a mock-up.
class PlaygroundPage extends StatefulWidget {
  const PlaygroundPage({super.key});

  @override
  State<PlaygroundPage> createState() => _PlaygroundPageState();
}

enum _Viewport { desktop, tablet, mobile }

class _PlaygroundPageState extends State<PlaygroundPage> {
  PlaygroundPreset get _initial =>
      kPresets.firstWhere((PlaygroundPreset p) => p.id == _presetId,
          orElse: () => kPresets.first);

  late String _presetId;
  late PlaygroundConfig _config;
  late final LocalRuntime _runtime = LocalRuntime(adapter: _PreviewAdapter());

  _Viewport _viewport = _Viewport.desktop;
  bool _showCode = false;

  @override
  void initState() {
    super.initState();
    final Map<String, String> query = Uri.base.queryParameters;
    _presetId = query['preset'] ?? kPresets.first.id;
    if (kPresets.every((PlaygroundPreset p) => p.id != _presetId)) {
      _presetId = kPresets.first.id;
    }
    _config = PlaygroundConfig.applyQuery(_initial.config, query);
    _applySuggestions();
  }

  void _applySuggestions() {
    _runtime.thread.setSuggestions(
      _config.suggestions
          ? const <ThreadSuggestion>[
              ThreadSuggestion(prompt: 'Show me the code'),
              ThreadSuggestion(prompt: 'What changes with radius?'),
              ThreadSuggestion(prompt: 'Try the dark theme'),
            ]
          : const <ThreadSuggestion>[],
    );
  }

  void _update(PlaygroundConfig next) {
    setState(() => _config = next);
    _applySuggestions();
  }

  void _pickPreset(PlaygroundPreset preset) {
    setState(() {
      _presetId = preset.id;
      _config = preset.config;
    });
    _applySuggestions();
  }

  /// The URL carries the preset plus whatever the visitor changed.
  String get _shareUrl {
    final Map<String, String> query = <String, String>{
      'page': 'playground',
      'preset': _presetId,
      ..._config.toQuery(),
    };
    return Uri.base.replace(queryParameters: query).toString();
  }

  Future<void> _share() async {
    await Clipboard.setData(ClipboardData(text: _shareUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copied — it carries your changes.')),
    );
  }

  @override
  void dispose() {
    _runtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    final PlaygroundPreset preset = _initial;
    final double? viewportWidth = switch (_viewport) {
      _Viewport.desktop => null,
      _Viewport.tablet => 768,
      _Viewport.mobile => 375,
    };
    return LandingPalette(
      colors: colors,
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide = constraints.maxWidth >= 1024;
              final Widget preview = _Preview(
                config: _config,
                runtime: _runtime,
                width: viewportWidth,
              );
              final Widget presetsPane = _PresetsPane(
                selected: _presetId,
                onPick: _pickPreset,
              );
              final Widget side = _SidePane(
                config: _config,
                onChanged: _update,
                showCode: _showCode,
                onShowCode: (bool value) => setState(() => _showCode = value),
                colors: colors,
              );
              if (!wide) {
                return Column(
                  children: <Widget>[
                    _Header(
                      preset: preset,
                      viewport: _viewport,
                      onViewport: (_Viewport v) => setState(() => _viewport = v),
                      onShare: _share,
                      colors: colors,
                    ),
                    Expanded(child: preview),
                    SizedBox(height: 280, child: SingleChildScrollView(child: side)),
                  ],
                );
              }
              return Column(
                children: <Widget>[
                  _Header(
                    preset: preset,
                    viewport: _viewport,
                    onViewport: (_Viewport v) => setState(() => _viewport = v),
                    onShare: _share,
                    colors: colors,
                  ),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(width: 280, child: presetsPane),
                        _Edge(colors: colors),
                        Expanded(child: preview),
                        _Edge(colors: colors),
                        SizedBox(width: 340, child: side),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.preset,
    required this.viewport,
    required this.onViewport,
    required this.onShare,
    required this.colors,
  });

  final PlaygroundPreset preset;
  final _Viewport viewport;
  final ValueChanged<_Viewport> onViewport;
  final VoidCallback onShare;
  final LandingColors colors;

  @override
  Widget build(BuildContext context) => Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.border)),
        ),
        child: Row(
          children: <Widget>[
            Text(
              'Playground',
              style: LandingText.body(context).copyWith(
                color: colors.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              preset.name,
              style: LandingText.mono(context, size: 11)
                  .copyWith(color: colors.mutedForeground),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                preset.description,
                overflow: TextOverflow.ellipsis,
                style: LandingText.small(context)
                    .copyWith(color: colors.mutedForeground),
              ),
            ),
            const Spacer(),
            _Segmented<_Viewport>(
              colors: colors,
              value: viewport,
              options: const <_Seg>[
                _Seg(_Viewport.desktop, 'Desktop'),
                _Seg(_Viewport.tablet, 'Tablet'),
                _Seg(_Viewport.mobile, 'Mobile'),
              ],
              onChanged: onViewport,
            ),
            const SizedBox(width: 10),
            _MiniButton(
              label: 'Share',
              colors: colors,
              onTap: onShare,
            ),
          ],
        ),
      );
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.config,
    required this.runtime,
    required this.width,
  });

  final PlaygroundConfig config;
  final LocalRuntime runtime;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    final bool dark = config.theme == PlaygroundTheme.dark;
    final Color accent =
        dark ? config.swatch.dark : config.swatch.light;
    final AssistantTheme base =
        dark ? AssistantTheme.dark : AssistantTheme.light;
    final AssistantTheme theme = base.copyWith(
      primary: accent,
      bubbleRadius: config.cornerRadius,
      composerRadius: config.cornerRadius,
      cardRadius: config.cornerRadius,
    );
    return Container(
      color: dark ? const Color(0xFF161616) : colors.background,
      alignment: Alignment.topCenter,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double frameWidth =
              width == null ? constraints.maxWidth : width!.clamp(0, constraints.maxWidth);
          return Container(
            width: frameWidth,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: colors.border),
              borderRadius: BorderRadius.circular(10),
              color: dark ? const Color(0xFF0D0D0D) : colors.background,
            ),
            clipBehavior: Clip.antiAlias,
            child: AssistantThemeProvider(
              theme: theme.copyWith(
                bodyStyle: AssistantTheme.of(context)
                    .body(context)
                    .copyWith(fontSize: config.fontSize),
                smallStyle: AssistantTheme.of(context)
                    .small(context)
                    .copyWith(fontSize: (config.fontSize - 1).clamp(8, 24)),
              ),
              child: AuiRuntimeProvider(
                runtime: runtime,
                child: AssistantThread(
                  maxWidth: config.maxWidth,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: config.messageGap,
                  ),
                  showScrollToLatest: config.scrollToBottom,
                  groupToolCalls: config.groupToolCalls,
                  showComposer: config.composer,
                  composerPlaceholder: 'Ask anything…',
                  emptyState: config.threadWelcome
                      ? AssistantThreadEmptyState(theme: theme)
                      : const SizedBox.shrink(),
                  avatarBuilder: config.avatar
                      ? (BuildContext context) =>
                          AssistantAvatar(theme: theme)
                      : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PresetsPane extends StatelessWidget {
  const _PresetsPane({required this.selected, required this.onPick});

  final String selected;
  final ValueChanged<PlaygroundPreset> onPick;

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'PRESETS',
              style: LandingText.eyebrow(context).copyWith(
                color: colors.mutedForeground,
                fontSize: 10,
              ),
            ),
          ),
          for (final PlaygroundPreset preset in kPresets)
            _PresetCard(
              preset: preset,
              selected: preset.id == selected,
              onTap: () => onPick(preset),
              colors: colors,
            ),
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  final PlaygroundPreset preset;
  final bool selected;
  final VoidCallback onTap;
  final LandingColors colors;

  @override
  Widget build(BuildContext context) {
    final PlaygroundConfig c = preset.config;
    final Color swatch = c.theme == PlaygroundTheme.dark ? c.swatch.dark : c.swatch.light;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? colors.muted : null,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? colors.border : Colors.transparent,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 3, right: 8),
                decoration: BoxDecoration(
                  color: swatch,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.border),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      preset.name,
                      style: LandingText.small(context).copyWith(
                        color: colors.foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      preset.description,
                      style: LandingText.small(context).copyWith(
                        color: colors.mutedForeground,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidePane extends StatelessWidget {
  const _SidePane({
    required this.config,
    required this.onChanged,
    required this.showCode,
    required this.onShowCode,
    required this.colors,
  });

  final PlaygroundConfig config;
  final ValueChanged<PlaygroundConfig> onChanged;
  final bool showCode;
  final ValueChanged<bool> onShowCode;
  final LandingColors colors;

  @override
  Widget build(BuildContext context) {
    if (showCode) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _SectionTitle('CODE', colors: colors),
                const Spacer(),
                _MiniButton(
                  label: 'Controls',
                  colors: colors,
                  onTap: () => onShowCode(false),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.muted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.border),
              ),
              child: SelectableText(
                playgroundSnippet(config),
                style: LandingText.mono(context, size: 11).copyWith(
                  color: colors.foreground,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _MiniButton(
              label: 'Copy',
              colors: colors,
              onTap: () => Clipboard.setData(
                ClipboardData(text: playgroundSnippet(config)),
              ),
            ),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _SectionTitle('COMPONENTS', colors: colors),
              const Spacer(),
              _MiniButton(
                label: 'Code',
                colors: colors,
                onTap: () => onShowCode(true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _Toggle(
            label: 'Thread welcome',
            value: config.threadWelcome,
            colors: colors,
            onChanged: (bool v) => onChanged(config.copyWith(threadWelcome: v)),
          ),
          _Toggle(
            label: 'Suggestions',
            value: config.suggestions,
            colors: colors,
            onChanged: (bool v) => onChanged(config.copyWith(suggestions: v)),
          ),
          _Toggle(
            label: 'Scroll to bottom',
            value: config.scrollToBottom,
            colors: colors,
            onChanged: (bool v) => onChanged(config.copyWith(scrollToBottom: v)),
          ),
          _Toggle(
            label: 'Avatar',
            value: config.avatar,
            colors: colors,
            onChanged: (bool v) => onChanged(config.copyWith(avatar: v)),
          ),
          _Toggle(
            label: 'Composer',
            value: config.composer,
            colors: colors,
            onChanged: (bool v) => onChanged(config.copyWith(composer: v)),
          ),
          _Toggle(
            label: 'Group tool calls',
            value: config.groupToolCalls,
            colors: colors,
            onChanged: (bool v) => onChanged(config.copyWith(groupToolCalls: v)),
          ),
          const SizedBox(height: 18),
          _SectionTitle('STYLES', colors: colors),
          const SizedBox(height: 10),
          _Row(label: 'Theme', colors: colors),
          _Segmented<PlaygroundTheme>(
            colors: colors,
            value: config.theme,
            options: const <_Seg>[
              _Seg(PlaygroundTheme.light, 'Light'),
              _Seg(PlaygroundTheme.dark, 'Dark'),
            ],
            onChanged: (PlaygroundTheme v) =>
                onChanged(config.copyWith(theme: v)),
          ),
          const SizedBox(height: 12),
          _Row(label: 'Accent', colors: colors),
          Row(
            children: <Widget>[
              for (final PlaygroundAccent accent in kAccents)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(config.copyWith(accent: accent.id)),
                    child: Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: config.theme == PlaygroundTheme.dark
                            ? accent.dark
                            : accent.light,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: config.accent == accent.id
                              ? colors.foreground
                              : colors.border,
                          width: config.accent == accent.id ? 2 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _Row(label: 'Border radius', colors: colors),
          _Segmented<PlaygroundRadius>(
            colors: colors,
            value: config.radius,
            options: const <_Seg>[
              _Seg(PlaygroundRadius.none, 'None'),
              _Seg(PlaygroundRadius.sm, 'Sm'),
              _Seg(PlaygroundRadius.md, 'Md'),
              _Seg(PlaygroundRadius.lg, 'Lg'),
              _Seg(PlaygroundRadius.full, 'Full'),
            ],
            onChanged: (PlaygroundRadius v) =>
                onChanged(config.copyWith(radius: v)),
          ),
          const SizedBox(height: 12),
          _Row(label: 'Font size', colors: colors),
          _Segmented<double>(
            colors: colors,
            value: config.fontSize,
            options: const <_Seg>[
              _Seg(13, '13'),
              _Seg(14, '14'),
              _Seg(15, '15'),
              _Seg(16, '16'),
            ],
            onChanged: (double v) => onChanged(config.copyWith(fontSize: v)),
          ),
          const SizedBox(height: 12),
          _Row(label: 'Message spacing', colors: colors),
          _Segmented<PlaygroundSpacing>(
            colors: colors,
            value: config.spacing,
            options: const <_Seg>[
              _Seg(PlaygroundSpacing.compact, 'Compact'),
              _Seg(PlaygroundSpacing.comfortable, 'Comfortable'),
              _Seg(PlaygroundSpacing.spacious, 'Spacious'),
            ],
            onChanged: (PlaygroundSpacing v) =>
                onChanged(config.copyWith(spacing: v)),
          ),
          const SizedBox(height: 12),
          _Row(label: 'Max width', colors: colors),
          _Segmented<double>(
            colors: colors,
            value: config.maxWidth,
            options: const <_Seg>[
              _Seg(40 * 16, '40rem'),
              _Seg(44 * 16, '44rem'),
              _Seg(48 * 16, '48rem'),
              _Seg(52 * 16, '52rem'),
            ],
            onChanged: (double v) => onChanged(config.copyWith(maxWidth: v)),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.muted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              'The preview is the package\'s own thread. Controls the port does not '
              'have yet (attachments, branch picker, edit, sources, action-bar '
              'entries, code themes) are not listed rather than faked.',
              style: LandingText.small(context).copyWith(
                color: colors.mutedForeground,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.colors});

  final String text;
  final LandingColors colors;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: LandingText.eyebrow(context).copyWith(
          color: colors.mutedForeground,
          fontSize: 10,
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.colors});

  final String label;
  final LandingColors colors;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          label,
          style: LandingText.small(context).copyWith(
            color: colors.foreground,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.colors,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final LandingColors colors;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: LandingText.small(context)
                      .copyWith(color: colors.foreground),
                ),
              ),
              Container(
                width: 34,
                height: 18,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: value ? colors.foreground : colors.muted,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.border),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 150),
                  alignment:
                      value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: value ? colors.background : colors.mutedForeground,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Seg<T> {
  const _Seg(this.value, this.label);

  final T value;
  final String label;
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.colors,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final LandingColors colors;
  final T value;
  final List<_Seg> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: <Widget>[
          for (final _Seg seg in options)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(seg.value as T),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: seg.value == value ? colors.foreground : colors.muted,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: colors.border),
                  ),
                  child: Text(
                    seg.label,
                    style: LandingText.small(context).copyWith(
                      color: seg.value == value
                          ? colors.background
                          : colors.mutedForeground,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final String label;
  final LandingColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: colors.muted,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.border),
            ),
            child: Text(
              label,
              style: LandingText.small(context).copyWith(
                color: colors.foreground,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
}

class _Edge extends StatelessWidget {
  const _Edge({required this.colors});

  final LandingColors colors;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, color: colors.border);
}

/// Answers for the preview thread: a streamed reply carrying reasoning, a tool
/// call and markdown, so the controls have something to act on.
class _PreviewAdapter implements ChatModelAdapter {
  @override
  Stream<ChatModelRunResult> run(ChatModelRunContext context) async* {
    final String question =
        context.messages.isEmpty ? '' : context.messages.last.text.trim();
    yield const ChatModelRunResult(
      content: <MessagePart>[
        ReasoningPart(
          'They want to see the controls take effect. Answer short, then offer '
          'the code.',
        ),
      ],
    );
    final String body = question.isEmpty
        ? 'Send anything: this is the **preview thread**, and every control on '
            'the right is applied to it — theme, accent, radii, width, spacing, '
            'avatars, composer.'
        : 'You asked: *$question*\n\n'
            'The points above hold here too:\n\n'
            '1. **Markdown** renders\n'
            '2. Reasoning stays collapsed\n'
            '3. Tool calls group when you ask them to\n';
    final StringBuffer buffer = StringBuffer();
    for (final String word in body.split(' ')) {
      buffer.write(word);
      buffer.write(' ');
      yield ChatModelRunResult(
        content: <MessagePart>[
          const ReasoningPart(
            'They want to see the controls take effect. Answer short, then '
            'offer the code.',
          ),
          TextPart(buffer.toString().trimRight()),
        ],
      );
      await Future<void>.delayed(const Duration(milliseconds: 12));
    }
    yield const ChatModelRunResult(
      content: <MessagePart>[
        ReasoningPart(
          'They want to see the controls take effect. Answer short, then '
          'offer the code.',
        ),
        TextPart(''),
        ToolCallPart(
          toolName: 'search_docs',
          toolCallId: 'call_1',
          args: <String, Object?>{'q': 'playground'},
          result: <String, Object?>{'hits': 3},
        ),
        ToolCallPart(
          toolName: 'read_page',
          toolCallId: 'call_2',
          args: <String, Object?>{'path': '/playground'},
          result: <String, Object?>{'ok': true},
        ),
      ],
    );
  }
}
