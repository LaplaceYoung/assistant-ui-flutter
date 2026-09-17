import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:assistant_ui_landing/playground/playground_config.dart';

/// The builder's contract: presets are named configurations, a shared URL
/// carries only the changes, and the snippet describes what is on screen.
void main() {
  test('the presets are the ones the live playground offers', () {
    expect(
      kPresets.map((PlaygroundPreset p) => p.id).toList(),
      <String>[
        'default',
        'chatgpt',
        'claude',
        'perplexity',
        'minimal',
        'gemini',
        'copilot',
        'slack',
        'grok',
      ],
    );
    for (final PlaygroundPreset preset in kPresets) {
      expect(preset.description, isNotEmpty);
    }
  });

  test('a shared URL carries the changes and nothing else', () {
    expect(PlaygroundConfig.defaults.toQuery(), isEmpty);

    final PlaygroundConfig edited = PlaygroundConfig.defaults.copyWith(
      theme: PlaygroundTheme.dark,
      radius: PlaygroundRadius.full,
      composer: false,
    );
    expect(edited.toQuery(), <String, String>{
      'theme': 'dark',
      'radius': 'full',
      'composer': '0',
    });
    expect(
      PlaygroundConfig.defaults.copyWith(reasoning: true).toQuery(),
      <String, String>{'reasoning': '1'},
    );

    // Round trip: what a link carries is what the visitor gets back.
    final PlaygroundConfig restored =
        PlaygroundConfig.fromQuery(edited.toQuery());
    expect(restored.theme, PlaygroundTheme.dark);
    expect(restored.radius, PlaygroundRadius.full);
    expect(restored.composer, isFalse);
    expect(restored.accent, PlaygroundConfig.defaults.accent);
  });

  test('a link keeps the preset it names and applies only its own keys', () {
    final PlaygroundPreset chatgpt = kPresets.firstWhere(
      (PlaygroundPreset p) => p.id == 'chatgpt',
    );
    // The URL of a shared ChatGPT link with one change.
    final PlaygroundConfig shared = PlaygroundConfig.applyQuery(
      chatgpt.config,
      <String, String>{
        'page': 'playground',
        'preset': 'chatgpt',
        'radius': 'full',
      },
    );
    expect(shared.theme, PlaygroundTheme.dark, reason: 'the preset keeps its theme');
    expect(shared.accent, chatgpt.config.accent);
    expect(shared.radius, PlaygroundRadius.full, reason: 'the change wins');
    expect(shared.suggestions, chatgpt.config.suggestions);

    // A bare preset link changes nothing.
    expect(
      PlaygroundConfig.applyQuery(
        chatgpt.config,
        <String, String>{'page': 'playground', 'preset': 'chatgpt'},
      ).theme,
      PlaygroundTheme.dark,
    );
  });

  test('the styles resolve to the values the widgets take', () {
    expect(
      PlaygroundConfig.defaults.copyWith(radius: PlaygroundRadius.none).cornerRadius,
      0,
    );
    expect(
      PlaygroundConfig.defaults.copyWith(radius: PlaygroundRadius.full).cornerRadius,
      999,
    );
    expect(
      PlaygroundConfig.defaults.copyWith(spacing: PlaygroundSpacing.spacious).messageGap,
      40,
    );
  });

  test('reasoning follows upstream: off by default, on where it ships on', () {
    expect(PlaygroundConfig.defaults.reasoning, isFalse);
    for (final String id in <String>['claude', 'copilot']) {
      expect(
        kPresets.firstWhere((PlaygroundPreset p) => p.id == id).config.reasoning,
        isTrue,
        reason: '$id ships with reasoning on',
      );
    }
  });

  test('the snippet reflects the configuration', () {
    final String defaults = playgroundSnippet(PlaygroundConfig.defaults);
    expect(defaults, contains('bubbleRadius: 16'));
    expect(defaults, contains('fontSize: 14'));
    expect(defaults, isNot(contains('showComposer: false')));

    final String stripped = playgroundSnippet(
      PlaygroundConfig.defaults.copyWith(
        radius: PlaygroundRadius.none,
        composer: false,
        scrollToBottom: false,
      ),
    );
    expect(stripped, contains('bubbleRadius: 0'));
    expect(stripped, contains('showComposer: false'));
    expect(stripped, contains('showScrollToLatest: false'));
  });

  test('every preset renders a distinct snippet', () {
    final Set<String> snippets = <String>{
      for (final PlaygroundPreset p in kPresets) playgroundSnippet(p.config),
    };
    expect(snippets.length, greaterThanOrEqualTo(6));
  });

  test('the swatches exist for every accent id a preset uses', () {
    for (final PlaygroundPreset preset in kPresets) {
      expect(
        kAccents.any((PlaygroundAccent a) => a.id == preset.config.accent),
        isTrue,
        reason: '${preset.id} uses ${preset.config.accent}',
      );
      expect(preset.config.swatch.light, isNot(Colors.transparent));
    }
  });
}
