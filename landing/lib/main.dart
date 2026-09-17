import 'dart:async';

import 'package:flutter/material.dart';

import 'landing_theme.dart';
import 'sections/demo_panel.dart';
import 'sections/get_started.dart';
import 'sections/hero.dart';
import 'sections/installs.dart';
import 'sections/primitives_section.dart';
import 'sections/runtime_handles.dart';
import 'sections/site_footer.dart';
import 'sections/top_nav.dart';
import 'sections/trusted_by.dart';

void main() => runApp(const LandingApp());

/// One-to-one Flutter replica of `https://www.assistant-ui.com/`.
///
/// The page is a single scroll view: a pinned header, the hero, and the
/// section stack. Dark is the default, matching the live site.
class LandingApp extends StatefulWidget {
  const LandingApp({super.key});

  @override
  State<LandingApp> createState() => _LandingAppState();
}

class _LandingAppState extends State<LandingApp> {
  /// `?theme=light` deep-links straight into the light palette.
  ThemeMode _mode = Uri.base.queryParameters['theme'] == 'light'
      ? ThemeMode.light
      : ThemeMode.dark;

  /// The open nav panel: a pinned header paints its own sections over a
  /// dropdown it overflows, so the panel is lifted above the scroll view.
  String? _menu;
  Rect? _menuAnchor;
  Timer? _menuClose;

  void _openMenu(String label, Rect anchor) {
    _menuClose?.cancel();
    setState(() {
      _menu = label;
      _menuAnchor = anchor;
    });
  }

  /// The pointer left the trigger; a short grace period lets it reach the
  /// panel before the menu closes.
  void _closeMenuSoon() {
    _menuClose?.cancel();
    _menuClose = Timer(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      setState(() {
        _menu = null;
        _menuAnchor = null;
      });
    });
  }

  @override
  void dispose() {
    _menuClose?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'assistant-ui · The frontend library for AI agents',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: LandingColors.light.background,
        fontFamily: LandingText.sans,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: LandingColors.dark.background,
        fontFamily: LandingText.sans,
      ),
      themeMode: _mode,
      home: Builder(
        builder: (BuildContext context) {
          final LandingColors colors = _mode == ThemeMode.dark
              ? LandingColors.dark
              : LandingColors.light;
          return LandingPalette(
            colors: colors,
            child: Scaffold(
            backgroundColor: colors.background,
            body: Stack(
              children: <Widget>[
                CustomScrollView(
              slivers: <Widget>[
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedHeader(
                    height: 48,
                    child: TopNav(
                      openMenu: _menu,
                      onMenu: _openMenu,
                      onMenuCloseRequest: _closeMenuSoon,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: HeroSection()),
                const SliverToBoxAdapter(child: _DemoBlock()),
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
                const SliverToBoxAdapter(child: InstallsSection()),
                const SliverToBoxAdapter(child: RuntimeHandlesSection()),
                const SliverToBoxAdapter(child: PrimitivesSection()),
                const SliverToBoxAdapter(child: TrustedBySection()),
                const SliverToBoxAdapter(child: GetStartedSection()),
                SliverToBoxAdapter(
                  child: SiteFooter(
                    isDark: _mode == ThemeMode.dark,
                    onToggleTheme: () => setState(() {
                      _mode = _mode == ThemeMode.dark
                          ? ThemeMode.light
                          : ThemeMode.dark;
                    }),
                  ),
                ),
              ],
                ),
                if (_menu != null && _menuAnchor != null)
                  Positioned(
                    left: _menuAnchor!.left,
                    top: _menuAnchor!.bottom + 8,
                    child: NavMenuPanel(
                      key: ValueKey<String>(_menu!),
                      label: _menu!,
                      onEnter: () => _menuClose?.cancel(),
                      onExit: _closeMenuSoon,
                    ),
                  ),
              ],
            ),
          ),
          );
        },
      ),
    );
  }
}

class _PinnedHeader extends SliverPersistentHeaderDelegate {
  const _PinnedHeader({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(
        color: LandingColors.of(context).background,
        child: child,
      );

  @override
  bool shouldRebuild(_PinnedHeader oldDelegate) => oldDelegate.child != child;
}

/// The demo sits in the same content column as the rest of the page.
class _DemoBlock extends StatelessWidget {
  const _DemoBlock();

  @override
  Widget build(BuildContext context) => const DemoPanel();
}
