import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// The composer a phone shows: quick actions above, a big field, and the
/// send/stop control — the `mobile-composer` element.
class AssistantMobileComposer extends StatelessWidget {
  const AssistantMobileComposer({
    super.key,
    this.value = '',
    this.keyboardOpen = false,
    this.running = false,
    this.actions = const <String>[],
    this.onAction,
    this.onAttach,
    this.onValueChange,
    this.onSend,
    this.onStop,
    this.placeholder = 'Message',
  });

  final String value;

  /// While the keyboard is up the actions and the grabber give way.
  final bool keyboardOpen;

  final bool running;

  /// Quick actions, e.g. `Summarize`.
  final List<String> actions;

  final ValueChanged<String>? onAction;
  final VoidCallback? onAttach;
  final ValueChanged<String>? onValueChange;
  final VoidCallback? onSend;
  final VoidCallback? onStop;

  final String placeholder;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool canSend = !running && value.isNotEmpty && onSend != null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 304),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            color: theme.background,
            border: Border(
              top: BorderSide(color: auiFg(theme, 0.07)),
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            12,
            12,
            12,
            keyboardOpen ? 12 : 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (!keyboardOpen && actions.isNotEmpty) ...<Widget>[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      for (final String action in actions)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _QuickAction(
                            label: action,
                            onTap: onAction == null
                                ? null
                                : () => onAction!(action),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Semantics(
                    button: true,
                    enabled: onAttach != null,
                    label: 'Add an attachment',
                    child: GestureDetector(
                      onTap: onAttach,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: auiFieldColor(theme),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add,
                          size: 16,
                          color: onAttach == null
                              ? auiFg(theme, 0.3)
                              : auiFg(theme, 0.45),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: auiField(theme, radius: 18),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: TextField(
                              controller:
                                  TextEditingController(text: value),
                              onChanged: onValueChange,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.3,
                                color: auiFg(theme, 0.85),
                              ),
                              cursorColor: theme.foreground,
                              decoration: InputDecoration(
                                isDense: true,
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText: placeholder,
                                hintStyle: TextStyle(
                                  fontSize: 16,
                                  color: auiFg(theme, 0.3),
                                ),
                              ),
                            ),
                          ),
                          if (value.isEmpty) ...<Widget>[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.mic_none,
                              size: 16,
                              color: auiFg(theme, 0.35),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (onSend != null || onStop != null) ...<Widget>[
                    Semantics(
                      button: true,
                      enabled: running ? onStop != null : canSend,
                      label: running ? 'Stop' : 'Send',
                      child: GestureDetector(
                        onTap: running ? onStop : (canSend ? onSend : null),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme.primary.withValues(
                              alpha: running
                                  ? (onStop == null ? 0.25 : 1)
                                  : (canSend ? 1 : 0.25),
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            running ? Icons.stop : Icons.arrow_upward,
                            size: 16,
                            color: theme.primaryForeground,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: keyboardOpen
                    ? Text(
                        'return to send',
                        style: auiMono(context, color: auiFg(theme, 0.25)),
                      )
                    : Container(
                        width: 112,
                        height: 4,
                        decoration: BoxDecoration(
                          color: auiFg(theme, 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: auiField(theme, radius: 999),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              height: 1.2,
              color: auiFg(theme, onTap == null ? 0.3 : 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
