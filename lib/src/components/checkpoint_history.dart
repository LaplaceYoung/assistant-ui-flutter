import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One saved state a run can return to.
@immutable
class Checkpoint {
  const Checkpoint({
    required this.id,
    required this.label,
    required this.at,
    required this.files,
  });

  final String id;
  final String label;

  /// When it was taken, pre-formatted.
  final String at;

  /// How many files the checkpoint covers.
  final int files;
}

/// The states a run can be restored to, with the live one marked — the
/// `checkpoint-history` element.
class AssistantCheckpointHistory extends StatelessWidget {
  const AssistantCheckpointHistory({
    super.key,
    required this.checkpoints,
    required this.currentId,
    this.onRestore,
  });

  final List<Checkpoint> checkpoints;

  /// Which checkpoint the run is sitting on.
  final String currentId;

  /// Restores a checkpoint; the control appears on hover, as upstream does.
  final ValueChanged<String>? onRestore;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final int currentIndex = checkpoints
        .indexWhere((Checkpoint checkpoint) => checkpoint.id == currentId);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
                child: Text(
                  'Checkpoints',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                    color: theme.foreground,
                  ),
                ),
              ),
              for (final (int index, Checkpoint checkpoint)
                  in checkpoints.indexed)
                _Row(
                  checkpoint: checkpoint,
                  current: checkpoint.id == currentId,
                  ahead: currentIndex >= 0 && index > currentIndex,
                  onRestore: onRestore,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    required this.checkpoint,
    required this.current,
    required this.ahead,
    required this.onRestore,
  });

  final Checkpoint checkpoint;
  final bool current;
  final bool ahead;
  final ValueChanged<String>? onRestore;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color dot = widget.current
        ? (dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6))
        : auiFg(theme, 0.25);

    return Opacity(
      opacity: widget.ahead ? 0.4 : 1,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Container(
          decoration: BoxDecoration(
            color: widget.current
                ? auiFg(theme, 0.05)
                : (_hovered ? auiFg(theme, 0.03) : null),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: <Widget>[
              Container(
                width: 6,
                height: 6,
                decoration: widget.ahead
                    ? BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: auiFg(theme, 0.25)),
                      )
                    : BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      widget.checkpoint.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.3,
                        color: theme.foreground,
                      ),
                    ),
                    Text(
                      '${widget.checkpoint.at} · ${widget.checkpoint.files} files',
                      style: auiMono(context, color: auiFg(theme, 0.3)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (widget.current)
                Text(
                  'current',
                  style: auiMono(context, color: auiFg(theme, 0.35)),
                )
              else if (widget.onRestore != null)
                AnimatedOpacity(
                  opacity: _hovered ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: _Restore(
                    label: widget.checkpoint.label,
                    onTap: () => widget.onRestore!(widget.checkpoint.id),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Restore extends StatelessWidget {
  const _Restore({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Semantics(
      button: true,
      label: 'Restore to $label',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.refresh,
                size: 10,
                color: auiFg(theme, 0.45),
              ),
              const SizedBox(width: 6),
              Text(
                'Restore',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: auiFg(theme, 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
