import 'dart:async';

import 'package:flutter/material.dart';

import '../core/message.dart' show MessageStatusIncomplete;
import '../core/runtime_api.dart';
import '../primitives/action_bar.dart';
import '../primitives/branch_picker.dart';
import '../primitives/runtime_provider.dart';
import '../primitives/state.dart';
import 'surfaces.dart';
import 'theme.dart';

/// Styled copy / regenerate / edit bar under an assistant message.
///
/// Hidden while a run is in flight and on every message but the last, floating
/// back in on hover — the behavior of the upstream action bar.
class AssistantActionBar extends StatelessWidget {
  const AssistantActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return AuiActionBar(
      hideWhenRunning: true,
      autohide: AuiActionBarAutohide.notLast,
      floatWhenHidden: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AuiActionBarCopy(
            copiedDuration: const Duration(seconds: 2),
            builder: (BuildContext context, bool enabled, bool copied) =>
                _ActionIcon(
              icon: copied ? Icons.check : Icons.copy,
              enabled: enabled,
              color: copied ? theme.success : null,
            ),
          ),
          AuiActionBarReload(
            builder: (BuildContext context, bool enabled) =>
                _ActionIcon(icon: Icons.refresh, enabled: enabled),
          ),
          AuiActionBarEdit(
            builder: (BuildContext context, bool enabled) =>
                _ActionIcon(icon: Icons.edit_outlined, enabled: enabled),
          ),
          const AssistantContinueRun(),
        ],
      ),
    );
  }
}

/// The affordance a stopped run leaves behind: upstream keeps the partial
/// content and offers to pick the run back up — the `stopped-run` element.
///
/// It renders nothing unless the message is the last one, its status is
/// [MessageStatusIncomplete] and no run is in flight; tapping it starts a run
/// from that message.
class AssistantContinueRun extends StatelessWidget {
  const AssistantContinueRun({super.key, this.label = 'Continue'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return AuiIf(
      condition: (AuiState state) =>
          (state.message?.isLast ?? false) &&
          !state.thread.isRunning &&
          state.message?.message.status is MessageStatusIncomplete,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: AuiStateBuilder<MessageState?>(
          selector: (AuiState state) => state.message,
          builder: (BuildContext context, MessageState? message) {
            if (message == null) return const SizedBox.shrink();
            final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
            return AuiPillButton(
              label: label,
              icon: Icons.play_arrow,
              spinnerSize: 12,
              height: 28,
              padding: 12,
              onPressed: () => unawaited(
                runtime.thread.startRun(parentId: message.message.id),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Branch navigation, rendered only when a message has alternatives.
class AssistantBranchPickerBar extends StatelessWidget {
  const AssistantBranchPickerBar({super.key});

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return _BranchPickerRow(theme: theme);
  }
}

/// Internal: keeps the styling local while the primitive handles state.
class _BranchPickerRow extends StatelessWidget {
  const _BranchPickerRow({required this.theme});

  final AssistantTheme theme;

  @override
  Widget build(BuildContext context) {
    return AuiIf(
      condition: (AuiState state) => (state.message?.branchCount ?? 1) > 1,
      child: AuiBranchPicker(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            AuiBranchPickerPrevious(
              builder: (BuildContext context, bool enabled) => _ActionIcon(
                icon: Icons.chevron_left,
                enabled: enabled,
                compact: true,
              ),
            ),
            AuiBranchPickerNumber(
              builder: (BuildContext context, int index, int count) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  '${index + 1}/$count',
                  style: theme.small(context),
                ),
              ),
            ),
            AuiBranchPickerNext(
              builder: (BuildContext context, bool enabled) => _ActionIcon(
                icon: Icons.chevron_right,
                enabled: enabled,
                compact: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.enabled,
    this.color,
    this.compact = false,
  });

  final IconData icon;
  final bool enabled;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final Color effective =
        enabled ? (color ?? theme.mutedForeground) : theme.border;
    return Tooltip(
      message: _label(icon),
      child: SizedBox(
        width: compact ? 26 : 30,
        height: compact ? 26 : 30,
        child: Icon(icon, size: compact ? 18 : 16, color: effective),
      ),
    );
  }

  static String _label(IconData icon) => switch (icon) {
        Icons.copy => 'Copy',
        Icons.check => 'Copied',
        Icons.refresh => 'Regenerate',
        Icons.edit_outlined => 'Edit',
        Icons.chevron_left => 'Previous version',
        Icons.chevron_right => 'Next version',
        _ => '',
      };
}
