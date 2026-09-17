import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One way to regenerate a message.
@immutable
class RegenerateOption {
  const RegenerateOption({
    required this.id,
    required this.label,
    required this.detail,
  });

  final String id;
  final String label;

  /// Shown on the right, unless this option is the current one.
  final String detail;
}

/// The regenerate control with a menu of models to regenerate with — the
/// `regenerate-menu` element.
class AssistantRegenerateMenu extends StatelessWidget {
  const AssistantRegenerateMenu({
    super.key,
    required this.options,
    this.open = false,
    this.currentId = '',
    this.onOpenChange,
    this.onPick,
  });

  final List<RegenerateOption> options;

  /// Bound open state; the trigger appears only when [onOpenChange] is set.
  final bool open;
  final String currentId;

  final ValueChanged<bool>? onOpenChange;
  final ValueChanged<String>? onPick;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (onOpenChange != null)
              Align(
                alignment: Alignment.centerLeft,
                child: _Trigger(
                  open: open,
                  onTap: () => onOpenChange!(!open),
                ),
              ),
            if (open)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  decoration: auiPaper(theme, radius: 16),
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final RegenerateOption option in options)
                        _OptionRow(
                          option: option,
                          current: option.id == currentId,
                          onPick: onPick,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Trigger extends StatelessWidget {
  const _Trigger({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Semantics(
      button: true,
      expanded: open,
      label: 'Regenerate with a different model',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: open ? auiFg(theme, 0.06) : null,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.refresh,
            size: 14,
            color: auiFg(theme, open ? 0.9 : 0.45),
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatefulWidget {
  const _OptionRow({
    required this.option,
    required this.current,
    required this.onPick,
  });

  final RegenerateOption option;
  final bool current;
  final ValueChanged<String>? onPick;

  @override
  State<_OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<_OptionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool tappable = widget.onPick != null;
    return MouseRegion(
      cursor: tappable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tappable ? () => widget.onPick!(widget.option.id) : null,
        child: Container(
          decoration: BoxDecoration(
            color: _hovered && tappable ? auiFg(theme, 0.05) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(
                child: Text(
                  widget.option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: theme.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                widget.current ? 'current' : widget.option.detail,
                style: auiMono(context, color: auiFg(theme, 0.3)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
