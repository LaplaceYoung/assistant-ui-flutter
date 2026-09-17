import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// Where a background run stands.
enum BackgroundState { running, ready, failed }

/// One run happening outside this thread.
@immutable
class BackgroundRun {
  const BackgroundRun({
    required this.id,
    required this.title,
    required this.state,
    required this.elapsed,
    this.summary,
  });

  final String id;
  final String title;
  final BackgroundState state;
  final String elapsed;

  /// One-line outcome, shown under the title.
  final String? summary;
}

/// Work happening elsewhere, ready to be pulled in — the `background-inbox`
/// element.
class AssistantBackgroundInbox extends StatelessWidget {
  const AssistantBackgroundInbox({
    super.key,
    required this.runs,
    this.onCollect,
  });

  final List<BackgroundRun> runs;

  /// Collects a finished run; running rows stay inert, as upstream does.
  final ValueChanged<String>? onCollect;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final int ready = runs
        .where((BackgroundRun run) => run.state == BackgroundState.ready)
        .length;
    final int running = runs
        .where((BackgroundRun run) => run.state == BackgroundState.running)
        .length;

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
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Running elsewhere',
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.2,
                          fontWeight: FontWeight.w500,
                          color: theme.foreground,
                        ),
                      ),
                    ),
                    Text(
                      ready > 0 ? '$ready ready' : '$running in flight',
                      style: auiMono(
                        context,
                        color: ready > 0
                            ? (dark
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF2563EB))
                            : auiFg(theme, 0.35),
                      ).copyWith(
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              for (final BackgroundRun run in runs) _Row(run: run, onCollect: onCollect),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.run, required this.onCollect});

  final BackgroundRun run;
  final ValueChanged<String>? onCollect;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool running = run.state == BackgroundState.running;
    // Upstream keeps the row inert while the run is still going.
    final VoidCallback? onTap =
        running || onCollect == null ? null : () => onCollect!(run.id);

    return _Hover(
      onTap: onTap,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 14,
            height: 14,
            child: Center(
              child: switch (run.state) {
                BackgroundState.running =>
                  AuiSpinner(size: 12, color: auiFg(theme, 0.3)),
                BackgroundState.failed =>
                  const Icon(Icons.close, size: 12, color: Color(0xFFEF4444)),
                BackgroundState.ready =>
                  const Icon(Icons.check, size: 12, color: Color(0xFF10B981)),
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  run.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    color: auiFg(theme, running ? 0.5 : 0.9),
                  ),
                ),
                if (run.summary != null)
                  Text(
                    run.summary!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: auiMono(context, color: auiFg(theme, 0.3)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            run.elapsed,
            style: auiMono(context, color: auiFg(theme, 0.25)).copyWith(
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hover extends StatefulWidget {
  const _Hover({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Hover> createState() => _HoverState();
}

class _HoverState extends State<_Hover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return MouseRegion(
      cursor: widget.onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: _hovered && widget.onTap != null
                ? auiFg(theme, 0.04)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: widget.child,
        ),
      ),
    );
  }
}
