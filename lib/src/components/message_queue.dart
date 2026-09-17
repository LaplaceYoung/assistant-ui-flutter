import 'package:flutter/material.dart';

import '../core/runtime_api.dart';
import '../primitives/runtime_provider.dart';
import '../primitives/state.dart';
import 'theme.dart';

/// Turns typed while a run was in flight, stacked above the composer and
/// cancelable until they are sent — the `message-queue` element.
class AssistantMessageQueue extends StatelessWidget {
  const AssistantMessageQueue({
    super.key,
    this.title = 'Queued',
    this.maxVisible = 3,
  });

  final String title;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return AuiStateBuilder<List<QueuedMessage>>(
      selector: (AuiState state) => state.composer.queue,
      builder: (BuildContext context, List<QueuedMessage> queue) {
        if (queue.isEmpty) return const SizedBox.shrink();
        final List<QueuedMessage> visible = queue.take(maxVisible).toList();
        final int hidden = queue.length - visible.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  title.toUpperCase(),
                  style: theme.small(context).copyWith(
                    fontSize: 10.5,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w600,
                    color: theme.mutedForeground,
                  ),
                ),
              ),
            for (final QueuedMessage message in visible)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _QueuedRow(message: message, theme: theme),
              ),
            if (hidden > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '+$hidden more',
                  style: theme.small(context).copyWith(fontSize: 11),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QueuedRow extends StatelessWidget {
  const _QueuedRow({required this.message, required this.theme});

  final QueuedMessage message;
  final AssistantTheme theme;

  @override
  Widget build(BuildContext context) {
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
      decoration: BoxDecoration(
        color: theme.muted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.schedule, size: 13, color: theme.mutedForeground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.text.isEmpty
                  ? '${message.attachments.length} attachment(s)'
                  : message.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.small(context).copyWith(color: theme.foreground),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Remove from queue',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => runtime.composer.removeQueued(message.id),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    Icons.close,
                    size: 13,
                    color: theme.mutedForeground,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
