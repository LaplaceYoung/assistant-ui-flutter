import 'package:flutter/material.dart';

import '../core/runtime_api.dart';
import '../primitives/runtime_provider.dart';
import '../primitives/thread_list.dart';
import 'theme.dart';
import 'tooltip_icon_button.dart';

/// The styled conversation list — the sidebar body of the official clone
/// shell: a `New thread` action, a search field, and one row per thread with
/// hover-revealed archive and delete actions.
class AssistantThreadList extends StatefulWidget {
  const AssistantThreadList({
    super.key,
    this.searchable = true,
    this.includeArchived = true,
    this.emptyLabel = 'No threads yet',
  });

  final bool searchable;
  final bool includeArchived;
  final String emptyLabel;

  @override
  State<AssistantThreadList> createState() => _AssistantThreadListState();
}

class _AssistantThreadListState extends State<AssistantThreadList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return AuiThreadListRoot(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: AuiThreadListNew(
              builder: (BuildContext context) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: theme.muted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.border),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.add, size: 14, color: theme.foreground),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'New thread',
                        style: theme.small(context).copyWith(
                          color: theme.foreground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.searchable)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.border),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.search, size: 13, color: theme.mutedForeground),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AuiThreadListSearch(
                        hint: 'Search chats…',
                        style: theme.small(context).copyWith(color: theme.foreground),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Search chats…',
                          hintStyle: theme.small(context),
                        ),
                        onChanged: (String value) => setState(() => _query = value),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: AuiThreadListItems(
                searchQuery: _query,
                includeArchived: widget.includeArchived,
                builder: (
                  BuildContext context,
                  ThreadListItem item,
                  bool isActive,
                ) =>
                    _ThreadRow(item: item, isActive: isActive),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadRow extends StatefulWidget {
  const _ThreadRow({required this.item, required this.isActive});

  final ThreadListItem item;
  final bool isActive;

  @override
  State<_ThreadRow> createState() => _ThreadRowState();
}

class _ThreadRowState extends State<_ThreadRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    final bool active = widget.isActive;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: AuiThreadListItemTrigger(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? theme.muted
                  : (_hovered ? theme.muted.withValues(alpha: 0.6) : null),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  widget.item.isArchived
                      ? Icons.inventory_2_outlined
                      : Icons.forum_outlined,
                  size: 14,
                  color: active ? theme.foreground : theme.mutedForeground,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: AuiThreadListItemTitle(
                    style: theme.small(context).copyWith(
                      color: active ? theme.foreground : theme.mutedForeground,
                      fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
                if (_hovered) ...<Widget>[
                  AuiThreadListItemArchive(
                    builder: (BuildContext context, bool archived) =>
                        AssistantTooltipIconButton(
                      icon: archived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                      tooltip: archived ? 'Unarchive' : 'Archive',
                      size: 24,
                      iconSize: 13,
                      radius: 6,
                      foregroundColor: theme.mutedForeground,
                      // The action is the runtime's. A no-op here would swallow
                      // the tap the reader expects to work.
                      onPressed: () => archived
                          ? runtime.threads.unarchive(widget.item.id)
                          : runtime.threads.archive(widget.item.id),
                    ),
                  ),
                  AuiThreadListItemDelete(
                    builder: (BuildContext context) =>
                        AssistantTooltipIconButton(
                      icon: Icons.delete_outline,
                      tooltip: 'Delete',
                      size: 24,
                      iconSize: 13,
                      radius: 6,
                      foregroundColor: theme.mutedForeground,
                      onPressed: () => runtime.threads.delete(widget.item.id),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Collapsible sidebar rail around a thread list — the desktop half of the
/// official shell. Below [mobileBreakpoint] the rail is replaced by a drawer
/// opened from a floating button.
/// Which edge the shell's sidebar sits on. `right` is the copilot layout:
/// the chat keeps the left side and the rail collapses against the right.
enum AssistantShellSide { left, right }

class AssistantShell extends StatefulWidget {
  const AssistantShell({
    super.key,
    required this.child,
    this.sidebar,
    this.sidebarWidth = 260,
    this.collapsedWidth = 48,
    this.mobileBreakpoint = 768,
    this.initiallyCollapsed = false,
    this.resizable = true,
    this.minSidebarWidth = 200,
    this.maxSidebarWidth = 420,
    this.side = AssistantShellSide.left,
    this.title = 'Chats',
    this.header,
  });

  final Widget child;

  /// Sidebar body; defaults to [AssistantThreadList].
  final Widget? sidebar;

  final double sidebarWidth;
  final double collapsedWidth;
  final double mobileBreakpoint;
  final bool initiallyCollapsed;

  /// Dragging the edge between the sidebar and the chat resizes it.
  final bool resizable;
  final double minSidebarWidth;
  final double maxSidebarWidth;

  /// `right` gives the copilot layout.
  final AssistantShellSide side;

  /// Label beside the rail toggle.
  final String title;

  /// Extra chrome in the rail header (a logo, account menu, …).
  final Widget? header;

  @override
  State<AssistantShell> createState() => _AssistantShellState();
}

class _AssistantShellState extends State<AssistantShell> {
  late bool _collapsed = widget.initiallyCollapsed;
  late double _width = widget.sidebarWidth;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _onRight => widget.side == AssistantShellSide.right;

  void _resize(double delta) {
    setState(() {
      // A drag to the right widens a left rail and narrows a right one.
      final double next = _width + (_onRight ? -delta : delta);
      _width = next.clamp(widget.minSidebarWidth, widget.maxSidebarWidth);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final Widget sidebar = widget.sidebar ?? const AssistantThreadList();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool mobile = constraints.maxWidth < widget.mobileBreakpoint;
        if (mobile) {
          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: theme.background,
            drawer: Drawer(
              backgroundColor: theme.background,
              child: SafeArea(child: sidebar),
            ),
            body: Stack(
              children: <Widget>[
                widget.child,
                Positioned(
                  left: 8,
                  top: 8,
                  child: AssistantTooltipIconButton(
                    icon: Icons.menu,
                    tooltip: 'Open chat history',
                    size: 32,
                    iconSize: 16,
                    backgroundColor: theme.background.withValues(alpha: 0.8),
                    foregroundColor: theme.mutedForeground,
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                ),
              ],
            ),
          );
        }

        final List<Widget> panes = <Widget>[
          _sidebarPane(theme, sidebar),
          if (widget.resizable && !_collapsed) _resizeHandle(theme),
        ];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_onRight) Expanded(child: widget.child),
            ...panes,
            if (!_onRight) Expanded(child: widget.child),
          ],
        );
      },
    );
  }

  Widget _resizeHandle(AssistantTheme theme) => MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (DragUpdateDetails details) =>
              _resize(details.delta.dx),
          child: SizedBox(
            width: 8,
            child: Center(
              child: Container(width: 1, color: theme.border),
            ),
          ),
        ),
      );

  Widget _sidebarPane(AssistantTheme theme, Widget sidebar) {
    return Builder(
      builder: (BuildContext context) {
        return AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: _collapsed ? widget.collapsedWidth : _width,
              decoration: BoxDecoration(
                color: theme.muted.withValues(alpha: 0.4),
                border: Border(right: BorderSide(color: theme.border)),
              ),
              clipBehavior: Clip.hardEdge,
              // During the width animation the container is narrower than the
              // content; lay the sidebar out at its full width and let the
              // container's clip hide the difference.
              child: _collapsed
                  ? _RailToggle(
                      icon: Icons.view_sidebar_outlined,
                      tooltip: 'Show sidebar',
                      onPressed: () => setState(() => _collapsed = false),
                    )
                  : OverflowBox(
                      alignment: AlignmentDirectional.topStart,
                      minWidth: _width,
                      maxWidth: _width,
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(
                          height: 52,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Row(
                              children: <Widget>[
                                _RailToggle(
                                  icon: Icons.view_sidebar_outlined,
                                  tooltip: 'Hide sidebar',
                                  onPressed: () => setState(() => _collapsed = true),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    style: theme.small(context).copyWith(
                                      color: theme.foreground,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (widget.header != null) widget.header!,
                              ],
                            ),
                          ),
                        ),
                        Expanded(child: sidebar),
                      ],
                    ),
                  ),
            );
      },
    );
  }
}

class _RailToggle extends StatelessWidget {
  const _RailToggle({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: AssistantTooltipIconButton(
        icon: icon,
        tooltip: tooltip,
        size: 32,
        iconSize: 15,
        foregroundColor: theme.mutedForeground,
        onPressed: onPressed,
      ),
    );
  }
}
