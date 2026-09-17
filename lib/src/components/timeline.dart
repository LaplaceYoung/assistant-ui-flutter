import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// Where an event sits relative to now.
enum TimelineWhen { past, now, future }

/// One event in a [AssistantTimeline].
@immutable
class TimelineEvent {
  const TimelineEvent({
    required this.id,
    required this.when,
    required this.time,
    required this.title,
    this.detail,
  });

  final String id;
  final TimelineWhen when;

  /// Clock label, pre-formatted by the host.
  final String time;

  final String title;
  final String? detail;
}

/// Dated events with a rail that runs through them — the `timeline` element.
class AssistantTimeline extends StatelessWidget {
  const AssistantTimeline({
    super.key,
    required this.events,
    required this.visibleCount,
  });

  final List<TimelineEvent> events;

  /// How many events have been revealed, in order.
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final List<TimelineEvent> shown = events.take(visibleCount).toList();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final (int index, TimelineEvent event) in shown.indexed)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        width: 56,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            event.time,
                            textAlign: TextAlign.end,
                            style: auiMono(
                              context,
                              color: auiFg(
                                theme,
                                event.when == TimelineWhen.future ? 0.25 : 0.4,
                              ),
                            ).copyWith(
                              fontFeatures: const <FontFeature>[
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 16,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: _Dot(
                                when: event.when,
                                dark: dark,
                                theme: theme,
                              ),
                            ),
                            if (index < shown.length - 1)
                              Expanded(
                                child: Container(
                                  width: 1,
                                  color: event.when == TimelineWhen.future
                                      ? auiFg(theme, 0.08)
                                      : auiFg(theme, 0.15),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: index < shown.length - 1 ? 12 : 0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                event.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  fontWeight: event.when == TimelineWhen.now
                                      ? FontWeight.w500
                                      : FontWeight.w400,
                                  color: auiFg(
                                    theme,
                                    event.when == TimelineWhen.future
                                        ? 0.4
                                        : 0.9,
                                  ),
                                ),
                              ),
                              if (event.detail != null)
                                Text(
                                  event.detail!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.5,
                                    color: auiFg(theme, 0.45),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
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

class _Dot extends StatelessWidget {
  const _Dot({required this.when, required this.dark, required this.theme});

  final TimelineWhen when;
  final bool dark;
  final AssistantTheme theme;

  @override
  Widget build(BuildContext context) {
    final Color blue =
        dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
    switch (when) {
      case TimelineWhen.now:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: blue,
            shape: BoxShape.circle,
            // Upstream's `ring-4 ring-blue-500/15`.
            boxShadow: <BoxShadow>[
              BoxShadow(color: blue.withValues(alpha: 0.15), spreadRadius: 4),
            ],
          ),
        );
      case TimelineWhen.past:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: auiFg(theme, 0.3),
            shape: BoxShape.circle,
          ),
        );
      case TimelineWhen.future:
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: auiFg(theme, 0.2)),
          ),
        );
    }
  }
}
