/// The playground is upstream's builder: a preset seeds a full configuration,
/// the controls edit it, and the preview renders under it. The fields here are
/// the ones this port can honour for real — each maps to a constructor argument
/// or an `AssistantTheme` value, so nothing in the panel is decorative.
library;

import 'dart:ui' show Color;

enum PlaygroundTheme { light, dark }

enum PlaygroundRadius { none, sm, md, lg, full }

enum PlaygroundSpacing { compact, comfortable, spacious }

/// The accent swatches upstream's builder offers.
class PlaygroundAccent {
  const PlaygroundAccent(this.id, this.name, this.light, this.dark);

  final String id;
  final String name;
  final Color light;
  final Color dark;
}

const List<PlaygroundAccent> kAccents = <PlaygroundAccent>[
  PlaygroundAccent('sky', 'Sky', Color(0xFF0EA5E9), Color(0xFF0EA5E9)),
  PlaygroundAccent('violet', 'Violet', Color(0xFF7C3AED), Color(0xFF8B5CF6)),
  PlaygroundAccent('emerald', 'Emerald', Color(0xFF10B981), Color(0xFF34D399)),
  PlaygroundAccent('amber', 'Amber', Color(0xFFF59E0B), Color(0xFFFBBF24)),
  PlaygroundAccent('rose', 'Rose', Color(0xFFE11D48), Color(0xFFFB7185)),
  PlaygroundAccent('slate', 'Slate', Color(0xFF0F172A), Color(0xFFF8FAFC)),
];

/// Everything the builder edits.
class PlaygroundConfig {
  const PlaygroundConfig({
    this.theme = PlaygroundTheme.light,
    this.accent = 'sky',
    this.radius = PlaygroundRadius.lg,
    this.maxWidth = 44 * 16,
    this.fontSize = 14,
    this.spacing = PlaygroundSpacing.comfortable,
    this.threadWelcome = true,
    this.suggestions = true,
    this.scrollToBottom = true,
    this.avatar = false,
    this.composer = true,
    this.groupToolCalls = false,
    this.reasoning = false,
    this.temperature,
    this.maxTokens,
  });

  final PlaygroundTheme theme;
  final String accent;
  final PlaygroundRadius radius;
  final double maxWidth;
  final double fontSize;
  final PlaygroundSpacing spacing;
  final bool threadWelcome;
  final bool suggestions;
  final bool scrollToBottom;
  final bool avatar;
  final bool composer;
  final bool groupToolCalls;

  /// Whether the reasoning parts render — upstream's `components.reasoning`,
  /// off by default there too.
  final bool reasoning;

  /// Upstream's `callSettings`. Null means the backend decides.
  final double? temperature;
  final int? maxTokens;

  static const PlaygroundConfig defaults = PlaygroundConfig();

  PlaygroundConfig copyWith({
    PlaygroundTheme? theme,
    String? accent,
    PlaygroundRadius? radius,
    double? maxWidth,
    double? fontSize,
    PlaygroundSpacing? spacing,
    bool? threadWelcome,
    bool? suggestions,
    bool? scrollToBottom,
    bool? avatar,
    bool? composer,
    bool? groupToolCalls,
    bool? reasoning,
    double? temperature,
    int? maxTokens,
    bool clearTemperature = false,
    bool clearMaxTokens = false,
  }) =>
      PlaygroundConfig(
        theme: theme ?? this.theme,
        accent: accent ?? this.accent,
        radius: radius ?? this.radius,
        maxWidth: maxWidth ?? this.maxWidth,
        fontSize: fontSize ?? this.fontSize,
        spacing: spacing ?? this.spacing,
        threadWelcome: threadWelcome ?? this.threadWelcome,
        suggestions: suggestions ?? this.suggestions,
        scrollToBottom: scrollToBottom ?? this.scrollToBottom,
        avatar: avatar ?? this.avatar,
        composer: composer ?? this.composer,
        groupToolCalls: groupToolCalls ?? this.groupToolCalls,
        reasoning: reasoning ?? this.reasoning,
        temperature: clearTemperature ? null : temperature ?? this.temperature,
        maxTokens: clearMaxTokens ? null : maxTokens ?? this.maxTokens,
      );

  /// The radius the bubbles, the composer and the cards take.
  double get cornerRadius => switch (radius) {
        PlaygroundRadius.none => 0,
        PlaygroundRadius.sm => 6,
        PlaygroundRadius.md => 10,
        PlaygroundRadius.lg => 16,
        PlaygroundRadius.full => 999,
      };

  /// The vertical gap between messages.
  double get messageGap => switch (spacing) {
        PlaygroundSpacing.compact => 12,
        PlaygroundSpacing.comfortable => 24,
        PlaygroundSpacing.spacious => 40,
      };

  PlaygroundAccent get swatch =>
      kAccents.firstWhere((PlaygroundAccent a) => a.id == accent,
          orElse: () => kAccents.first);

