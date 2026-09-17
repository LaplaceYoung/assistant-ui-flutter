import 'package:assistant_ui/assistant_ui.dart';
import 'package:flutter/material.dart';

import 'playground_config.dart';

/// One configuration for the whole site: the playground edits it, the landing's
/// demo panel renders under it, and the same query keys seed both — so a link
/// one of them shares reproduces the look on the other.
class PlaygroundScope extends InheritedNotifier<ValueNotifier<PlaygroundConfig>> {
  const PlaygroundScope({
    super.key,
    required ValueNotifier<PlaygroundConfig> controller,
    required super.child,
  }) : super(notifier: controller);

  static ValueNotifier<PlaygroundConfig> controllerOf(BuildContext context) {
    final PlaygroundScope? scope =
        context.dependOnInheritedWidgetOfExactType<PlaygroundScope>();
    assert(scope != null, 'No PlaygroundScope above this widget');
    return scope!.notifier!;
  }

  static PlaygroundConfig of(BuildContext context) => controllerOf(context).value;

  /// The configuration as the widgets read it.
  static AssistantTheme themeOf(BuildContext context) =>
      themeFor(of(context));
}

/// The configuration as an [AssistantTheme] — the styles section of the
/// playground, applied.
AssistantTheme themeFor(PlaygroundConfig config) {
  final bool dark = config.theme == PlaygroundTheme.dark;
  final AssistantTheme base = dark ? AssistantTheme.dark : AssistantTheme.light;
  final Color accent = dark ? config.swatch.dark : config.swatch.light;
  return base.copyWith(
    primary: accent,
    bubbleRadius: config.cornerRadius,
    composerRadius: config.cornerRadius,
    cardRadius: config.cornerRadius,
  );
}

/// The body and small text styles the configuration asks for.
AssistantTheme themeWithType(AssistantTheme base, PlaygroundConfig config) =>
    base.copyWith(
      bodyStyle: base.bodyStyle?.copyWith(fontSize: config.fontSize) ??
          TextStyle(fontSize: config.fontSize),
    );
