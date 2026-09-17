import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One step of a first-run tour.
@immutable
class OnboardingStep {
  const OnboardingStep({
    required this.title,
    required this.body,
    required this.example,
  });

  final String title;
  final String body;

  /// A concrete example of what this step unlocks.
  final String example;
}

/// A first-run tour with progress dots and Skip / Next — the `onboarding`
/// element.
class AssistantOnboarding extends StatelessWidget {
  const AssistantOnboarding({
    super.key,
    required this.steps,
    required this.index,
    this.onNext,
    this.onSkip,
  });

  final List<OnboardingStep> steps;
  final int index;
  final VoidCallback? onNext;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    if (steps.isEmpty) return const SizedBox.shrink();
    final int current = index.clamp(0, steps.length - 1);
    final OnboardingStep step = steps[current];
    final bool last = current >= steps.length - 1;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 20),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${current + 1} of ${steps.length}',
                style: auiMono(context, color: auiFg(theme, 0.3)).copyWith(
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                step.title,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                  color: theme.foreground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                step.body,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: auiFg(theme, 0.55),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: auiField(theme, radius: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  step.example,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: auiFg(theme, 0.6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  for (final int i
                      in List<int>.generate(steps.length, (int i) => i))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: i == current ? 16 : 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: auiFg(theme, i == current ? 0.6 : 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  const Spacer(),
                  AuiPillButton(
                    label: 'Skip',
                    height: 32,
                    padding: 12,
                    onPressed: onSkip,
                  ),
                  const SizedBox(width: 8),
                  AuiPillButton(
                    label: last ? 'Start' : 'Next',
                    height: 32,
                    variant: AuiPillButtonVariant.ink,
                    onPressed: onNext,
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
