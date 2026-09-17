import 'package:flutter/material.dart';

import '../core/message.dart';
import '../core/runtime_api.dart';
import '../primitives/state.dart';
import 'theme.dart';

/// Streaming statistics for the current message, behind a hover tooltip.
///
/// Reads the timing the runtime recorded for the run: time to first token,
/// total stream time, tokens per second and chunk count — the
/// `message-timing` element.
class AssistantMessageTiming extends StatelessWidget {
  const AssistantMessageTiming({super.key, this.iconSize = 14});

  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return AuiStateBuilder<MessageTiming?>(
      selector: (AuiState state) => state.message?.message.metadata.timing,
      builder: (BuildContext context, MessageTiming? timing) {
        if (timing == null || timing.totalStreamTime == null) {
          return const SizedBox.shrink();
        }
        final String detail = _describe(timing);
        return Tooltip(
          message: detail,
          waitDuration: const Duration(milliseconds: 250),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.schedule,
                size: iconSize,
                color: theme.mutedForeground,
              ),
              const SizedBox(width: 4),
              Text(_short(timing), style: theme.small(context)),
            ],
          ),
        );
      },
    );
  }

  static String _short(MessageTiming timing) {
    final int? total = timing.totalStreamTime;
    if (total == null) return '';
    return '${(total / 1000).toStringAsFixed(1)}s';
  }

  static String _describe(MessageTiming timing) {
    final List<String> lines = <String>[];
    if (timing.firstTokenTime != null) {
      lines.add('First token: ${(timing.firstTokenTime! / 1000).toStringAsFixed(2)}s');
    }
    if (timing.totalStreamTime != null) {
      lines.add('Total: ${(timing.totalStreamTime! / 1000).toStringAsFixed(2)}s');
    }
    if (timing.tokensPerSecond != null) {
      lines.add('Speed: ${timing.tokensPerSecond!.toStringAsFixed(1)} tok/s');
    }
    if (timing.tokenCount != null) {
      lines.add('Tokens: ${timing.tokenCount}');
    }
    if (timing.totalChunks != null) {
      lines.add('Chunks: ${timing.totalChunks}');
    }
    return lines.join('\n');
  }
}
