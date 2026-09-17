import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// A cited page.
@immutable
class SourceRef {
  const SourceRef({
    required this.domain,
    required this.title,
    this.snippet = '',
  });

  final String domain;
  final String title;

  /// Preview text, used by the inline citation element.
  final String snippet;
}

/// A pill that opens the list of sources behind an answer — the `sources`
/// element.
class AssistantSources extends StatefulWidget {
  const AssistantSources({
    super.key,
    required this.sources,
    this.open,
    this.onOpenChange,
    this.initiallyOpen = false,
  });

  final List<SourceRef> sources;

  /// Bound open state; when null the widget owns it from [initiallyOpen].
  final bool? open;
  final ValueChanged<bool>? onOpenChange;
  final bool initiallyOpen;

  @override
  State<AssistantSources> createState() => _AssistantSourcesState();
}

class _AssistantSourcesState extends State<AssistantSources> {
  late bool _open = widget.open ?? widget.initiallyOpen;

  @override
  void didUpdateWidget(AssistantSources oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open != null) _open = widget.open!;
  }

  void _toggle() {
    final bool next = !_open;
    if (widget.open == null) setState(() => _open = next);
    widget.onOpenChange?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _Trigger(
              count: widget.sources.length,
              open: _open,
              onTap: _toggle,
            ),
            if (_open)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final SourceRef source in widget.sources)
                      _SourceCard(source: source, theme: theme),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Trigger extends StatefulWidget {
  const _Trigger({
    required this.count,
    required this.open,
    required this.onTap,
  });

  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  State<_Trigger> createState() => _TriggerState();
}

class _TriggerState extends State<_Trigger> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Semantics(
          button: true,
          expanded: widget.open,
          label: 'Sources, ${widget.count}',
          child: Container(
            decoration: BoxDecoration(
              color: _hovered
                  ? auiFg(theme, 0.07)
                  : auiFieldColor(theme),
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Sources',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.2,
                    color: auiFg(theme, _hovered ? 0.9 : 0.6),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.count}',
                  style: auiMono(context, color: auiFg(theme, 0.35)).copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: widget.open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.expand_more,
                    size: 12,
                    color: auiFg(theme, 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.source, required this.theme});

  final SourceRef source;
  final AssistantTheme theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 184),
      decoration: auiPaper(theme, radius: 16),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 16,
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: auiFg(theme, 0.06),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  source.domain.isEmpty
                      ? '?'
                      : source.domain[0].toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    height: 1,
                    fontWeight: FontWeight.w500,
                    color: auiFg(theme, 0.45),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  source.domain,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: auiMono(context, color: auiFg(theme, 0.4)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            source.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w500,
              color: auiFg(theme, 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
