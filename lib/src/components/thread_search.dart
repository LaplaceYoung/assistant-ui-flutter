import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One thread the search can match.
@immutable
class SearchableThread {
  const SearchableThread({
    required this.id,
    required this.title,
    required this.group,
    required this.preview,
    this.pinned = false,
  });

  final String id;
  final String title;
  final String group;
  final String preview;
  final bool pinned;
}

/// Search across threads: pinned first, then groups, with the arrow keys
/// stepping the selection — the `thread-search` element.
class AssistantThreadSearch extends StatefulWidget {
  const AssistantThreadSearch({
    super.key,
    required this.threads,
    this.query = '',
    this.activeId = '',
    this.onQueryChange,
    this.onSelect,
  });

  final List<SearchableThread> threads;
  final String query;
  final String activeId;

  final ValueChanged<String>? onQueryChange;

  /// Reports the newly active thread — by arrow key or by tap.
  final ValueChanged<String>? onSelect;

  @override
  State<AssistantThreadSearch> createState() => _AssistantThreadSearchState();
}

class _AssistantThreadSearchState extends State<AssistantThreadSearch> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.query);
  late final FocusNode _focusNode = FocusNode(onKeyEvent: _onKey);

  @override
  void didUpdateWidget(AssistantThreadSearch oldWidget) {
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
    _focusNode.dispose();
    super.dispose();
  }

  List<SearchableThread> get _matches {
    final String needle = widget.query.toLowerCase();
    return widget.threads
        .where((SearchableThread thread) =>
            '${thread.title} ${thread.preview}'.toLowerCase().contains(needle))
        .toList();
  }

  /// Display order: pinned first, then groups in first-match order.
  List<SearchableThread> _ordered(List<SearchableThread> matches) {
    final List<SearchableThread> pinned =
        matches.where((SearchableThread thread) => thread.pinned).toList();
    final List<String> groups = <String>[];
    for (final SearchableThread thread in matches) {
      if (!thread.pinned && !groups.contains(thread.group)) {
        groups.add(thread.group);
      }
    }
    return <SearchableThread>[
      ...pinned,
      for (final String group in groups)
        ...matches.where((SearchableThread thread) =>
            !thread.pinned && thread.group == group),
    ];
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final List<SearchableThread> ordered = _ordered(_matches);
    if (ordered.isEmpty) return KeyEventResult.ignored;
    final int delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => 1,
      LogicalKeyboardKey.arrowUp => -1,
      _ => 0,
    };
    if (delta == 0) return KeyEventResult.ignored;
    final int at = ordered.indexWhere(
      (SearchableThread thread) => thread.id == widget.activeId,
    );
    // The active thread can be filtered out; start from the edge the key implies.
    final int from = at == -1 ? (delta > 0 ? -1 : 0) : at;
    final SearchableThread next =
        ordered[(from + delta + ordered.length) % ordered.length];
    widget.onSelect?.call(next.id);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final List<SearchableThread> matches = _matches;
    final List<SearchableThread> pinned =
        matches.where((SearchableThread thread) => thread.pinned).toList();
    final List<String> groups = <String>[];
    for (final SearchableThread thread in matches) {
      if (!thread.pinned && !groups.contains(thread.group)) {
        groups.add(thread.group);
      }
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                decoration: auiField(theme, radius: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.search, size: 14, color: auiFg(theme, 0.3)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
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
                          hintText: 'Search threads',
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: auiFg(theme, 0.3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              if (pinned.isNotEmpty) ...<Widget>[
                _GroupLabel(label: 'pinned'),
                for (final SearchableThread thread in pinned) ...<Widget>[
                  _Row(
                    thread: thread,
                    active: thread.id == widget.activeId,
                    onSelect: widget.onSelect,
                  ),
                ],
              ],
              for (final String group in groups) ...<Widget>[
                _GroupLabel(label: group),
                for (final SearchableThread thread in matches.where(
                  (SearchableThread thread) =>
                      !thread.pinned && thread.group == group,
                ))
                  _Row(
                    thread: thread,
                    active: thread.id == widget.activeId,
                    onSelect: widget.onSelect,
                  ),
              ],
              if (matches.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 16,
                  ),
                  child: Text(
                    'No thread matches “${widget.query}”',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: auiFg(theme, 0.3),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Text(label, style: auiMono(context, color: auiFg(theme, 0.25))),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    required this.thread,
    required this.active,
    required this.onSelect,
  });

  final SearchableThread thread;
  final bool active;
  final ValueChanged<String>? onSelect;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool tappable = widget.onSelect != null;
    return MouseRegion(
      cursor: tappable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tappable ? () => widget.onSelect!(widget.thread.id) : null,
        child: Container(
          decoration: BoxDecoration(
            color: widget.active
                ? auiFg(theme, 0.05)
                : (_hovered && tappable ? auiFg(theme, 0.03) : null),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (widget.thread.pinned) ...<Widget>[
                    Icon(
                      Icons.push_pin_outlined,
                      size: 10,
                      color: auiFg(theme, 0.3),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      widget.thread.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: theme.foreground,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                widget.thread.preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: auiFg(theme, 0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
