import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// Who is talking in a multi-party transcript.
enum SpeakerKind { user, agent, subagent, tool }

/// One turn, with who said it.
@immutable
class SpeakerTurn {
  const SpeakerTurn({
    required this.id,
    required this.kind,
    required this.name,
    required this.text,
    this.detail,
  });

  final String id;
  final SpeakerKind kind;
  final String name;

  /// Small note beside the name, e.g. the model or the tool.
  final String? detail;

  final String text;
}

/// A transcript where each turn names its speaker, with an avatar tinted by
/// kind — the `speaker-identity` element.
class AssistantSpeakerIdentity extends StatelessWidget {
  const AssistantSpeakerIdentity({super.key, required this.turns});

  final List<SpeakerTurn> turns;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (int index, SpeakerTurn turn) in turns.indexed)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == turns.length - 1 ? 0 : 14,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _Avatar(kind: turn.kind, theme: theme),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: <Widget>[
                              Flexible(
                                child: Text(
                                  turn.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.3,
                                    fontWeight: FontWeight.w500,
                                    color: theme.foreground,
                                  ),
                                ),
                              ),
                              if (turn.detail != null) ...<Widget>[
                                const SizedBox(width: 6),
                                Text(
                                  turn.detail!,
                                  style: auiMono(
                                    context,
                                    color: auiFg(theme, 0.3),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            turn.text,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.5,
                              color: auiFg(theme, 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.kind, required this.theme});

  final SpeakerKind kind;
  final AssistantTheme theme;

  @override
  Widget build(BuildContext context) {
    final bool dark = theme.brightness == Brightness.dark;
    final Color blue =
        dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
    final (Color fill, Color icon) = switch (kind) {
      SpeakerKind.user => (auiFg(theme, 0.06), auiFg(theme, 0.55)),
      SpeakerKind.agent => (
          blue.withValues(alpha: dark ? 0.15 : 0.12),
          blue,
        ),
      SpeakerKind.subagent => (auiFg(theme, 0.06), auiFg(theme, 0.45)),
      SpeakerKind.tool => (auiFg(theme, 0.04), auiFg(theme, 0.4)),
    };
    final IconData glyph = switch (kind) {
      SpeakerKind.user => Icons.person_outline,
      SpeakerKind.tool => Icons.build_outlined,
      SpeakerKind.agent || SpeakerKind.subagent => Icons.smart_toy_outlined,
    };

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: fill,
        // A subagent reads as a round badge, the way upstream styles it.
        borderRadius: BorderRadius.circular(kind == SpeakerKind.subagent ? 999 : 8),
      ),
      child: Icon(glyph, size: 12, color: icon),
    );
  }
}
