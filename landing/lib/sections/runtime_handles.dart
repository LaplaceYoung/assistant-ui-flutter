import 'dart:async';

import 'package:flutter/material.dart';

import '../landing_theme.dart';
import '../widgets.dart';
import 'showcase_demos.dart';

/// `WHAT THE RUNTIME HANDLES` — the numbered 01–10 list on the left and the
/// live preview panel on the right.
class RuntimeHandlesSection extends StatefulWidget {
  const RuntimeHandlesSection({super.key});

  @override
  State<RuntimeHandlesSection> createState() => _RuntimeHandlesSectionState();
}

class _RuntimeHandlesSectionState extends State<RuntimeHandlesSection> {
  /// Matches the live showcase's slot timing.
  static const Duration _slot = Duration(milliseconds: 7000);

  int _active = 0;
  bool _held = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_slot, (_) {
      if (!mounted || _held) return;
      setState(() => _active = (_active + 1) % _items.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static const List<(String, String, String)> _items = <(String, String, String)>[
    ('Streaming', 'Tokens land as they arrive', 'Here is what changed in the latest release: the runtime now streams partial tool calls.'),
    ('Reasoning', 'Thinking shown while it happens', 'Reasoning parts render in a disclosure that follows the running part.'),
    ('Tools', 'Calls executed for you', 'The runtime runs each tool and feeds the result back in a continuation run.'),
    ('Approval', 'Humans in the loop', 'Tool calls that need a human pause the run until a result arrives.'),
    ('Sources', 'Citations with links', 'Source parts render as favicon links, file badges, or inline citations.'),
    ('Attachments', 'Files in and out', 'Composer attachments upload with progress and become message parts.'),
    ('Branching', 'Every version kept', 'Regenerating or editing adds a branch instead of dropping the answer.'),
    ('Suggestions', 'Follow-ups offered', 'Suggested prompts come from the runtime and drop straight into the composer.'),
    ('Voice', 'Dictation and speech', 'Adapters wire dictation and read-aloud into the same action bar.'),
    ('Generative UI', 'The model composes UI', 'Structured output renders through a component vocabulary you ship.'),
  ];

  @override
  Widget build(BuildContext context) {
    final (String title, String subtitle, String preview) = _items[_active];

    return ContentColumn(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Eyebrow('What the runtime handles'),
            const SizedBox(height: 26),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool wide = constraints.maxWidth >= 980;
                final Widget list = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    for (int i = 0; i < _items.length; i++)
                      _HandleRow(
                        index: i + 1,
                        title: _items[i].$1,
                        subtitle: _items[i].$2,
                        active: i == _active,
                        onEnter: () => setState(() {
                          _active = i;
                          _held = true;
                        }),
                      ),
                  ],
                );
                final Widget panel = _PreviewPanel(
                  title: title,
                  subtitle: subtitle,
                  demo: DemoSlot(index: _active),
                );
                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      list,
                      const SizedBox(height: 28),
                      panel,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(flex: 5, child: list),
                    const SizedBox(width: 56),
                    Expanded(flex: 6, child: panel),
                  ],
                );
              },
            ),
            const SizedBox(height: 26),
            const ArrowLink(label: 'All elements'),
          ],
        ),
      ),
    );
  }
}

class _HandleRow extends StatefulWidget {
  const _HandleRow({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.active,
    required this.onEnter,
  });

  final int index;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onEnter;

  @override
  State<_HandleRow> createState() => _HandleRowState();
}

class _HandleRowState extends State<_HandleRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    final bool lit = widget.active || _hovered;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() => _hovered = true);
        widget.onEnter();
      },
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            SizedBox(
              width: 34,
              child: Text(
                widget.index.toString().padLeft(2, '0'),
                style: LandingText.mono(context, size: 11).copyWith(
                  color: lit ? colors.foreground : colors.mutedForeground,
                ),
              ),
            ),
            Text(
              widget.title,
              style: LandingText.body(context).copyWith(
                fontSize: 16,
                color: lit ? colors.foreground : colors.mutedForeground,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                widget.subtitle,
                style: LandingText.small(context).copyWith(
                  color: colors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The panel that previews the hovered capability.
class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({
    required this.title,
    required this.subtitle,
    required this.demo,
  });

  final String title;
  final String subtitle;

  /// The live element for the active act.
  final Widget demo;

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 320),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                title,
                style: LandingText.body(context).copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: colors.border),
                ),
                child: Text(
                  'LIVE',
                  style: LandingText.mono(context, size: 10)
                      .copyWith(color: colors.mutedForeground),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: LandingText.small(context).copyWith(color: colors.mutedForeground),
          ),
          const SizedBox(height: 20),
          demo,
        ],
      ),
    );
  }
}
