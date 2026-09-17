import 'package:flutter/material.dart';

import 'code_diff.dart' show DiffKind, DiffLine;
import 'surfaces.dart';
import 'theme.dart';

/// Where a hunk stands in review.
enum HunkDecision { pending, kept, discarded }

/// One reviewable hunk of a diff.
@immutable
class DiffHunk {
  const DiffHunk({
    required this.id,
    required this.range,
    required this.lines,
    this.decision = HunkDecision.pending,
  });

  final String id;

  /// Hunk header, e.g. `@@ -12,4 +12,6 @@`.
  final String range;

  final List<DiffLine> lines;
  final HunkDecision decision;
}

/// A diff the reader accepts hunk by hunk — the `reviewable-diff` element.
class AssistantReviewableDiff extends StatelessWidget {
  const AssistantReviewableDiff({
    super.key,
    required this.filename,
    required this.hunks,
    this.onKeep,
    this.onDiscard,
    this.onApply,
  });

  final String filename;
  final List<DiffHunk> hunks;

  final ValueChanged<String>? onKeep;
  final ValueChanged<String>? onDiscard;

  /// Applies the kept hunks; disabled while any hunk is still pending.
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final int kept =
        hunks.where((DiffHunk hunk) => hunk.decision == HunkDecision.kept).length;
    final int pending = hunks
        .where((DiffHunk hunk) => hunk.decision == HunkDecision.pending)
        .length;
    final TextStyle code = theme.code(context).copyWith(fontSize: 12);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 448),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: code,
                      ),
                    ),
                    Text(
                      '$kept of ${hunks.length} kept',
                      style: auiMono(context, color: auiFg(theme, 0.35))
                          .copyWith(
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              for (final DiffHunk hunk in hunks)
                Opacity(
                  opacity: hunk.decision == HunkDecision.discarded ? 0.4 : 1,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: auiFg(theme, 0.06)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: Row(
                            children: <Widget>[
                              Text(
                                hunk.range,
                                style: auiMono(
                                  context,
                                  color: auiFg(theme, 0.3),
                                ),
                              ),
                              const Spacer(),
                              if (hunk.decision == HunkDecision.pending &&
                                  (onKeep != null || onDiscard != null))
                                ...<Widget>[
                                  if (onDiscard != null)
                                    AuiPillButton(
                                      label: 'Discard',
                                      icon: Icons.close,
                                      height: 24,
                                      padding: 8,
                                      spinnerSize: 12,
                                      onPressed: () => onDiscard!(hunk.id),
                                    ),
                                  if (onKeep != null) ...<Widget>[
                                    const SizedBox(width: 6),
                                    _KeepButton(
                                      range: hunk.range,
                                      onTap: () => onKeep!(hunk.id),
                                    ),
                                  ],
                                ]
                              else
                                Text(
                                  hunk.decision.name,
                                  style: auiMono(
                                    context,
                                    color: hunk.decision == HunkDecision.kept
                                        ? (dark
                                            ? const Color(0xFF34D399)
                                            : const Color(0xFF059669))
                                        : auiFg(theme, 0.35),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              for (final (int index, DiffLine line)
                                  in hunk.lines.indexed)
                                Container(
                                  key: ValueKey<String>('${hunk.id}-$index'),
                                  color: switch (line.kind) {
                                    DiffKind.context => null,
                                    DiffKind.added => const Color(0xFF10B981)
                                        .withValues(alpha: 0.10),
                                    DiffKind.removed => const Color(0xFFEF4444)
                                        .withValues(alpha: 0.10),
                                  },
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 2,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      SizedBox(
                                        width: 16,
                                        child: Text(
                                          switch (line.kind) {
                                            DiffKind.context => '',
                                            DiffKind.added => '+',
                                            DiffKind.removed => '−',
                                          },
                                          style: code.copyWith(
                                            color: auiFg(theme, 0.4),
                                          ),
                                        ),
                                      ),
                                      Text(
                                        line.text,
                                        style: code.copyWith(
                                          color: switch (line.kind) {
                                            DiffKind.context =>
                                              auiFg(theme, 0.4),
                                            DiffKind.added => dark
                                                ? const Color(0xFF6EE7B7)
                                                : const Color(0xFFB45309),
                                            DiffKind.removed => dark
                                                ? const Color(0xFFFCA5A5)
                                                : const Color(0xFFB91C1C),
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: auiFg(theme, 0.06)),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        pending > 0 ? '$pending left to review' : 'All reviewed',
                        style:
                            auiMono(context, color: auiFg(theme, 0.35)),
                      ),
                    ),
                    if (onApply != null)
                      AuiPillButton(
                        label: 'Apply $kept',
                        height: 28,
                        padding: 12,
                        variant: AuiPillButtonVariant.ink,
                        onPressed: pending > 0 ? null : onApply,
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

class _KeepButton extends StatelessWidget {
  const _KeepButton({required this.range, required this.onTap});

  final String range;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color green =
        dark ? const Color(0xFF34D399) : const Color(0xFF059669);
    return Semantics(
      button: true,
      label: 'Keep hunk $range',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 24,
          decoration: BoxDecoration(
            color: green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.check, size: 12, color: green),
              const SizedBox(width: 4),
              Text(
                'Keep',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: FontWeight.w500,
                  color: green,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