  /// Only what differs from the defaults, so a shared URL stays readable —
  /// upstream does the same with its diff against `DEFAULT_CONFIG`.
  Map<String, String> toQuery() {
    final Map<String, String> out = <String, String>{};
    if (theme != defaults.theme) out['theme'] = theme.name;
    if (accent != defaults.accent) out['accent'] = accent;
    if (radius != defaults.radius) out['radius'] = radius.name;
    if (maxWidth != defaults.maxWidth) out['maxWidth'] = maxWidth.round().toString();
    if (fontSize != defaults.fontSize) out['fontSize'] = fontSize.round().toString();
    if (spacing != defaults.spacing) out['spacing'] = spacing.name;
    if (threadWelcome != defaults.threadWelcome) {
      out['welcome'] = threadWelcome ? '1' : '0';
    }
    if (suggestions != defaults.suggestions) {
      out['suggestions'] = suggestions ? '1' : '0';
    }
    if (scrollToBottom != defaults.scrollToBottom) {
      out['scroll'] = scrollToBottom ? '1' : '0';
    }
    if (avatar != defaults.avatar) out['avatar'] = avatar ? '1' : '0';
    if (composer != defaults.composer) out['composer'] = composer ? '1' : '0';
    if (groupToolCalls != defaults.groupToolCalls) {
      out['groupTools'] = groupToolCalls ? '1' : '0';
    }
    if (reasoning != defaults.reasoning) {
      out['reasoning'] = reasoning ? '1' : '0';
    }
    if (temperature != defaults.temperature) {
      out['temperature'] = '$temperature';
    }
    if (maxTokens != defaults.maxTokens) {
      out['maxTokens'] = '$maxTokens';
    }
    return out;
  }

  /// Applies whatever the query carries on top of [base] — a link holds the
  /// preset plus the visitor's changes, so an absent key must leave the preset's
  /// value alone.
  static PlaygroundConfig applyQuery(
    PlaygroundConfig base,
    Map<String, String> query,
  ) {
    final PlaygroundConfig patch = fromQuery(query);
    return base.copyWith(
      theme: query.containsKey('theme') ? patch.theme : null,
      accent: query['accent'],
      radius: query.containsKey('radius') ? patch.radius : null,
      maxWidth: query.containsKey('maxWidth') ? patch.maxWidth : null,
      fontSize: query.containsKey('fontSize') ? patch.fontSize : null,
      spacing: query.containsKey('spacing') ? patch.spacing : null,
      threadWelcome:
          query.containsKey('welcome') ? patch.threadWelcome : null,
      suggestions:
          query.containsKey('suggestions') ? patch.suggestions : null,
      scrollToBottom: query.containsKey('scroll') ? patch.scrollToBottom : null,
      avatar: query.containsKey('avatar') ? patch.avatar : null,
      composer: query.containsKey('composer') ? patch.composer : null,
      groupToolCalls:
          query.containsKey('groupTools') ? patch.groupToolCalls : null,
      reasoning: query.containsKey('reasoning') ? patch.reasoning : null,
      temperature: query.containsKey('temperature') ? patch.temperature : null,
      maxTokens: query.containsKey('maxTokens') ? patch.maxTokens : null,
    );
  }

  static PlaygroundConfig fromQuery(Map<String, String> query) {
    T? pick<T extends Enum>(List<T> values, String? name) {
      if (name == null) return null;
      for (final T value in values) {
        if (value.name == name) return value;
      }
      return null;
    }

    bool? flag(String key) {
      final String? raw = query[key];
      if (raw == null) return null;
      return raw != '0' && raw != 'false';
    }

    double? number(String key) {
      final String? raw = query[key];
      if (raw == null) return null;
      return double.tryParse(raw);
    }

    return defaults.copyWith(
      theme: pick(PlaygroundTheme.values, query['theme']),
      accent: query['accent'],
      radius: pick(PlaygroundRadius.values, query['radius']),
      maxWidth: number('maxWidth'),
      fontSize: number('fontSize'),
      spacing: pick(PlaygroundSpacing.values, query['spacing']),
      threadWelcome: flag('welcome'),
      suggestions: flag('suggestions'),
      scrollToBottom: flag('scroll'),
      avatar: flag('avatar'),
      composer: flag('composer'),
      groupToolCalls: flag('groupTools'),
      reasoning: flag('reasoning'),
      temperature: number('temperature'),
      maxTokens: number('maxTokens')?.round(),
    );
  }
}

/// A starting point, in upstream's shape: a name, a description, a config.
class PlaygroundPreset {
  const PlaygroundPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.config,
  });

  final String id;
  final String name;
  final String description;
  final PlaygroundConfig config;
}

