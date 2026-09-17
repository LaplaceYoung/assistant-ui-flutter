import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// Where a human-in-the-loop request stands.
enum ApprovalState { request, running, done, denied }

/// Asks before running something with side effects, then reports what came of
/// it — the `approval-card` element.
class AssistantApprovalCard extends StatelessWidget {
  const AssistantApprovalCard({
    super.key,
    required this.state,
    required this.command,
    required this.title,
    required this.subtitle,
    this.onAllowOnce,
    this.onAlwaysAllow,
    this.onDeny,
  });

  final ApprovalState state;

  /// The exact thing awaiting approval, shown verbatim in mono.
  final String command;

  final String title;
  final String subtitle;

  /// Actions render only in [ApprovalState.request], and only when supplied.
  final VoidCallback? onAllowOnce;
  final VoidCallback? onAlwaysAllow;
  final VoidCallback? onDeny;

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
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: auiFg(theme, 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.terminal,
                      size: 16,
                      color: auiFg(theme, 0.45),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                            color: theme.foreground,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.3,
                            color: auiFg(theme, 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                decoration: auiField(theme, radius: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Text(
                  command,
                  style: auiMono(context, size: 12, color: auiFg(theme, 0.7)),
                ),
              ),
              const SizedBox(height: 14),
              // Upstream keeps a fixed h-8 row; wrapping keeps long labels
              // (other locales, narrow sheets) reachable instead of clipped.
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (state == ApprovalState.request) ...<Widget>[
                      if (onDeny != null)
                        AuiPillButton(
                          label: 'Deny',
                          height: 32,
                          onPressed: onDeny,
                        ),
                      if (onAlwaysAllow != null)
                        AuiPillButton(
                          label: 'Always allow',
                          height: 32,
                          onPressed: onAlwaysAllow,
                        ),
                      if (onAllowOnce != null)
                        AuiPillButton(
                          label: 'Allow once',
                          height: 32,
                          variant: AuiPillButtonVariant.ink,
                          onPressed: onAllowOnce,
                        ),
                    ] else
                      _StatusLine(state: state),
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

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});

  final ApprovalState state;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final TextStyle style = TextStyle(
      fontSize: 12,
      height: 1.2,
      color: auiFg(theme, 0.55),
    );
    final Widget leading = switch (state) {
      ApprovalState.running =>
        AuiSpinner(size: 14, color: auiFg(theme, 0.45)),
      ApprovalState.denied => Icon(
          Icons.close,
          size: 14,
          color: auiFg(theme, 0.45),
        ),
      // request never reaches here; done is the remaining branch.
      _ => const Icon(Icons.check, size: 14, color: Color(0xFF10B981)),
    };
    final String label = switch (state) {
      ApprovalState.running => 'Approved, running',
      ApprovalState.denied => 'Denied',
      _ => 'Finished with exit 0',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        leading,
        const SizedBox(width: 8),
        Text(label, style: style),
      ],
    );
  }
}
