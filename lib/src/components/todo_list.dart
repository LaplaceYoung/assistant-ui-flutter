import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// Where one todo stands.
enum TodoStatus { pending, active, done, failed }

/// One todo of the current plan.
@immutable
class TodoItem {
  const TodoItem({
    required this.id,
    required this.text,
    required this.status,
    this.reason,
  });

  final String id;
  final String text;
  final TodoStatus status;

  /// Why a failed todo failed.
  final String? reason;
}

/// The agent's working list, with a pair of counters — the `todo-list`
/// element.
class AssistantTodoList extends StatelessWidget {
  const AssistantTodoList({
    super.key,
    required this.items,
    this.revision,
  });

  final List<TodoItem> items;

  /// Plan revision, shown beside the counters when the host tracks one.
  final int? revision;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final int done =
        items.where((TodoItem item) => item.status == TodoStatus.done).length;
    final String counter = revision == null
        ? '$done/${items.length}'
        : '$done/${items.length} · rev $revision';
    final Color red =
        dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
    final Color blue =
        dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Todos',
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                      color: theme.foreground,
                    ),
                  ),
                ),
                Text(
                  counter,
                  style: auiMono(context, color: auiFg(theme, 0.35)).copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final TodoItem item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _Row(item: item, red: red, blue: blue),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item, required this.red, required this.blue});

  final TodoItem item;
  final Color red;
  final Color blue;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 16,
          height: 20,
          child: Center(child: _Glyph(item: item, red: red, blue: blue)),
        ),
        const SizedBox(width: 10),
        Semantics(
          container: true,
          label: item.status.name,
          child: const SizedBox.shrink(),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                item.text,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 20 / 13.5,
                  color: switch (item.status) {
                    TodoStatus.done => auiFg(theme, 0.35),
                    TodoStatus.active => auiFg(theme, 0.9),
                    TodoStatus.pending => auiFg(theme, 0.5),
                    TodoStatus.failed => red,
                  },
                  decoration: item.status == TodoStatus.done
                      ? TextDecoration.lineThrough
                      : null,
                  decorationColor: auiFg(theme, 0.35),
                  decorationThickness: 1.5,
                ),
              ),
              if (item.status == TodoStatus.failed && item.reason != null)
                Text(
                  item.reason!,
                  style: TextStyle(
                    fontSize: 12,
                    height: 16 / 12,
                    color: auiFg(theme, 0.45),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.item, required this.red, required this.blue});

  final TodoItem item;
  final Color red;
  final Color blue;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    switch (item.status) {
      case TodoStatus.done:
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: auiFg(theme, 0.06),
            border: Border.all(color: auiFg(theme, 0.2)),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(Icons.check, size: 10, color: auiFg(theme, 0.45)),
        );
      case TodoStatus.failed:
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: red.withValues(alpha: 0.08),
            border: Border.all(color: red.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(Icons.close, size: 10, color: red),
        );
      case TodoStatus.active:
        return AuiSpinner(size: 14, color: blue);
      case TodoStatus.pending:
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            border: Border.all(color: auiFg(theme, 0.15)),
            borderRadius: BorderRadius.circular(5),
          ),
        );
    }
  }
}