/// Upstream's presets, with configurations this port can render.
const List<PlaygroundPreset> kPresets = <PlaygroundPreset>[
  PlaygroundPreset(
    id: 'default',
    name: 'Default',
    description: 'Clean, modern design with all features enabled',
    config: PlaygroundConfig(),
  ),
  PlaygroundPreset(
    id: 'chatgpt',
    name: 'ChatGPT',
    description: 'Dark theme inspired by ChatGPT\'s interface',
    config: PlaygroundConfig(
      theme: PlaygroundTheme.dark,
      accent: 'emerald',
      radius: PlaygroundRadius.md,
      maxWidth: 48 * 16,
      fontSize: 15,
      suggestions: false,
    ),
  ),
  PlaygroundPreset(
    id: 'claude',
    name: 'Claude',
    description: 'Warm, elegant design inspired by Claude\'s interface',
    config: PlaygroundConfig(
      accent: 'amber',
      radius: PlaygroundRadius.lg,
      fontSize: 15,
      spacing: PlaygroundSpacing.spacious,
      avatar: true,
      reasoning: true,
    ),
  ),
  PlaygroundPreset(
    id: 'perplexity',
    name: 'Perplexity',
    description: 'Search-focused design with prominent answers',
    config: PlaygroundConfig(
      theme: PlaygroundTheme.dark,
      accent: 'sky',
      radius: PlaygroundRadius.md,
      maxWidth: 52 * 16,
      spacing: PlaygroundSpacing.compact,
      suggestions: false,
    ),
  ),
  PlaygroundPreset(
    id: 'minimal',
    name: 'Minimal',
    description: 'Stripped-down interface with only essential features',
    config: PlaygroundConfig(
      accent: 'slate',
      radius: PlaygroundRadius.none,
      maxWidth: 40 * 16,
      fontSize: 13,
      spacing: PlaygroundSpacing.compact,
      threadWelcome: false,
      suggestions: false,
      scrollToBottom: false,
    ),
  ),
  PlaygroundPreset(
    id: 'gemini',
    name: 'Gemini',
    description: 'Google\'s Gemini-inspired clean interface',
    config: PlaygroundConfig(
      accent: 'violet',
      radius: PlaygroundRadius.full,
      maxWidth: 46 * 16,
      fontSize: 15,
      avatar: true,
    ),
  ),
  PlaygroundPreset(
    id: 'copilot',
    name: 'Copilot',
    description: 'GitHub Copilot inspired developer chat',
    config: PlaygroundConfig(
      theme: PlaygroundTheme.dark,
      accent: 'emerald',
      radius: PlaygroundRadius.sm,
      maxWidth: 48 * 16,
      spacing: PlaygroundSpacing.compact,
      groupToolCalls: true,
      suggestions: false,
      reasoning: true,
    ),
  ),
  PlaygroundPreset(
    id: 'slack',
    name: 'Slack',
    description: 'Team chat inspired collaborative interface',
    config: PlaygroundConfig(
      accent: 'rose',
      radius: PlaygroundRadius.md,
      maxWidth: 50 * 16,
      avatar: true,
      groupToolCalls: true,
    ),
  ),
  PlaygroundPreset(
    id: 'grok',
    name: 'Grok',
    description: 'xAI\'s Grok-inspired minimal dark interface',
    config: PlaygroundConfig(
      theme: PlaygroundTheme.dark,
      accent: 'slate',
      radius: PlaygroundRadius.sm,
      maxWidth: 44 * 16,
      fontSize: 15,
      spacing: PlaygroundSpacing.compact,
      suggestions: false,
    ),
  ),
];

/// The code the visitor would write to get the configuration they are looking
/// at. Only what differs from the defaults is printed.
String playgroundSnippet(PlaygroundConfig config) {
  final List<String> args = <String>[
    if (!config.threadWelcome) 'emptyState: null,',
    if (!config.suggestions) '// suggestions cleared on the thread',
    if (!config.scrollToBottom) 'showScrollToLatest: false,',
    if (config.groupToolCalls) 'groupToolCalls: true,',
    if (config.reasoning) 'showReasoning: true,',
    'maxWidth: ${config.maxWidth.round()},',
    'padding: EdgeInsets.symmetric(horizontal: 16, vertical: ${config.messageGap.round()}),',
    if (config.avatar)
      'avatarBuilder: (context) => const AssistantAvatar(),',
    if (!config.composer) 'showComposer: false,',
  ];
  final String radius = config.cornerRadius % 1 == 0
      ? config.cornerRadius.round().toString()
      : config.cornerRadius.toStringAsFixed(1);
  final List<String> settings = <String>[
    if (config.maxTokens != null) 'maxTokens: ${config.maxTokens},',
    if (config.temperature != null) 'temperature: ${config.temperature},',
  ];
  return <String>[
    'LocalRuntime(',
    '  adapter: yourAdapter,',
    '  options: LocalRuntimeOptions(',
    if (settings.isEmpty) '    // backend defaults',
    for (final String setting in settings) '    $setting',
    '  ),',
    ');',
    '',
    'AssistantTheme(',
    '  brightness: Brightness.${config.theme.name},',
    '  primary: const Color(0x${config.swatch.light.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}),',
    '  bubbleRadius: $radius,',
    '  composerRadius: $radius,',
    '  cardRadius: $radius,',
    '  bodyStyle: const TextStyle(fontSize: ${config.fontSize.round()}),',
    '  child: AssistantThread(',
    for (final String arg in args) '    $arg',
    '  ),',
    ')',
  ].join('\n');
}
