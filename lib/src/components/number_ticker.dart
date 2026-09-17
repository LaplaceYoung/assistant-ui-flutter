import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// A figure that rolls its digits into place when it changes — the
/// `number-ticker` element.
class AssistantNumberTicker extends StatelessWidget {
  const AssistantNumberTicker({
    super.key,
    required this.value,
    required this.label,
    this.style,
  });

  final num value;

  /// Caption under the figure.
  final String label;

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final TextStyle figure = style ??
        TextStyle(
          fontSize: 30,
          height: 1.1,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.5,
          color: theme.foreground,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        );
    // Upstream formats with `toLocaleString("en-US")`.
    final String formatted = _group(value);
    final TextPainter ruler = TextPainter(
      text: TextSpan(text: '0', style: figure),
      textDirection: TextDirection.ltr,
    )..layout();
    final double lineHeight = ruler.height;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Upstream puts the `aria-label` on the figure alone; the caption
        // stays its own node.
        Semantics(
          container: true,
          label: formatted,
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final String char in formatted.split(''))
                  _isDigit(char)
                      ? _RollingDigit(
                          digit: int.parse(char),
                          style: figure,
                          width: ruler.width,
                          lineHeight: lineHeight,
                        )
                      : Text(char, style: figure),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(label, style: auiMono(context, color: auiFg(theme, 0.35))),
      ],
    );
  }

  static bool _isDigit(String char) =>
      char.codeUnitAt(0) >= 0x30 && char.codeUnitAt(0) <= 0x39;

  /// Thousands separators, matching `toLocaleString` for the plain values
  /// this element sees.
  static String _group(num value) {
    final bool whole = value == value.roundToDouble();
    final String text = whole ? value.toStringAsFixed(0) : '$value';
    final int dot = text.indexOf('.');
    final String digits = dot == -1 ? text : text.substring(0, dot);
    final String decimals = dot == -1 ? '' : text.substring(dot);
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return '$out$decimals';
  }
}

class _RollingDigit extends StatelessWidget {
  const _RollingDigit({
    required this.digit,
    required this.style,
    required this.width,
    required this.lineHeight,
  });

  final int digit;
  final TextStyle style;
  final double width;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: width,
        height: lineHeight,
        // `TweenAnimationBuilder` continues from wherever the last roll
        // stopped, which is what makes a digit change read as one movement.
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: -digit * lineHeight),
          duration: const Duration(milliseconds: 500),
          curve: const Cubic(0.32, 0.72, 0, 1),
          builder: (BuildContext context, double offset, Widget? child) =>
              Transform.translate(offset: Offset(0, offset), child: child),
          // The strip is deliberately taller than the window it shows
          // through; `OverflowBox` keeps that from reading as a layout error.
          child: OverflowBox(
            alignment: Alignment.topCenter,
            minHeight: 0,
            maxHeight: lineHeight * 10,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < 10; i++)
                  SizedBox(
                    height: lineHeight,
                    child: Text('$i', style: style),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
