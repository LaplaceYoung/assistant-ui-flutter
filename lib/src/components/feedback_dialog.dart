import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// What went wrong with an answer, then a thank-you — the `feedback-dialog`
/// element.
class AssistantFeedbackDialog extends StatelessWidget {
  const AssistantFeedbackDialog({
    super.key,
    this.reasons = const <String>[],
    this.selected = const <String>[],
    this.note = '',
    this.sent = false,
    this.onToggleReason,
    this.onNoteChange,
    this.onSubmit,
  });

  final List<String> reasons;

  /// Reasons currently picked.
  final List<String> selected;

  final String note;

  /// Swaps the form for the acknowledgement.
  final bool sent;

  final ValueChanged<String>? onToggleReason;
  final ValueChanged<String>? onNoteChange;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 20),
          padding: const EdgeInsets.all(16),
          child: sent
              ? Semantics(
                  container: true,
                  liveRegion: true,
                  label: 'Thanks. That helps us tune the model.',
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.check,
                        size: 16,
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Thanks. That helps us tune the model.',
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.3,
                            color: theme.foreground,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: auiFg(theme, 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.thumb_down_outlined,
                            size: 14,
                            color: auiFg(theme, 0.45),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'What went wrong?',
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                            color: theme.foreground,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'optional',
                          style: auiMono(context, color: auiFg(theme, 0.3)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        for (final String reason in reasons)
                          _Reason(
                            label: reason,
                            active: selected.contains(reason),
                            onTap: onToggleReason == null
                                ? null
                                : () => onToggleReason!(reason),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: auiField(theme, radius: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: TextField(
                        controller: TextEditingController(text: note),
                        onChanged: onNoteChange,
                        maxLines: 2,
                        minLines: 2,
                        cursorColor: theme.foreground,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: auiFg(theme, 0.8),
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          isCollapsed: true,
                          border: InputBorder.none,
                          hintText: 'Anything else?',
                          hintStyle: TextStyle(
                            fontSize: 12,
                            color: auiFg(theme, 0.3),
                          ),
                        ),
                      ),
                    ),
                    if (onSubmit != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: AuiPillButton(
                          label: 'Send feedback',
                          variant: AuiPillButtonVariant.ink,
                          onPressed: onSubmit,
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

class _Reason extends StatelessWidget {
  const _Reason({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: active ? theme.foreground : auiFieldColor(theme),
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              color: active ? theme.background : auiFg(theme, 0.55),
            ),
          ),
        ),
      ),
    );
  }
}
