import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:assistant_ui_landing/playground/playground_config.dart';
import 'package:assistant_ui_landing/playground/playground_state.dart';

/// One configuration for the site: the playground edits it, everything else
/// renders under it.
void main() {
  test('the configuration becomes the theme the widgets read', () {
    final PlaygroundConfig minimal = PlaygroundConfig.defaults.copyWith(
      theme: PlaygroundTheme.dark,
      accent: 'rose',
      radius: PlaygroundRadius.none,
    );
    final AssistantTheme theme = themeFor(minimal);
    expect(theme.brightness, Brightness.dark);
    expect(theme.bubbleRadius, 0);
    expect(theme.composerRadius, 0);
    expect(theme.cardRadius, 0);
    expect(theme.primary, minimal.swatch.dark);
  });

  testWidgets('a scope publishes its configuration and rebuilds on change', (
    WidgetTester tester,
  ) async {
    final ValueNotifier<PlaygroundConfig> controller =
        ValueNotifier<PlaygroundConfig>(PlaygroundConfig.defaults);
    addTearDown(controller.dispose);
    AssistantTheme? seen;

    await tester.pumpWidget(
      MaterialApp(
        home: PlaygroundScope(
          controller: controller,
          child: Builder(
            builder: (BuildContext context) {
              seen = PlaygroundScope.themeOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    expect(seen!.bubbleRadius, PlaygroundConfig.defaults.cornerRadius);

    controller.value = controller.value.copyWith(radius: PlaygroundRadius.full);
    await tester.pump();
    expect(seen!.bubbleRadius, 999);
  });
}
