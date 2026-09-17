import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One past run of a schedule.
@immutable
class ScheduleRun {
  const ScheduleRun({required this.id, required this.at, required this.ok});

  final String id;
  final String at;
  final bool ok;
}

/// A recurring job: its cadence, when it fires next, and how the recent runs
/// went — the `schedule-card` element.
class AssistantScheduleCard extends StatelessWidget {
  const AssistantScheduleCard({
    super.key,
    required this.name,
    required this.cadence,
    required this.nextRun,
    required this.enabled,
    this.history = const <ScheduleRun>[],
    this.onToggle,
  });

  final String name;

  /// Human cadence, e.g. `every weekday at 09:00`.
  final String cadence;

  final String nextRun;
  final bool enabled;
  final List<ScheduleRun> history;

  /// Flips the schedule; without it the switch is inert.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
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
                      Icons.schedule,
                      size: 14,
                      color: auiFg(theme, 0.45),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                            color: theme.foreground,
                          ),
                        ),
                        Text(
                          cadence,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              auiMono(context, color: auiFg(theme, 0.3)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _Switch(
                    on: enabled,
                    label: '${enabled ? 'Pause' : 'Resume'} $name',
                    onToggle: onToggle,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: enabled ? 1 : 0.45,
                child: Container(
                  decoration: auiField(theme, radius: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Text(
                        'next',
                        style: auiMono(context, color: auiFg(theme, 0.3)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          enabled ? nextRun : 'paused',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.3,
                            color: auiFg(theme, 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (history.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  'recent runs',
                  style: auiMono(context, color: auiFg(theme, 0.3)),
                ),
                const SizedBox(height: 4),
                for (final ScheduleRun run in history)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: <Widget>[
                        Icon(
                          run.ok ? Icons.check : Icons.close,
                          size: 12,
                          color: run.ok
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            run.at,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.3,
                              color: auiFg(theme, 0.6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          run.ok ? 'ok' : 'failed',
                          style:
                              auiMono(context, color: auiFg(theme, 0.25)),
                        ),
                      ],
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

class _Switch extends StatelessWidget {
  const _Switch({required this.on, required this.label, required this.onToggle});

  final bool on;
  final String label;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Semantics(
      toggled: on,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: MouseRegion(
          cursor: onToggle == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 20,
            padding: const EdgeInsets.all(2),
            alignment: on ? Alignment.centerRight : Alignment.centerLeft,
            decoration: BoxDecoration(
              color: on ? auiFg(theme, 0.8) : auiFg(theme, 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: theme.background,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
