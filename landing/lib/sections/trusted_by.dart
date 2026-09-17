import 'package:flutter/material.dart';

import '../landing_theme.dart';
import '../widgets.dart';

/// Social proof: the ecosystems sentence, the logo wall and the three quotes.
class TrustedBySection extends StatelessWidget {
  const TrustedBySection({super.key});

  static const List<(String, IconData?)> _logosRow1 = <(String, IconData?)>[
    ('mastra', Icons.blur_on),
    ('Google Cloud', Icons.cloud_outlined),
    ('Paperclip', Icons.attach_file),
    ('Neon', Icons.bolt_outlined),
    ('AgentOps', Icons.hub_outlined),
  ];

  static const List<(String, IconData?)> _logosRow2 = <(String, IconData?)>[
    ('thesys', Icons.terminal),
    ('voltagent', Icons.electric_bolt_outlined),
    ('ONLYOFFICE', Icons.description_outlined),
    ('unsloth', Icons.speed_outlined),
  ];

  static const List<(String, String)> _quotes = <(String, String)>[
    (
      'Build stateful conversational AI agents with LangGraph and assistant-ui.',
      '@LangChainAI',
    ),
    (
      'Conversations and streaming AI output are powered by @assistantui. It '
      'renders the chat interface and stores threads in Assistant UI Cloud so '
      'sessions persist across refreshes and context builds over time.',
      '@neondatabase',
    ),
    (
      'Pleasure to work with Simon… bring streaming, gen UI, and '
      'human-in-the-loop with LangGraph Cloud + assistant-ui.',
      '@hwchase17',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return ContentColumn(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Text.rich(
                TextSpan(
                  style: LandingText.lead(context).copyWith(
                    color: colors.mutedForeground,
                    fontSize: 15,
                  ),
                  children: const <InlineSpan>[
                    TextSpan(text: 'Works with '),
                    TextSpan(
                      text: 'AI SDK',
                      style: TextStyle(color: Color(0xFFFAFAF9)),
                    ),
                    TextSpan(text: ', '),
                    TextSpan(text: 'LangGraph', style: TextStyle(color: Color(0xFFFAFAF9))),
                    TextSpan(text: ', and '),
                    TextSpan(text: 'LangChain', style: TextStyle(color: Color(0xFFFAFAF9))),
                    TextSpan(
                      text: ', or any backend through adapters. Ships for React, '
                          'Native, and Ink. Elements extends it. Cloud hosts '
                          'threads and persistence when you want them.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 42),
            Wrap(
              spacing: 56,
              runSpacing: 26,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                for (final (String name, IconData? icon) in _logosRow1)
                  LogoMark(name: name, mark: icon, emphasizeWord: name.contains(' ')),
              ],
            ),
            const SizedBox(height: 30),
            Wrap(
              spacing: 56,
              runSpacing: 26,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                for (final (String name, IconData? icon) in _logosRow2)
                  LogoMark(name: name, mark: icon, emphasizeWord: name.contains(' ')),
              ],
            ),
            const SizedBox(height: 54),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool wide = constraints.maxWidth >= 900;
                final List<Widget> cards = <Widget>[
                  for (final (String text, String handle) in _quotes)
                    SizedBox(
                      width: wide ? (constraints.maxWidth - 80) / 3 : constraints.maxWidth,
                      child: QuoteCard(text: text, handle: handle, width: double.infinity),
                    ),
                ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(spacing: 40, runSpacing: 26, children: cards),
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
