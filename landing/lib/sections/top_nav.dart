import 'package:flutter/material.dart';

import '../landing_theme.dart';
import '../widgets.dart';

/// Sticky top navigation: logo, section links with dropdowns, the search and
/// Ask AI chips, and the Cloud call to action.
class TopNav extends StatefulWidget {
  const TopNav({
    super.key,
    required this.openMenu,
    required this.onMenu,
    required this.onMenuCloseRequest,
  });

  /// The label whose panel is showing, if any. The panel itself is rendered
  /// by the page above the scroll view: a pinned header paints the sections
  /// that follow over anything its child overflows.
  final String? openMenu;

  /// Opens a panel, with the anchor rectangle of the item that opened it.
  final void Function(String label, Rect anchor) onMenu;

  /// The pointer left an item; the page decides when to actually close.
  final VoidCallback onMenuCloseRequest;

  @override
  State<TopNav> createState() => _TopNavState();
}

/// The dropdowns, grouped the way the live nav groups them: a heading
/// followed by its entries.
  /// The dropdowns, grouped the way the live nav groups them: a heading
  /// followed by its entries.
const Map<String, List<(String?, List<(String, String)>)>> kNavMenus =
    <String, List<(String?, List<(String, String)>)>>{
  'Products': <(String?, List<(String, String)>)>[
      (
        'Platforms',
        <(String, String)>[
          ('Docs', 'Guides and API reference'),
          ('React', 'The browser package'),
          ('React Native', 'Chat UI for Expo and bare RN'),
          ('Ink', 'Terminal chat for React Ink'),
          ('Hosted', 'Managed backend'),
          ('Cloud', 'Threads, persistence, analytics'),
          ('Playground', 'Try it in the browser'),
        ],
      ),
      (
        'Primitives',
        <(String, String)>[
          ('tw-shimmer', 'Tailwind shimmer for loading states'),
          ('Heat Graph', 'Contribution-style activity grid'),
          ('Safe Content Frame', 'Sandboxed embeds'),
          ('react-o11y', 'OpenTelemetry for React'),
        ],
      ),
    ],
  'Resources': <(String?, List<(String, String)>)>[
      (
        'Learn',
        <(String, String)>[('Interactive course', 'Build an assistant step by step')],
      ),
      (
        null,
        <(String, String)>[
          ('Changelog', 'Every release'),
          ('Showcase', 'What people shipped'),
        ],
      ),
      (
        'Open source',
        <(String, String)>[
          ('Packages', 'The runtime, the store, the UI'),
          ('OSS', 'MIT licensed core'),
        ],
      ),
      (
        'Company',
        <(String, String)>[
          ('Blog', 'Notes from the team'),
          ('Careers', 'Open roles'),
          ('Brand', 'Logos and assets'),
          ('Traction', 'Where we are'),
        ],
      ),
      (
        null,
        <(String, String)>[('Status', 'Live uptime')],
      ),
    ],
  };

