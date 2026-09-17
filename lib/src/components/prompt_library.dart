import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'surfaces.dart';
import 'theme.dart';

/// A prompt saved for reuse.
@immutable
class SavedPrompt {
  const SavedPrompt({
    required this.id,
    required this.name,
    required this.body,
    this.variables = const <String>[],
  });

  final String id;
  final String name;
  final String body;

  /// Placeholders in [body], shown as `{name}` chips.
  final List<String> variables;
}

/// Searchable saved prompts, with the selected one previewed — the
/// `prompt-library` element.
class AssistantPromptLibrary extends StatefulWidget {
  const AssistantPromptLibrary({
    super.key,
    required this.prompts,
    this.query = '',
    this.selectedId = '',
    this.onQueryChange,
    this.onSelect,
    this.onInsert,
  });

  final List<SavedPrompt> prompts;
  final String query;
  final String selectedId;

  final ValueChanged<String>? onQueryChange;
  final ValueChanged<String>? onSelect;

  /// Enter (or a double tap) inserts the selected prompt.
  final ValueChanged<String>? onInsert;

  @override
  State<AssistantPromptLibrary> createState() => _AssistantPromptLibraryState();
}

class _AssistantPromptLibraryState extends State<AssistantPromptLibrary> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.query);
  late final FocusNode _focusNode = FocusNode(onKeyEvent: _onKey);

  @override
  void didUpdateWidget(AssistantPromptLibrary oldWidget) {
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

  List<SavedPrompt> get _matches {
    final String needle = widget.query.toLowerCase();
    return widget.prompts
        .where((SavedPrompt prompt) =>
            prompt.name.toLowerCase().contains(needle))
        .toList();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final List<SavedPrompt> matches = _matches;
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final SavedPrompt? selected = matches
          .where((SavedPrompt prompt) => prompt.id == widget.selectedId)
          .firstOrNull;
      if (selected != null && widget.onInsert != null) {
        widget.onInsert!(selected.id);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }
    final int delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => 1,
      LogicalKeyboardKey.arrowUp => -1,
      _ => 0,
    };
    if (delta == 0 || matches.isEmpty) return KeyEventResult.ignored;
    final int at = matches
        .indexWhere((SavedPrompt prompt) => prompt.id == widget.selectedId);
    // The selection can be filtered out; start from the edge the key implies.
    final int from = at == -1 ? (delta > 0 ? -1 : 0) : at;
    widget.onSelect?.call(matches[(from + delta + matches.length) %
        matches.length]
        .id);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final List<SavedPrompt> matches = _matches;
    final SavedPrompt? selected = matches
        .where((SavedPrompt prompt) => prompt.id == widget.selectedId)
        .firstOrNull;

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
                    Icon(
                      Icons.bookmark_border,
                      size: 14,
                      color: auiFg(theme, 0.3),
                    ),
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
                          hintText: 'Search prompts',
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
              Semantics(
                container: true,
                label: 'Saved prompts',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final SavedPrompt prompt in matches)
                      _PromptRow(
                        prompt: prompt,
                        active: prompt.id == widget.selectedId,
                        onSelect: widget.onSelect,
                        onInsert: widget.onInsert,
                      ),
                  ],
                ),
              ),
              if (matches.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                  child: Text(
                    'Nothing matches “${widget.query}”',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: auiFg(theme, 0.3),
                    ),
                  ),
                ),
              if (selected != null) ...<Widget>[
                const SizedBox(height: 8),
                Container(
                  decoration: auiField(theme, radius: 12),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        selected.body,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: auiFg(theme, 0.65),
                        ),
                      ),
                      if (selected.variables.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: <Widget>[
                            for (final String variable in selected.variables)
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.background.withValues(
                                    alpha: 0.7,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                child: Text(
                                  '{$variable}',
                                  style: auiMono(
                                    context,
                                    color: auiFg(theme, 0.5),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptRow extends StatefulWidget {
  const _PromptRow({
    required this.prompt,
    required this.active,
    required this.onSelect,
    required this.onInsert,
  });

  final SavedPrompt prompt;
  final bool active;
  final ValueChanged<String>? onSelect;
  final ValueChanged<String>? onInsert;

  @override
  State<_PromptRow> createState() => _PromptRowState();
}

class _PromptRowState extends State<_PromptRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool interactive =
        widget.onSelect != null || widget.onInsert != null;
    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect == null
            ? null
            : () => widget.onSelect!(widget.prompt.id),
        onDoubleTap: widget.onInsert == null
            ? null
            : () => widget.onInsert!(widget.prompt.id),
        child: Container(
          decoration: BoxDecoration(
            color: widget.active
                ? auiFg(theme, 0.05)
                : (_hovered && interactive ? auiFg(theme, 0.03) : null),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.prompt.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: theme.foreground,
                  ),
                ),
              ),
              if (widget.prompt.variables.isNotEmpty) ...<Widget>[
                const SizedBox(width: 8),
                Text(
                  '${widget.prompt.variables.length} vars',
                  style: auiMono(context, color: auiFg(theme, 0.25)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
