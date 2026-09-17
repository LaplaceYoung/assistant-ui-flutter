import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One subagent in an [AssistantSubagentList].
@immutable
class SubagentItem {
  const SubagentItem({required this.name, required this.model});

  final String name;
  final String model;
}

/// The subagents a run fanned out to, each with its progress — the
/// `subagent-list` element.
class AssistantSubagentList extends StatelessWidget {
  const AssistantSubagentList({
    super.key,
    required this.agents,
    required this.completedCount,
    this.progress = const <double>[],
    this.showSummary = false,
    this.summaryAgent,
  });

  final List<SubagentItem> agents;

  /// How many of [agents] have finished, in order.
  final int completedCount;

  /// Per-agent percentage (0..100), as upstream takes it.
  final List<double> progress;

  /// Adds the gathering-summary row while the parent still works.
  final bool showSummary;
  final SubagentItem? summaryAgent;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 320,
        minHeight: 232,
      ),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (int index, SubagentItem agent) in agents.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AgentRow(
                  agent: agent,
                  done: index < completedCount,
                  percentage: index < progress.length
                      ? progress[index].clamp(0, 100)
                      : 0,
                ),
              ),
            if (showSummary && summaryAgent != null)
              _SummaryRow(agent: summaryAgent!),
          ],
        ),
      ),
    );
  }
}

class _AgentRow extends StatelessWidget {
  const _AgentRow({
    required this.agent,
    required this.done,
    required this.percentage,
  });

  final SubagentItem agent;
  final bool done;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      decoration: auiPaper(theme, radius: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (done)
                const Icon(Icons.check, size: 14, color: Color(0xFF10B981))
              else
                AuiSpinner(size: 14, color: auiFg(theme, 0.35)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  agent.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.3,
                    color: theme.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                agent.model,
                style: auiMono(context, color: auiFg(theme, 0.35)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: '${agent.name} progress',
            value: '${percentage.round()}%',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Container(
                height: 3,
                color: auiFg(theme, 0.06),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: math.max(0, math.min(1, percentage / 100)),
                    child: ColoredBox(
                      color: done
                          ? const Color(0xFF10B981).withValues(alpha: 0.7)
                          : auiFg(theme, 0.6),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.agent});

  final SubagentItem agent;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      decoration: auiPaper(theme, radius: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              AuiSpinner(size: 14, color: auiFg(theme, 0.35)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  agent.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.3,
                    color: theme.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                agent.model,
                style: auiMono(context, color: auiFg(theme, 0.35)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const AuiShimmerBar(),
        ],
      ),
    );
  }
}
