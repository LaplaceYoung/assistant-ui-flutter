import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// Status of one span in a trace.
enum SpanStatus { running, completed, failed }

/// One timed unit of work in an [AssistantTraceWaterfall].
@immutable
class TraceSpan {
  const TraceSpan({
    required this.id,
    required this.name,
    required this.depth,
    required this.startMs,
    required this.durationMs,
    required this.status,
  });

  final String id;
  final String name;

  /// Nesting level; each level indents the label by 12px.
  final int depth;

  final int startMs;
  final int durationMs;
  final SpanStatus status;
}

/// Where the time went: one bar per span, placed on the run's timeline — the
/// `trace-waterfall` element.
class AssistantTraceWaterfall extends StatelessWidget {
  const AssistantTraceWaterfall({
    super.key,
    required this.spans,
    required this.totalMs,
    required this.visibleCount,
  });

  final List<TraceSpan> spans;

  /// Full width of the timeline; zero is treated as 1ms so bars stay sane.
  final int totalMs;

  /// How many spans have been revealed so far, in order.
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final int span = totalMs == 0 ? 1 : totalMs;
    final List<TraceSpan> shown = spans.take(visibleCount).toList();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 448),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Trace',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                        color: theme.foreground,
                      ),
                    ),
                  ),
                  Text(
                    '${totalMs}ms',
                    style: auiMono(context, color: auiFg(theme, 0.35))
                        .copyWith(
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final TraceSpan item in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: _SpanRow(span: item, totalMs: span),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpanRow extends StatelessWidget {
  const _SpanRow({required this.span, required this.totalMs});

  final TraceSpan span;
  final int totalMs;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final double left = _pct(span.startMs, totalMs);
    final double width = math.max(1.5, _pct(span.durationMs, totalMs));

    return Row(
      children: <Widget>[
        SizedBox(
          width: 120,
          child: Padding(
            padding: EdgeInsets.only(left: span.depth * 12),
            child: Text(
              span.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                color: auiFg(theme, 0.7),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 16,
            child: Semantics(
              label: '${span.status.name}, starts at ${span.startMs}ms, '
                  'runs ${span.durationMs}ms',
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double full = constraints.maxWidth;
                  return Stack(
                    children: <Widget>[
                      Positioned(
                        left: full * left / 100,
                        top: 4.5,
                        width: math.max(2, full * width / 100),
                        height: 7,
                        child: _Bar(status: span.status),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          child: Text(
            '${span.durationMs}',
            textAlign: TextAlign.end,
            style: auiMono(context, color: auiFg(theme, 0.3)).copyWith(
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _Bar extends StatefulWidget {
  const _Bar({required this.status});

  final SpanStatus status;

  @override
  State<_Bar> createState() => _BarState();
}

class _BarState extends State<_Bar> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.status == SpanStatus.running) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_Bar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status == SpanStatus.running) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    // Note: tailwind's blue-500 / blue-400, red-500/80 — the theme has no
    // blue or trace tokens.
    final Color color = switch (widget.status) {
      SpanStatus.running =>
        dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
      SpanStatus.completed => auiFg(theme, 0.35),
      SpanStatus.failed => const Color(0xFFEF4444).withValues(alpha: 0.8),
    };
    final Widget bar = Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
    return widget.status == SpanStatus.running
        ? FadeTransition(
            opacity: Tween<double>(begin: 0.35, end: 1).animate(_pulse),
            child: bar,
          )
        : bar;
  }
}

double _pct(num value, num total) =>
    total == 0 ? 0 : (value / total) * 100;
