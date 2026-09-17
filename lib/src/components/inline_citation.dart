import 'package:flutter/material.dart';

import 'sources.dart' show SourceRef;
import 'surfaces.dart';
import 'theme.dart';

/// Prose with numbered citation chips that preview their source — the
/// `inline-citation` element.
///
/// Upstream hardcodes the sentence and drops two citations into it; the port
/// takes the segments instead, and puts citation `n` after segment `n`, so
/// any text can carry them.
class AssistantInlineCitation extends StatelessWidget {
  const AssistantInlineCitation({
    super.key,
    this.segments = const <String>[],
    required this.sources,
    this.openIndex,
    this.onOpenIndexChange,
  });

  /// Text pieces; citation chips follow each piece, in order.
  final List<String> segments;

  final List<SourceRef> sources;

  /// Which preview is open; null for none.
  final int? openIndex;
  final ValueChanged<int?>? onOpenIndexChange;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final TextStyle body = TextStyle(
      fontSize: 14,
      height: 1.55,
      color: auiFg(theme, 0.9),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              for (final (int index, String segment) in segments.indexed) ...[
                Text(segment, style: body),
                if (index < sources.length)
                  _CitationChip(
                    index: index,
                    source: sources[index],
                    open: openIndex == index,
                    onOpenChange: (bool open) =>
                        onOpenIndexChange?.call(open ? index : null),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CitationChip extends StatefulWidget {
  const _CitationChip({
    required this.index,
    required this.source,
    required this.open,
    required this.onOpenChange,
  });

  final int index;
  final SourceRef source;
  final bool open;
  final ValueChanged<bool> onOpenChange;

  @override
  State<_CitationChip> createState() => _CitationChipState();
}

class _CitationChipState extends State<_CitationChip> {
  final LayerLink _link = LayerLink();
  final OverlayPortalController _controller = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    if (widget.open) {
      // The overlay is not mounted during initState.
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }
  }

  @override
  void didUpdateWidget(_CitationChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.open != widget.open) {
      // `didUpdateWidget` runs inside the build phase, where the portal
      // controller refuses to change state.
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }
  }

  void _sync() {
    if (!mounted) return;
    if (widget.open) {
      _controller.show();
    } else {
      _controller.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _controller,
        overlayChildBuilder: (BuildContext context) => CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.topCenter,
          followerAnchor: Alignment.bottomCenter,
          offset: const Offset(0, -8),
          child: Align(
            alignment: Alignment.topLeft,
            child: _Preview(source: widget.source),
          ),
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => widget.onOpenChange(true),
          onExit: (_) => widget.onOpenChange(false),
          child: GestureDetector(
            onTap: () => widget.onOpenChange(!widget.open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                constraints: const BoxConstraints(minWidth: 16),
                height: 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.open ? theme.foreground : auiFg(theme, 0.06),
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '${widget.index + 1}',
                  style: auiMono(
                    context,
                    size: 10,
                    color: widget.open ? theme.background : auiFg(theme, 0.45),
                    weight: FontWeight.w500,
                  ).copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.source});

  final SourceRef source;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      width: 256,
      decoration: auiPaper(theme, radius: 16),
      padding: const EdgeInsets.all(14),
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
          const SizedBox(height: 8),
          Text(
            source.title,
            style: TextStyle(
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w500,
              color: theme.foreground,
            ),
          ),
          if (source.snippet.isNotEmpty) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              source.snippet,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: auiFg(theme, 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
