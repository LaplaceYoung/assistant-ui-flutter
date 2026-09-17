import 'package:flutter/material.dart';

import '../landing_theme.dart';
import '../widgets.dart';

/// Site footer: the six link columns, the legal row, the status pill, the
/// social icons and the theme toggle.
class SiteFooter extends StatelessWidget {
  const SiteFooter({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  final bool isDark;
  final VoidCallback onToggleTheme;

  static const List<(String, List<String>)> _columns = <(String, List<String>)>[
    ('Library', <String>['Docs', 'Changelog', 'Playground']),
    ('Platforms', <String>['React', 'React Native', 'Ink']),
    ('Extend', <String>['Elements', 'Design']),
    ('Primitives', <String>['tw-shimmer', 'Heat Graph', 'Safe Content Frame', 'react-o11y']),
    ('Resources', <String>['Examples', 'Showcase', 'Open source', 'Packages']),
    ('Company', <String>['Blog', 'Careers', 'Brand', 'Traction', 'Pricing']),
  ];

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return ContentColumn(
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.border)),
        ),
        padding: const EdgeInsets.only(top: 44, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 56,
              runSpacing: 28,
              children: <Widget>[
                for (final (String title, List<String> links) in _columns)
                  SizedBox(
                    width: 150,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title.toUpperCase(),
                          style: LandingText.eyebrow(context).copyWith(
                            color: colors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 14),
                        for (final String link in links)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 9),
                            child: _FooterLink(label: link),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 44),
            Container(height: 1, color: colors.border),
            const SizedBox(height: 18),
            // The legal row and the status row sit side by side on desktop and
            // stack under each other below that, like the live page.
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Widget legal = Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      '©2026 Agentbase AI Inc.',
                      style: LandingText.small(context)
                          .copyWith(color: colors.mutedForeground),
                    ),
                    const SizedBox(width: 10),
                    Text('·', style: TextStyle(color: colors.mutedForeground)),
                    const SizedBox(width: 10),
                    _FooterLink(label: 'Privacy'),
                    const SizedBox(width: 10),
                    Text('·', style: TextStyle(color: colors.mutedForeground)),
                    const SizedBox(width: 10),
                    _FooterLink(label: 'Terms'),
                    const SizedBox(width: 10),
                    Text('·', style: TextStyle(color: colors.mutedForeground)),
                    const SizedBox(width: 10),
                    _FooterLink(label: 'Cookie settings'),
                  ],
                );

                final Widget status = Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 14,
                  runSpacing: 10,
                  children: <Widget>[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF3FB950),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'All systems operational',
                          style: LandingText.small(context)
                              .copyWith(color: colors.mutedForeground),
                        ),
                      ],
                    ),
                    for (final IconData icon in <IconData>[
                      Icons.close,
                      Icons.code,
                      Icons.forum_outlined,
                    ])
                      Icon(icon, size: 15, color: colors.mutedForeground),
                    _ThemeToggle(isDark: isDark, onToggle: onToggleTheme),
                  ],
                );

                if (constraints.maxWidth < 1100) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      legal,
                      const SizedBox(height: 18),
                      status,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(child: legal),
                    status,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterLink extends StatefulWidget {
  const _FooterLink({required this.label});

  final String label;

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {},
        child: Text(
          widget.label,
          style: LandingText.small(context).copyWith(
            color: colors.mutedForeground,
            decoration: _hovered ? TextDecoration.underline : null,
            decorationColor: colors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

/// Moon/sun control at the end of the status row.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.isDark, required this.onToggle});

  final bool isDark;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: const Key('landing-theme-toggle'),
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: Tooltip(
          message: isDark ? 'Switch to light' : 'Switch to dark',
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              isDark ? Icons.dark_mode : Icons.light_mode_outlined,
              size: 16,
              color: colors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
