import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One turn of a shared conversation.
@immutable
class SharedTurn {
  const SharedTurn({
    required this.id,
    required this.role,
    required this.text,
  });

  final String id;

  /// `user` renders as a bubble; anything else as prose.
  final String role;

  final String text;
}

/// A read-only conversation someone shared, with an offer to continue it —
/// the `shared-conversation` element.
class AssistantSharedConversation extends StatelessWidget {
  const AssistantSharedConversation({
    super.key,
    required this.title,
    required this.sharedBy,
    required this.sharedAt,
    required this.turns,
    this.onContinue,
  });

  final String title;

  /// Who shared it, and when.
  final String sharedBy;
  final String sharedAt;

  final List<SharedTurn> turns;

  /// The primary action; without it the button is inert.
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
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
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.link,
                      size: 14,
                      color: auiFg(theme, 0.3),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
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
                          Text(
                            'shared by $sharedBy · $sharedAt',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                auiMono(context, color: auiFg(theme, 0.3)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: auiFg(theme, 0.07)),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final (int index, SharedTurn turn) in turns.indexed)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: index == turns.length - 1 ? 0 : 10,
                        ),
                        child: _Turn(turn: turn),
                      ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: auiFg(theme, 0.07)),
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: <Widget>[
                    Text(
                      'read only',
                      style: auiMono(context, color: auiFg(theme, 0.3)),
                    ),
                    AuiPillButton(
                      label: 'Continue in your own chat',
                      variant: AuiPillButtonVariant.ink,
                      onPressed: onContinue,
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

class _Turn extends StatelessWidget {
  const _Turn({required this.turn});

  final SharedTurn turn;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool user = turn.role == 'user';
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 288),
        decoration: user
            ? BoxDecoration(
                color: auiFg(theme, 0.05),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        padding: user
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
            : EdgeInsets.zero,
        child: Text(
          turn.text,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: user ? theme.foreground : auiFg(theme, 0.7),
          ),
        ),
      ),
    );
  }
}
