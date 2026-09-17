import 'package:flutter/material.dart';

/// Colors, radii and text styles the styled components use.
///
/// Defaults track assistant-ui's shadcn neutral theme, so a ported screen
/// looks like the original. Override the whole theme, or wrap part of the tree
/// with [AssistantThemeProvider].
@immutable
class AssistantTheme {
  const AssistantTheme({
    required this.brightness,
    required this.background,
    required this.foreground,
    required this.muted,
    required this.mutedForeground,
    required this.primary,
    required this.primaryForeground,
    required this.border,
    required this.destructive,
    required this.success,
    this.bubbleRadius = 18,
    this.composerRadius = 22,
    this.cardRadius = 12,
    this.bodyStyle,
    this.smallStyle,
    this.codeStyle,
    this.avatarLabel = 'AI',
  });

  final Brightness brightness;

  final Color background;
  final Color foreground;

  /// Fill of assistant bubbles, reasoning cards and other secondary surfaces.
  final Color muted;
  final Color mutedForeground;

  final Color primary;
  final Color primaryForeground;

  final Color border;
  final Color destructive;
  final Color success;

  final double bubbleRadius;
  final double composerRadius;
  final double cardRadius;

  /// Base text style of message bodies.
  final TextStyle? bodyStyle;

  /// Small secondary text, used by the branch picker and tool headers.
  final TextStyle? smallStyle;

  /// Monospace style for inline code and fenced blocks.
  final TextStyle? codeStyle;

  /// Label in the assistant avatar.
  final String avatarLabel;

  static const AssistantTheme light = AssistantTheme(
    brightness: Brightness.light,
    background: Color(0xFFFFFFFF),
    foreground: Color(0xFF0A0A0A),
    muted: Color(0xFFF5F5F5),
    mutedForeground: Color(0xFF737373),
    primary: Color(0xFF171717),
    primaryForeground: Color(0xFFFAFAFA),
    border: Color(0xFFE5E5E5),
    destructive: Color(0xFFE7000B),
    success: Color(0xFF16A34A),
  );

  static const AssistantTheme dark = AssistantTheme(
    brightness: Brightness.dark,
    background: Color(0xFF0A0A0A),
    foreground: Color(0xFFFAFAFA),
    muted: Color(0xFF262626),
    mutedForeground: Color(0xFFA1A1A1),
    primary: Color(0xFFFAFAFA),
    primaryForeground: Color(0xFF171717),
    border: Color(0xFF2E2E2E),
    destructive: Color(0xFFFF6467),
    success: Color(0xFF4ADE80),
  );

  /// Resolves the closest provider, otherwise [light] or [dark] by brightness.
  static AssistantTheme of(BuildContext context) {
    final AssistantTheme? provided =
        context.dependOnInheritedWidgetOfExactType<AssistantThemeProvider>()?.theme;
    if (provided != null) return provided;
    final Brightness brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? dark : light;
  }

  TextStyle body(BuildContext context) =>
      bodyStyle ??
      TextStyle(
        fontSize: 14,
        height: 1.55,
        color: foreground,
        fontWeight: FontWeight.w400,
      );

  TextStyle small(BuildContext context) =>
      smallStyle ??
      TextStyle(
        fontSize: 12,
        height: 1.4,
        color: mutedForeground,
      );

  TextStyle code(BuildContext context) =>
      codeStyle ??
      TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: const <String>['Menlo', 'Consolas', 'Courier'],
        fontSize: 13,
        height: 1.5,
        color: foreground,
      );

  AssistantTheme copyWith({
    Brightness? brightness,
    Color? background,
    Color? foreground,
    Color? muted,
    Color? mutedForeground,
    Color? primary,
    Color? primaryForeground,
    Color? border,
    Color? destructive,
    Color? success,
    double? bubbleRadius,
    double? composerRadius,
    double? cardRadius,
    TextStyle? bodyStyle,
    TextStyle? smallStyle,
    TextStyle? codeStyle,
    String? avatarLabel,
  }) {
    return AssistantTheme(
      brightness: brightness ?? this.brightness,
      background: background ?? this.background,
      foreground: foreground ?? this.foreground,
      muted: muted ?? this.muted,
      mutedForeground: mutedForeground ?? this.mutedForeground,
      primary: primary ?? this.primary,
      primaryForeground: primaryForeground ?? this.primaryForeground,
      border: border ?? this.border,
      destructive: destructive ?? this.destructive,
      success: success ?? this.success,
      bubbleRadius: bubbleRadius ?? this.bubbleRadius,
      composerRadius: composerRadius ?? this.composerRadius,
      cardRadius: cardRadius ?? this.cardRadius,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      smallStyle: smallStyle ?? this.smallStyle,
      codeStyle: codeStyle ?? this.codeStyle,
      avatarLabel: avatarLabel ?? this.avatarLabel,
    );
  }
}

/// Overrides [AssistantTheme] for the widgets below it.
class AssistantThemeProvider extends InheritedWidget {
  const AssistantThemeProvider({
    super.key,
    required this.theme,
    required super.child,
  });

  final AssistantTheme theme;

  static AssistantTheme of(BuildContext context) => AssistantTheme.of(context);

  @override
  bool updateShouldNotify(AssistantThemeProvider oldWidget) =>
      theme != oldWidget.theme;
}
