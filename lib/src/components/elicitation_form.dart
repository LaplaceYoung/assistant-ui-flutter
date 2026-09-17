import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// Where an elicitation request stands.
enum ElicitationState { request, accepted, declined }

/// The control a field is shown as.
enum ElicitationFieldKind { text, choice, toggle }

/// One field an MCP server asked for.
@immutable
class ElicitationField {
  const ElicitationField({
    required this.name,
    required this.label,
    required this.value,
    this.kind = ElicitationFieldKind.text,
    this.options = const <String>[],
    this.required = false,
  });

  final String name;
  final String label;

  /// Value the server proposed; for [ElicitationFieldKind.text] this is also
  /// what is shown, since the card does not own a text editor upstream.
  final String value;

  final ElicitationFieldKind kind;

  /// Choices for [ElicitationFieldKind.choice].
  final List<String> options;

  final bool required;
}

/// An MCP server asking the user for input before it can continue — the
/// `elicitation-form` element.
class AssistantElicitationForm extends StatelessWidget {
  const AssistantElicitationForm({
    super.key,
    required this.server,
    required this.message,
    required this.fields,
    required this.state,
    this.onAccept,
    this.onDecline,
    this.selected = const <String, String>{},
    this.onFieldChanged,
  });

  final String server;
  final String message;
  final List<ElicitationField> fields;
  final ElicitationState state;

  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  /// Answers by field name: an option for `choice`, `'true'`/`'false'` for
  /// `toggle`. Falls back to the field's own [ElicitationField.value].
  final Map<String, String> selected;

  /// Reports an answer; without it the controls are display only.
  final void Function(String name, String value)? onFieldChanged;

  String _valueOf(ElicitationField field) =>
      selected[field.name] ?? field.value;

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
          child: Column(
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
                      Icons.power,
                      size: 14,
                      color: auiFg(theme, 0.45),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      server,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: theme.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'needs input',
                    style: auiMono(context, color: auiFg(theme, 0.3)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                message,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: auiFg(theme, 0.55),
                ),
              ),
              const SizedBox(height: 14),
              for (final ElicitationField field in fields)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: field == fields.last ? 0 : 10,
                  ),
                  child: _Field(
                    field: field,
                    value: _valueOf(field),
                    onChanged: onFieldChanged == null
                        ? null
                        : (String value) =>
                            onFieldChanged!(field.name, value),
                  ),
                ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (state == ElicitationState.request) ...<Widget>[
                      if (onDecline != null)
                        AuiPillButton(
                          label: 'Decline',
                          height: 32,
                          onPressed: onDecline,
                        ),
                      if (onAccept != null)
                        AuiPillButton(
                          label: 'Send',
                          height: 32,
                          variant: AuiPillButtonVariant.ink,
                          onPressed: onAccept,
                        ),
                    ] else
                      _StatusLine(state: state, server: server),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  final ElicitationField field;
  final String value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              field.label,
              style: auiMono(context, color: auiFg(theme, 0.35)),
            ),
            if (field.required)
              Text(' *', style: auiMono(context, color: auiFg(theme, 0.25))),
          ],
        ),
        const SizedBox(height: 4),
        switch (field.kind) {
          ElicitationFieldKind.choice => Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final String option in field.options)
                  _ChoiceChip(
                    option: option,
                    selected: option == value,
                    onTap: onChanged == null
                        ? null
                        : () => onChanged!(option),
                  ),
              ],
            ),
          ElicitationFieldKind.toggle => _Toggle(
              on: value == 'true',
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(value == 'true' ? 'false' : 'true'),
            ),
          ElicitationFieldKind.text => Container(
              decoration: auiField(theme, radius: 8),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: auiFg(theme, 0.8),
                ),
              ),
            ),
        },
      ],
    );
  }
}

class _ChoiceChip extends StatefulWidget {
  const _ChoiceChip({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final String option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<_ChoiceChip> createState() => _ChoiceChipState();
}

class _ChoiceChipState extends State<_ChoiceChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: MouseRegion(
        cursor: widget.onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Semantics(
          button: true,
          selected: widget.selected,
          label: widget.option,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: widget.selected
                  ? theme.foreground
                  : auiFieldColor(theme).withValues(
                      alpha: _hovered && widget.onTap != null
                          ? (theme.brightness == Brightness.dark ? 0.09 : 0.07)
                          : (theme.brightness == Brightness.dark ? 0.06 : 0.04),
                    ),
              borderRadius: BorderRadius.circular(999),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Text(
              widget.option,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                color: widget.selected
                    ? theme.background
                    : auiFg(theme, 0.55),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.on, required this.onTap});

  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        child: Semantics(
          toggled: on,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28,
                height: 16,
                padding: const EdgeInsets.all(2),
                alignment: on ? Alignment.centerRight : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: on ? auiFg(theme, 0.8) : auiFg(theme, 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: theme.background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                on ? 'On' : 'Off',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  color: auiFg(theme, 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state, required this.server});

  final ElicitationState state;
  final String server;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool accepted = state == ElicitationState.accepted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (accepted)
          const Icon(Icons.check, size: 14, color: Color(0xFF10B981))
        else
          Icon(Icons.close, size: 14, color: auiFg(theme, 0.45)),
        const SizedBox(width: 8),
        Text(
          accepted ? 'Sent to $server' : 'Declined',
          style: TextStyle(
            fontSize: 12,
            height: 1.2,
            color: auiFg(theme, 0.55),
          ),
        ),
      ],
    );
  }
}
