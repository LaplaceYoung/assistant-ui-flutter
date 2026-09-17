import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// A run of text, optionally in the mono style.
@immutable
class StreamingSegment {
  const StreamingSegment(this.text, {this.mono = false});

  final String text;
  final bool mono;
}

/// Text revealed word by word, with the newest words tinted — the
/// `streaming-text` element.
class AssistantStreamingText extends StatelessWidget {
  const AssistantStreamingText({
    super.key,
    required this.segments,
    required this.count,
    this.streaming = false,
    this.style,
  });

  final List<StreamingSegment> segments;

  /// How many words are showing.
  final int count;

  final bool streaming;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    final Color blue =
        dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);
    final TextStyle base = (style ?? theme.body(context)).copyWith(
      fontSize: 14,
      height: 1.55,
    );

    final List<(String, bool)> words = <(String, bool)>[
      for (final StreamingSegment segment in segments)
        for (final String word in segment.text.split(' '))
          (word, segment.mono),
    ];
    final List<(String, bool)> shown =
        words.take(count.clamp(0, words.length)).toList();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384, minHeight: 136),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            for (final (int i, (String, bool) entry) in shown.indexed)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  entry.$1,
                  style: base.copyWith(
                    // The two newest words read as fresh while streaming.
                    color: streaming && shown.length - 1 - i < 2
                        ? blue
                        : null,
                    fontFamily: entry.$2 ? theme.code(context).fontFamily : null,
                    fontFamilyFallback:
                        entry.$2 ? theme.code(context).fontFamilyFallback : null,
                    fontSize: entry.$2 ? base.fontSize! * 0.85 : base.fontSize,
                    background: entry.$2
                        ? (Paint()..color = auiFg(theme, 0.06))
                        : null,
                  ),
                ),
              ),
            if (streaming && shown.isNotEmpty) const _StreamingCaret(),
          ],
        ),
      ),
    );
  }
}

class _StreamingCaret extends StatefulWidget {
  const _StreamingCaret();

  @override
  State<_StreamingCaret> createState() => _StreamingCaretState();
}

class _StreamingCaretState extends State<_StreamingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.3, end: 1).animate(_pulse),
        child: Container(
          width: 2,
          height: 16,
          decoration: BoxDecoration(
            color:
                dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
