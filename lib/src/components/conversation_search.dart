import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One match inside a conversation.
@immutable
class SearchHit {
  const SearchHit({
    required this.id,
    required this.before,
    required this.match,
    required this.after,
    required this.position,
  });

  final String id;

  /// Text around the match, kept verbatim so the excerpt reads naturally.
  final String before;
  final String match;
  final String after;

  /// Where in the conversation the hit sits, 0..100, for the rail marks.
  final double position;
}

/// Find-in-conversation: a query field, the hit count, stepping and a rail of
/// match marks — the `conversation-search` element.
class AssistantConversationSearch extends StatefulWidget {
  const AssistantConversationSearch({
    super.key,
    required this.hits,
    this.query = '',
    this.activeIndex = 0,
    this.onQueryChange,
    this.onStep,
  });

  final List<SearchHit> hits;

  /// Bound query; when null the field owns its text.
  final String query;

  final int activeIndex;

  final ValueChanged<String>? onQueryChange;

  /// Called with -1 / +1 by the step controls; without it they are hidden.
  final ValueChanged<int>? onStep;

  @override
  State<AssistantConversationSearch> createState() =>
      _AssistantConversationSearchState();
}

class _AssistantConversationSearchState
    extends State<AssistantConversationSearch> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.query);

  @override
  void didUpdateWidget(AssistantConversationSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != _controller.text) {
      _controller.text = widget.query;
      _controller.selection =
          TextSelection.collapsed(offset: widget.query.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final int index = widget.hits.isEmpty
        ? -1
        : widget.activeIndex.clamp(0, widget.hits.length - 1);
    final SearchHit? active = index == -1 ? null : widget.hits[index];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    decoration: auiPaper(theme, radius: 999),
                    padding: const EdgeInsets.only(
                      left: 12,
                      right: 6,
                      top: 6,
                      bottom: 6,
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.search,
                          size: 14,
                          color: auiFg(theme, 0.3),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            onChanged: widget.onQueryChange,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.3,
                              color: auiFg(theme, 0.85),
                            ),
                            cursorColor: theme.foreground,
                            decoration: InputDecoration(
                              isDense: true,
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: 'Find in conversation',
                              hintStyle: TextStyle(
                                fontSize: 13,
                                color: auiFg(theme, 0.3),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.hits.isEmpty
                              ? '0'
                              : '${index + 1}/${widget.hits.length}',
                          style: auiMono(context, color: auiFg(theme, 0.3))
                              .copyWith(
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        if (widget.onStep != null) ...<Widget>[
                          AuiIconAction(
                            icon: Icons.keyboard_arrow_up,
                            label: 'Previous match',
                            size: 24,
                            onPressed: () => widget.onStep!(-1),
                          ),
                          AuiIconAction(
                            icon: Icons.keyboard_arrow_down,
                            label: 'Next match',
                            size: 24,
                            onPressed: () => widget.onStep!(1),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (active != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Container(
                      decoration: auiField(theme, radius: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: auiFg(theme, 0.45),
                          ),
                          children: <TextSpan>[
                            TextSpan(text: active.before),
                            TextSpan(
                              text: active.match,
                              style: TextStyle(
                                color: auiFg(theme, 0.95),
                                background: Paint()
                                  ..color = const Color(0xFFFBBF24)
                                      .withValues(alpha: 0.35),
                              ),
                            ),
                            TextSpan(text: active.after),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 6,
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return Stack(
                    children: <Widget>[
                      Container(
                        width: 6,
                        height: constraints.maxHeight,
                        decoration: BoxDecoration(
                          color: auiFg(theme, 0.04),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      for (final (int i, SearchHit hit) in widget.hits.indexed)
                        Positioned(
                          top: hit.position.clamp(0, 100) /
                              100 *
                              (constraints.maxHeight - 4),
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(
                                alpha: i == index
                                    ? 1
                                    : (dark ? 0.35 : 0.35),
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
