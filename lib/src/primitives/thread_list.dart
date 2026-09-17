import 'package:flutter/material.dart';

import '../core/runtime_api.dart';
import 'runtime_provider.dart';
import 'state.dart';

/// Container for a thread list. Provides the search scope and composes the
/// parts below it.
class AuiThreadListRoot extends StatelessWidget {
  const AuiThreadListRoot({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

/// Creates a new conversation when tapped.
class AuiThreadListNew extends StatelessWidget {
  const AuiThreadListNew({super.key, this.child, this.builder});

  final Widget? child;
  final Widget Function(BuildContext context)? builder;

  @override
  Widget build(BuildContext context) {
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    return AuiThreadListTrigger(
      onTap: () => runtime.threads.create(),
      child: builder?.call(context) ?? child ?? const SizedBox.shrink(),
    );
  }
}

/// Search field for the list. The host owns the query — pass it back through
/// [AuiThreadListItems.searchQuery], the way the upstream shell does.
class AuiThreadListSearch extends StatefulWidget {
  const AuiThreadListSearch({
    super.key,
    required this.onChanged,
    this.hint = 'Search chats…',
    this.style,
    this.decoration,
    this.autofocus = false,
  });

  final ValueChanged<String> onChanged;
  final String hint;
  final TextStyle? style;
  final InputDecoration? decoration;
  final bool autofocus;

  @override
  State<AuiThreadListSearch> createState() => _AuiThreadListSearchState();
}

class _AuiThreadListSearchState extends State<AuiThreadListSearch> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: TextField(
          controller: _controller,
          autofocus: widget.autofocus,
          style: widget.style,
          onChanged: widget.onChanged,
          decoration: widget.decoration ??
              InputDecoration(
                hintText: widget.hint,
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
        ),
      );
}

/// Iterates the conversations, newest first.
///
/// [searchQuery] filters by title; [includeArchived] appends the archived
/// threads after the active ones, matching the upstream list's behavior.
class AuiThreadListItems extends StatelessWidget {
  const AuiThreadListItems({
    super.key,
    required this.builder,
    this.searchQuery = '',
    this.includeArchived = true,
  });

  final Widget Function(
    BuildContext context,
    ThreadListItem item,
    bool isActive,
  ) builder;

  final String searchQuery;
  final bool includeArchived;

  @override
  Widget build(BuildContext context) {
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    final String query = searchQuery.trim().toLowerCase();

    return AnimatedBuilder(
      animation: runtime,
      builder: (BuildContext context, Widget? _) {
        final ThreadsState state = runtime.state.threads;
        final List<String> ids = <String>[
          ...state.threadIds,
          if (includeArchived) ...state.archivedThreadIds,
        ];
        final List<Widget> children = <Widget>[];
        for (final String id in ids) {
          final ThreadListItem? item = state.itemById(id);
          if (item == null) continue;
          if (query.isNotEmpty && !item.title.toLowerCase().contains(query)) {
            continue;
          }
          children.add(
            AuiThreadListItemScope(
              item: item,
              isActive: id == state.mainThreadId,
              child: Builder(
                builder: (BuildContext context) => builder(
                  context,
                  item,
                  id == state.mainThreadId,
                ),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: children,
        );
      },
    );
  }
}

/// Scope for a single conversation: title, archive, delete and switching.
class AuiThreadListItemScope extends InheritedWidget {
  const AuiThreadListItemScope({
    super.key,
    required this.item,
    required this.isActive,
    required super.child,
  });

  final ThreadListItem item;
  final bool isActive;

  static AuiThreadListItemScope? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AuiThreadListItemScope>();

  @override
  bool updateShouldNotify(AuiThreadListItemScope oldWidget) =>
      item != oldWidget.item || isActive != oldWidget.isActive;
}

/// Switches to the scoped conversation when tapped.
class AuiThreadListItemTrigger extends StatelessWidget {
  const AuiThreadListItemTrigger({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    final AuiThreadListItemScope? scope = AuiThreadListItemScope.maybeOf(context);
    return AuiThreadListTrigger(
      onTap: scope == null
          ? null
          : () => runtime.threads.switchToThread(scope.item.id),
      child: child,
    );
  }
}

/// The conversation's title, or a placeholder while it has none.
class AuiThreadListItemTitle extends StatelessWidget {
  const AuiThreadListItemTitle({
    super.key,
    this.placeholder = 'New thread',
    this.builder,
    this.style,
  });

  final String placeholder;
  final Widget Function(BuildContext context, String title)? builder;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final AuiThreadListItemScope? scope = AuiThreadListItemScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    final String title =
        scope.item.hasTitle ? scope.item.title : placeholder;
    if (builder != null) return builder!(context, title);
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}

/// Archives (or unarchives) the scoped conversation.
class AuiThreadListItemArchive extends StatelessWidget {
  const AuiThreadListItemArchive({super.key, this.child, this.builder});

  final Widget? child;
  final Widget Function(BuildContext context, bool archived)? builder;

  @override
  Widget build(BuildContext context) {
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    final AuiThreadListItemScope? scope = AuiThreadListItemScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    final bool archived = scope.item.isArchived;
    return AuiThreadListTrigger(
      onTap: () => archived
          ? runtime.threads.unarchive(scope.item.id)
          : runtime.threads.archive(scope.item.id),
      child: builder?.call(context, archived) ??
          child ??
          const SizedBox.shrink(),
    );
  }
}

/// Deletes the scoped conversation.
class AuiThreadListItemDelete extends StatelessWidget {
  const AuiThreadListItemDelete({super.key, this.child, this.builder});

  final Widget? child;
  final Widget Function(BuildContext context)? builder;

  @override
  Widget build(BuildContext context) {
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    final AuiThreadListItemScope? scope = AuiThreadListItemScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    return AuiThreadListTrigger(
      onTap: () => runtime.threads.delete(scope.item.id),
      child: builder?.call(context) ?? child ?? const SizedBox.shrink(),
    );
  }
}

/// Fetches the next page of conversations from a persisting host.
class AuiThreadListLoadMore extends StatelessWidget {
  const AuiThreadListLoadMore({super.key, this.child, this.builder});

  final Widget? child;
  final Widget Function(BuildContext context, bool hasMore)? builder;

  @override
  Widget build(BuildContext context) {
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    return AuiStateBuilder<bool>(
      selector: (AuiState state) => state.threads.hasMore,
      builder: (BuildContext context, bool hasMore) {
        if (!hasMore) return const SizedBox.shrink();
        final Widget content =
            builder?.call(context, hasMore) ?? child ?? const SizedBox.shrink();
        return AuiThreadListTrigger(
          onTap: () => runtime.threads.loadMore(),
          child: content,
        );
      },
    );
  }
}

/// Shared tap surface for the list's controls.
class AuiThreadListTrigger extends StatelessWidget {
  const AuiThreadListTrigger({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      );
}
