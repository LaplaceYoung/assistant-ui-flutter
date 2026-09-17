import 'package:flutter/material.dart';

import '../landing_theme.dart';
import '../widgets.dart';

/// `GET STARTED` — "Start in the docs." with the command chip and the two
/// calls to action.
class GetStartedSection extends StatelessWidget {
  const GetStartedSection({super.key});

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return ContentColumn(
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.border)),
        ),
        padding: const EdgeInsets.only(top: 56, bottom: 64),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= 900;
            final Widget copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Eyebrow('Get started'),
                const SizedBox(height: 16),
                Text(
                  'Start in the docs.',
                  style: LandingText.sectionTitle(context).copyWith(
                    color: colors.foreground,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 330),
                  child: Text(
                    'The command scaffolds a working thread. The docs take it '
                    'from there.',
                    style: LandingText.body(context).copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                ),
              ],
            );

            final Widget actions = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const CommandChip(command: 'npx assistant-ui init', fontSize: 16),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 14,
                  runSpacing: 12,
                  children: <Widget>[
                    LandingButton(
                      label: 'Read the docs',
                      solid: true,
                      onPressed: () {},
                    ),
                    LandingButton(label: 'Contact sales', onPressed: () {}),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  '@assistant-ui/react · MIT License',
                  style: LandingText.mono(context, size: 11).copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              ],
            );

            if (!wide) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  copy,
                  const SizedBox(height: 30),
                  actions,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(flex: 4, child: copy),
                const SizedBox(width: 40),
                Expanded(flex: 6, child: actions),
              ],
            );
          },
        ),
      ),
    );
  }
}
