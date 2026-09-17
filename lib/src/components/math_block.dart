import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One line of a derivation.
@immutable
class MathStep {
  const MathStep({required this.expression, this.note});

  /// The expression, usually built from [AuiFrac], [AuiSup] and [AuiSub].
  final Widget expression;

  /// What the step did.
  final String? note;
}

/// A derivation, revealed step by step — the `math-block` element.
class AssistantMathBlock extends StatelessWidget {
  const AssistantMathBlock({
    super.key,
    required this.steps,
    required this.visibleSteps,
    this.label,
  });

  final List<MathStep> steps;

  /// How many steps have been revealed, in order.
  final int visibleSteps;

  final String? label;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final TextStyle expression = TextStyle(
      fontFamily: 'serif',
      fontFamilyFallback: const <String>['Times New Roman', 'Georgia'],
      fontSize: 17,
      height: 1.5,
      fontStyle: FontStyle.italic,
      color: auiFg(theme, 0.9),
    );

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
              if (label != null)
                Text(label!, style: auiMono(context, color: auiFg(theme, 0.3))),
              for (final (int index, MathStep step)
                  in steps.take(visibleSteps).indexed)
                Padding(
                  padding: EdgeInsets.only(top: index == 0 && label == null ? 0 : 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: DefaultTextStyle(
                            style: expression,
                            textAlign: TextAlign.center,
                            child: step.expression,
                          ),
                        ),
                      ),
                      if (step.note != null)
                        Align(
                          alignment: Alignment.center,
                          child: Text(
                            step.note!,
                            textAlign: TextAlign.center,
                            style:
                                auiMono(context, color: auiFg(theme, 0.3)),
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

/// A stacked fraction with the bar upstream draws — the `Frac` helper.
class AuiFrac extends StatelessWidget {
  const AuiFrac({super.key, required this.over, required this.under});

  final Widget over;
  final Widget under;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 14.5, height: 1.2),
            child: over,
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: auiFg(theme, 0.4))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 14.5, height: 1.2),
            child: under,
          ),
        ),
      ],
    );
  }
}

/// Superscript text, 65% size and raised.
class AuiSup extends StatelessWidget {
  const AuiSup({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -4),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.normal),
        child: child,
      ),
    );
  }
}

/// Subscript text, 65% size and lowered.
class AuiSub extends StatelessWidget {
  const AuiSub({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, 4),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.normal),
        child: child,
      ),
    );
  }
}
