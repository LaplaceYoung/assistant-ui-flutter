import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// How a suggestion set is laid out.
enum AuiSuggestionVariant { pills, list }

/// Prompt suggestions, as pills or a stack — the `suggestions` element.
class AssistantSuggestions extends StatefulWidget {
  const AssistantSuggestions({
    super.key,
    required this.suggestions,
    this.selected,
    this.onSuggestion,
    this.variant = AuiSuggestionVariant.pills,
    this.cycle = 0,
  });

  final List<String> suggestions;

  /// The chosen suggestion, drawn inverted.
  final String? selected;

  /// Reports a choice; without it the rows are inert.
  final ValueChanged<String>? onSuggestion;

  final AuiSuggestionVariant variant;

  /// Bump to replay the entrance of the set.
  final int cycle;

  @override
  State<AssistantSuggestions> createState() => _AssistantSuggestionsState();
}

class _AssistantSuggestionsState extends State<AssistantSuggestions> {
  @override
  Widget build(BuildContext context) {
    final bool list = widget.variant == AuiSuggestionVariant.list;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: list ? 384 : 448),
      child: SizedBox(
        width: double.infinity,
        child: KeyedSubtree(
          key: ValueKey<int>(widget.cycle),
          child: list
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final String suggestion in widget.suggestions)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _Chip(
                          label: suggestion,
                          selected: suggestion == widget.selected,
                          list: true,
                          onTap: widget.onSuggestion,
                        ),
                      ),
                  ],
                )
              : Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final String suggestion in widget.suggestions)
                      _Chip(
                        label: suggestion,
                        selected: suggestion == widget.selected,
                        list: false,
                        onTap: widget.onSuggestion,
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Chip extends StatefulWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.list,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool list;
  final ValueChanged<String>? onTap;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool tappable = widget.onTap != null;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: MouseRegion(
        cursor: tappable ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: tappable ? () => widget.onTap!(widget.label) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.translationValues(0, _hovered ? -1 : 0, 0),
            decoration: widget.selected
                ? BoxDecoration(
                    color: theme.foreground,
                    borderRadius:
                        BorderRadius.circular(widget.list ? 16 : 999),
                  )
                : auiPaper(theme, radius: widget.list ? 16 : 999),
            padding: EdgeInsets.symmetric(
              horizontal: widget.list ? 16 : 16,
              vertical: widget.list ? 10 : 8,
            ),
            alignment:
                widget.list ? Alignment.centerLeft : null,
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                color: widget.selected
                    ? theme.background
                    : theme.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
