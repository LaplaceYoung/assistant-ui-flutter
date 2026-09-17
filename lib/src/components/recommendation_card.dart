import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// Where a recommendation stands.
enum RecommendationState { idle, accepted }

/// A recommendation with its confidence, and the two ways forward — the
/// `recommendation-card` element.
class AssistantRecommendationCard extends StatelessWidget {
  const AssistantRecommendationCard({
    super.key,
    required this.state,
    required this.question,
    required this.answer,
    required this.confidenceLabel,
    required this.acceptedLabel,
    this.onAccept,
    this.onAlternatives,
  });

  final RecommendationState state;

  /// The question being answered.
  final String question;

  /// The recommendation itself.
  final String answer;

  final String confidenceLabel;
  final String acceptedLabel;

  final VoidCallback? onAccept;
  final VoidCallback? onAlternatives;

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
              Text(
                question,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: theme.foreground,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                answer,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: auiFg(theme, 0.55),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 32,
                child: state == RecommendationState.idle
                    ? Row(
                        children: <Widget>[
                          const _ConfidenceBars(),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              confidenceLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: auiMono(
                                context,
                                color: auiFg(theme, 0.4),
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (onAlternatives != null)
                            AuiPillButton(
                              label: 'Alternatives',
                              onPressed: onAlternatives,
                            ),
                          if (onAccept != null) ...<Widget>[
                            const SizedBox(width: 8),
                            AuiPillButton(
                              label: 'Accept',
                              variant: AuiPillButtonVariant.ink,
                              onPressed: onAccept,
                            ),
                          ],
                        ],
                      )
                    : Row(
                        children: <Widget>[
                          const Icon(
                            Icons.check,
                            size: 14,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              acceptedLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.2,
                                color: auiFg(theme, 0.55),
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

class _ConfidenceBars extends StatelessWidget {
  const _ConfidenceBars();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'confidence',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int bar = 0; bar < 3; bar++)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Container(
                width: 4,
                height: 6 + bar * 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
