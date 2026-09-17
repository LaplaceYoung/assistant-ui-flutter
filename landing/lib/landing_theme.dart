import 'package:flutter/material.dart';

/// Landing palette, resolved from the live site's OKLCH tokens.
///
/// See `docs/landing/theme.md` for the source values and the conversion.
/// `--tint: 106` keeps every neutral slightly warm, which is why the greys
/// read as `#fcfcfb` / `#0f0f0e` rather than pure values.
@immutable
class LandingColors {
  const LandingColors({
    required this.background,
    required this.foreground,
    required this.card,
    required this.muted,
    required this.mutedForeground,
    required this.primary,
    required this.primaryForeground,
    required this.border,
    required this.accent,
  });

  static const LandingColors light = LandingColors(
    background: Color(0xFFFCFCFB),
    foreground: Color(0xFF0A0A08),
    card: Color(0xFFFCFCFB),
    muted: Color(0xFFF5F5F2),
    mutedForeground: Color(0xFF74746F),
    primary: Color(0xFF171714),
    primaryForeground: Color(0xFFFAFAF8),
    border: Color(0xFFE5E5E2),
    accent: Color(0xFFE8F0FF),
  );

  static const LandingColors dark = LandingColors(
    background: Color(0xFF0F0F0E),
    foreground: Color(0xFFFAFAF9),
    card: Color(0xFF1A1918),
    muted: Color(0xFF282826),
    mutedForeground: Color(0xFFA1A19E),
    primary: Color(0xFFE5E5E4),
    primaryForeground: Color(0xFF1A1918),
    border: Color(0x1AFAFAF9), // #fafaf9 at 10%
    accent: Color(0xFF1B1B19),
  );

  final Color background;
  final Color foreground;
  final Color card;
  final Color muted;
  final Color mutedForeground;
  final Color primary;
  final Color primaryForeground;
  final Color border;

  /// Soft highlight used by the code block's active line.
  final Color accent;

  bool get isDark => background.computeLuminance() < 0.5;

  /// Tinted code colours, sampled from the site's syntax theme.
  Color get codeKeyword => isDark ? const Color(0xFFC792EA) : const Color(0xFF8250DF);
  Color get codeString => isDark ? const Color(0xFFA5D6A7) : const Color(0xFF0A7B4A);
  Color get codeType => isDark ? const Color(0xFF7FD1E0) : const Color(0xFF0A5F8A);
  Color get codeComment => isDark ? const Color(0xFF6E7681) : const Color(0xFF8B949E);
  Color get codePlain => isDark ? const Color(0xFFCFCFCB) : const Color(0xFF3A3A36);

  /// Reads the palette the app published. Falls back to the system brightness
  /// for widgets rendered outside the landing shell (tests, previews).
  static LandingColors of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LandingPalette>()?.colors ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);
}

/// Publishes the active [LandingColors] to the tree.
///
/// The landing page picks its palette from its own theme state rather than
/// inferring it from Material's brightness, so a mode swap is a single source
/// of truth.
class LandingPalette extends InheritedWidget {
  const LandingPalette({
    super.key,
    required this.colors,
    required super.child,
  });

  final LandingColors colors;

  @override
  bool updateShouldNotify(LandingPalette oldWidget) =>
      colors != oldWidget.colors;
}

/// Typography for the landing page: Public Sans for copy, JetBrains Mono for
/// code and eyebrows.
abstract final class LandingText {
  static const String sans = 'Public Sans';
  static const String monoFamily = 'JetBrains Mono';

  /// Public Sans and JetBrains Mono ship as variable fonts here, so a weight
  /// has to be set through the `wght` axis as well as `fontWeight`.
  static List<FontVariation> weight(int w) =>
      <FontVariation>[FontVariation('wght', w.toDouble())];

  /// Hero display: tight leading, weight 500 at 72px on desktop.
  static TextStyle display(BuildContext context, {double size = 72}) => TextStyle(
        fontFamily: sans,
        fontWeight: FontWeight.w500,
        fontVariations: weight(500),
        height: 1.04,
        fontSize: size,
        letterSpacing: -size * 0.015,
      );

  static TextStyle sectionTitle(BuildContext context) => TextStyle(
        fontFamily: sans,
        fontWeight: FontWeight.w600,
        fontVariations: weight(600),
        fontSize: 34,
        height: 1.15,
        letterSpacing: -0.6,
      );

  static TextStyle lead(BuildContext context) => const TextStyle(
        fontFamily: sans,
        fontSize: 17,
        height: 1.6,
        fontWeight: FontWeight.w400,
      );

  static TextStyle body(BuildContext context) => const TextStyle(
        fontFamily: sans,
        fontSize: 14.5,
        height: 1.6,
        fontWeight: FontWeight.w400,
      );

  static TextStyle small(BuildContext context) => const TextStyle(
        fontFamily: sans,
        fontSize: 13,
        height: 1.5,
        fontWeight: FontWeight.w400,
      );

  /// `WHAT YOU INSTALL` — uppercase, mono, letterspaced.
  static TextStyle eyebrow(BuildContext context) => TextStyle(
        fontFamily: monoFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        fontVariations: weight(500),
        letterSpacing: 1.4,
      );

  static TextStyle mono(BuildContext context, {double size = 13}) => TextStyle(
        fontFamily: monoFamily,
        fontSize: size,
        height: 1.7,
        fontWeight: FontWeight.w400,
        fontVariations: weight(400),
      );

  static TextStyle button(BuildContext context) => TextStyle(
        fontFamily: sans,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        fontVariations: weight(500),
      );

  /// Section width used across the page: `max-w-7xl` with 16px gutters.
  static const double contentMaxWidth = 1280;
  static const double gutter = 16;
}

/// Wraps a landing subtree in the palette.
class LandingTheme extends StatelessWidget {
  const LandingTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}
