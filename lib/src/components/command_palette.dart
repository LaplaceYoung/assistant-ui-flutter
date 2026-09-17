import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One entry of the palette.
@immutable
class PaletteCommand {
  const PaletteCommand({
    required this.id,
    required this.label,
    required this.group,
    this.keys = const <String>[],
  });

  final String id;
  final String label;

  /// Section the command is listed under; groups render in the order their
  /// first match appears.
  final String group;

  /// Key caps shown on the right, e.g. `['⌘', 'K']`.
  final List<String> keys;
}

/// Keyboard-driven command list: filter by label, walk with the arrows, run
/// with Enter — the `command-palette` element.
class AssistantCommandPalette extends StatefulWidget {
  const AssistantCommandPalette({
    super.key,
    required this.commands,
    this.query,
    this.activeId,
    this.onQueryChange,
    this.onActiveChange,
    this.onRun,
    this.autoFocus = false,
  });

  final List<PaletteCommand> commands;

  /// Bound query and highlight; when null the widget owns them.
  final String? query;
  final String? activeId;

  final ValueChanged<String>? onQueryChange;
  final ValueChanged<String>? onActiveChange;

  /// Runs a command and makes the rows tappable; without it the list is a
  /// read-only view.
  final ValueChanged<String>? onRun;

  final bool autoFocus;

  @override
  State<AssistantCommandPalette> createState() =>
      _AssistantCommandPaletteState();
}

class _AssistantCommandPaletteState extends State<AssistantCommandPalette> {
  final GlobalKey _activeRowKey = GlobalKey();

  late String _query = widget.query ?? '';
  late String? _activeId = widget.activeId;
  late final TextEditingController _controller =
      TextEditingController(text: _query);
  late final FocusNode _focusNode = FocusNode(onKeyEvent: _onKey);

  @override
  void initState() {
    super.initState();
    _activeId ??= _ordered(_query, _matches(_query)).firstOrNull?.id;
  }

  @override
  void didUpdateWidget(AssistantCommandPalette oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query != null && widget.query != _query) {
      _query = widget.query!;
      if (_controller.text != _query) {
        _controller.text = _query;
        _controller.selection =
            TextSelection.collapsed(offset: _query.length);
      }
    }
    if (widget.activeId != null) _activeId = widget.activeId;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<PaletteCommand> _matches(String query) {
    final String needle = query.toLowerCase();
    return widget.commands
        .where((PaletteCommand command) =>
            command.label.toLowerCase().contains(needle))
        .toList();
  }

  /// Display order: grouped, so it differs from the filter order.
  List<PaletteCommand> _ordered(String query, List<PaletteCommand> matches) {
    final List<String> groups = <String>[];
    for (final PaletteCommand command in matches) {
      if (!groups.contains(command.group)) groups.add(command.group);
    }
    return <PaletteCommand>[
      for (final String group in groups)
        ...matches.where((PaletteCommand command) => command.group == group),
    ];
  }

  void _setQuery(String value) {
    setState(() {
      _query = value;
      final List<PaletteCommand> ordered = _ordered(value, _matches(value));
      if (!ordered.any((PaletteCommand command) => command.id == _activeId)) {
        _activeId = ordered.firstOrNull?.id;
      }
    });
    widget.onQueryChange?.call(value);
    _scrollActiveIntoView();
  }

  void _setActive(String id) {
    setState(() => _activeId = id);
    widget.onActiveChange?.call(id);
    _scrollActiveIntoView();
  }

  void _scrollActiveIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final BuildContext? context = _activeRowKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(context, alignment: 0.5);
      }
    });
  }

  /// Arrow keys and Enter come here before the field's own editing shortcuts.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final List<PaletteCommand> ordered = _ordered(_query, _matches(_query));
    if (ordered.isEmpty) return KeyEventResult.ignored;
    final int at = ordered
        .indexWhere((PaletteCommand command) => command.id == _activeId);
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        final int from = at == -1 ? -1 : at;
        _setActive(ordered[(from + 1) % ordered.length].id);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        final int from = at == -1 ? 0 : at;
        _setActive(
          ordered[(from - 1 + ordered.length) % ordered.length].id,
        );
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (_activeId != null) widget.onRun?.call(_activeId!);
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final List<PaletteCommand> matches = _matches(_query);
    final List<PaletteCommand> ordered = _ordered(_query, matches);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 20),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.search,
                      size: 14,
                      color: auiFg(theme, 0.3),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: widget.autoFocus,
                        onChanged: _setQuery,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.3,
                          color: auiFg(theme, 0.85),
                        ),
                        cursorColor: theme.foreground,
                        decoration: InputDecoration(
                          isDense: true,
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: 'Type a command',
                          hintStyle: TextStyle(
                            fontSize: 13.5,
                            color: auiFg(theme, 0.3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: auiField(theme, radius: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Text(
                        'esc',
                        style: auiMono(context, color: auiFg(theme, 0.35)),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: auiFg(theme, 0.07)),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 288),
                child: Semantics(
                  container: true,
                  label: 'Commands',
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (final String group in _groups(ordered))
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                                child: Text(
                                  group,
                                  style: auiMono(
                                    context,
                                    color: auiFg(theme, 0.25),
                                  ),
                                ),
                              ),
                              for (final PaletteCommand command
                                  in ordered.where((PaletteCommand command) =>
                                      command.group == group))
                                _Row(
                                  key: command.id == _activeId
                                      ? _activeRowKey
                                      : null,
                                  command: command,
                                  active: command.id == _activeId,
                                  onRun: widget.onRun,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (matches.isEmpty) ...<Widget>[
                Container(height: 1, color: auiFg(theme, 0.07)),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 16,
                    ),
                    child: Text(
                      'No command matches “$_query”',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: auiFg(theme, 0.3),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<String> _groups(List<PaletteCommand> ordered) {
    final List<String> groups = <String>[];
    for (final PaletteCommand command in ordered) {
      if (!groups.contains(command.group)) groups.add(command.group);
    }
    return groups;
  }
}

class _Row extends StatefulWidget {
  const _Row({
    super.key,
    required this.command,
    required this.active,
    required this.onRun,
  });

  final PaletteCommand command;
  final bool active;
  final ValueChanged<String>? onRun;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool tappable = widget.onRun != null;
    final Color? fill = widget.active
        ? auiFg(theme, 0.06)
        : (_hovered && tappable ? auiFg(theme, 0.03) : null);
    return MouseRegion(
      cursor: tappable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tappable ? () => widget.onRun!(widget.command.id) : null,
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.command.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: theme.foreground,
                  ),
                ),
              ),
              if (widget.command.keys.isNotEmpty) ...<Widget>[
                const SizedBox(width: 8),
                for (final String key in widget.command.keys)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Container(
                      decoration: auiField(theme, radius: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Text(
                        key,
                        style: auiMono(context, color: auiFg(theme, 0.4)),
                      ),
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