class _TopNavState extends State<TopNav> {

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.background.withValues(alpha: 0.85),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          final bool showLinks = width >= 1020;
          final bool showChips = width >= 880;
          return ContentColumn(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              height: 48,
              child: Row(
                children: <Widget>[
                  const _Wordmark(),
                  if (showLinks) ...<Widget>[
                    const Spacer(),
                    for (final String label in <String>[
                      'Docs',
                      'Products',
                      'Resources',
                      'Pricing',
                    ])
                      _NavItem(
                        label: label,
                        menu: kNavMenus[label],
                        open: widget.openMenu == label,
                        onOpen: widget.onMenu,
                        onCloseRequest: widget.onMenuCloseRequest,
                      ),
                  ],
                  const Spacer(),
                  if (showChips) ...<Widget>[
                    const _KeyChip(
                      icon: Icons.search,
                      label: 'Search',
                      shortcut: '⌘K',
                    ),
                    const SizedBox(width: 8),
                    const _KeyChip(
                      icon: Icons.auto_awesome,
                      label: 'Ask AI',
                      shortcut: '⌘I',
                    ),
                    const SizedBox(width: 10),
                  ] else ...<Widget>[
                    Icon(Icons.search, size: 16, color: colors.mutedForeground),
                    const SizedBox(width: 14),
                  ],
                  LandingButton(
                    label: 'Cloud',
                    solid: true,
                    compact: true,
                    onPressed: () {},
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

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return Row(
      children: <Widget>[
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            border: Border.all(color: colors.foreground, width: 1.6),
          ),
          child: Icon(Icons.auto_awesome, size: 13, color: colors.foreground),
        ),
        const SizedBox(width: 9),
        Text(
          'assistant-ui',
          style: LandingText.body(context).copyWith(
            fontWeight: FontWeight.w600,
            color: colors.foreground,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.label,
    required this.menu,
    required this.open,
    required this.onOpen,
    required this.onCloseRequest,
  });

  final String label;
  final List<(String?, List<(String, String)>)>? menu;
  final bool open;
  final void Function(String label, Rect anchor) onOpen;
  final VoidCallback onCloseRequest;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  void _open() {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;
    widget.onOpen(widget.label, box.localToGlobal(Offset.zero) & box.size);
  }

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    final List<(String?, List<(String, String)>)>? menu = widget.menu;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      // The live nav opens on hover and keeps the click toggle as a fallback.
      onEnter: (_) {
        setState(() => _hovered = true);
        if (menu != null) _open();
      },
      onExit: (_) {
        setState(() => _hovered = false);
        if (menu != null) widget.onCloseRequest();
      },
      child: GestureDetector(
        onTap: () {
          if (widget.open) {
            widget.onCloseRequest();
          } else {
            _open();
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.label,
                style: LandingText.body(context).copyWith(
                  color: _hovered || widget.open
                      ? colors.foreground
                      : colors.mutedForeground,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (menu != null) ...<Widget>[
                const SizedBox(width: 3),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 14,
                  color: colors.mutedForeground,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The panel for an open nav label, rendered above the page content.
class NavMenuPanel extends StatelessWidget {
  const NavMenuPanel({
    super.key,
    required this.label,
    this.onEnter,
    this.onExit,
  });

  final String label;
  final VoidCallback? onEnter;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final List<(String?, List<(String, String)>)>? items = kNavMenus[label];
    if (items == null) return const SizedBox.shrink();
    return MouseRegion(
      onEnter: (_) => onEnter?.call(),
      onExit: (_) => onExit?.call(),
      child: _Dropdown(items: items),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.items});

  final List<(String?, List<(String, String)>)> items;

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return Container(
      width: 300,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: colors.isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final (String? group, List<(String, String)> entries) in items)
            ...<Widget>[
              if (group != null)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 14,
                    right: 14,
                    top: 10,
                    bottom: 4,
                  ),
                  child: Text(
                    group.toUpperCase(),
                    style: LandingText.eyebrow(context).copyWith(
                      color: colors.mutedForeground,
                      fontSize: 10,
                    ),
                  ),
                ),
              for (final (String title, String subtitle) in entries)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: LandingText.small(context).copyWith(
                          color: colors.foreground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: LandingText.small(context).copyWith(
                          color: colors.mutedForeground,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
        ],
      ),
    );
  }
}

class _KeyChip extends StatelessWidget {
  const _KeyChip({required this.icon, required this.label, required this.shortcut});

  final IconData icon;
  final String label;
  final String shortcut;

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: colors.mutedForeground),
          const SizedBox(width: 6),
          Text(
            label,
            style: LandingText.small(context).copyWith(color: colors.mutedForeground),
          ),
          const SizedBox(width: 8),
          Text(
            shortcut,
            style: LandingText.mono(context, size: 11)
                .copyWith(color: colors.mutedForeground),
          ),
        ],
      ),
    );
  }
}
