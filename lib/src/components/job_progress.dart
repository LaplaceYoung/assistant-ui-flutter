import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One weighted stage of a job.
@immutable
class JobStage {
  const JobStage({required this.name, required this.weight});

  final String name;
  final double weight;
}

/// A long-running job: its stages, an overall bar weighted by stage size, the
/// ETA and a cancel control — the `job-progress` element.
class AssistantJobProgress extends StatelessWidget {
  const AssistantJobProgress({
    super.key,
    required this.title,
    required this.stages,
    required this.stageIndex,
    required this.stageProgress,
    required this.eta,
    this.onCancel,
  });

  final String title;
  final List<JobStage> stages;

  /// Stage in flight; `stages.length` means finished.
  final int stageIndex;

  /// Progress inside the current stage, 0..1.
  final double stageProgress;

  final String eta;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final int stage = stageIndex.clamp(0, stages.length);
    final double progress = stageProgress.clamp(0, 1);
    final double totalWeight = stages.fold<double>(
          0,
          (double sum, JobStage item) => sum + item.weight,
        ) ==
        0
        ? 1
        : stages.fold<double>(
            0,
            (double sum, JobStage item) => sum + item.weight,
          );
    final double completed = stages
        .take(stage)
        .fold<double>(0, (double sum, JobStage item) => sum + item.weight);
    final JobStage? current = stage < stages.length ? stages[stage] : null;
    final double overall = (completed +
            (current == null ? 0 : current.weight * progress)) /
        totalWeight;
    final bool finished = stage >= stages.length;
    final Color blue =
        dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);

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
                  if (finished)
                    const Icon(Icons.check, size: 14, color: Color(0xFF10B981))
                  else
                    AuiSpinner(size: 14, color: auiFg(theme, 0.35)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: theme.foreground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    finished ? 'done' : eta,
                    style: auiMono(context, color: auiFg(theme, 0.35)).copyWith(
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  if (!finished && onCancel != null) ...<Widget>[
                    const SizedBox(width: 10),
                    AuiIconAction(
                      icon: Icons.close,
                      label: 'Cancel the job',
                      onPressed: onCancel,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Semantics(
                label: '$title progress',
                value: '${(overall * 100).round()}%',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 4,
                    color: auiFg(theme, 0.06),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: math.max(0, math.min(1, overall)),
                        child: ColoredBox(
                          color: finished
                              ? const Color(0xFF10B981)
                              : blue,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: <Widget>[
                  for (final (int index, JobStage item) in stages.indexed)
                    Text(
                      item.name,
                      style: auiMono(
                        context,
                        color: index < stage
                            ? auiFg(theme, 0.35)
                            : index == stage
                                ? auiFg(theme, 0.9)
                                : auiFg(theme, 0.2),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
