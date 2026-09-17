import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One dated message.
@immutable
class DatedMessage {
  const DatedMessage({
    required this.id,
    required this.day,
    required this.time,
    required this.role,
    required this.text,
  });

  final String id;
  final String day;

  /// Clock label, revealed on hover.
  final String time;

  /// `user` renders right-aligned in a bubble; anything else is plain prose.
  final String role;

  final String text;
}

/// A transcript with a rule whenever the day changes — the `day-separator`
/// element.
class AssistantDaySeparator extends StatelessWidget {
  const AssistantDaySeparator({super.key, required this.messages});

  final List<DatedMessage> messages;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final List<Widget> rows = <Widget>[];
    String lastDay = '';
    for (final DatedMessage message in messages) {
      final bool newDay = message.day != lastDay;
      lastDay = message.day;
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: rows.isEmpty ? 0 : 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (newDay)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          height: 1,
                          color: auiFg(theme, 0.08),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        message.day,
                        style:
                            auiMono(context, color: auiFg(theme, 0.3)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: auiFg(theme, 0.08),
                        ),
                      ),
                    ],
                  ),
                ),
              _Message(message: message),
            ],
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 384),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: rows,
        ),
      ),
    );
  }
}

class _Message extends StatefulWidget {
  const _Message({required this.message});

  final DatedMessage message;

  @override
  State<_Message> createState() => _MessageState();
}

class _MessageState extends State<_Message> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool user = widget.message.role == 'user';
    final Widget text = Container(
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: user
          ? BoxDecoration(
              color: auiFg(theme, 0.05),
              borderRadius: BorderRadius.circular(16),
            )
          : null,
      padding: user
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
          : EdgeInsets.zero,
      child: Text(
        widget.message.text,
        style: TextStyle(
          fontSize: 13.5,
          height: 1.5,
          color: user ? theme.foreground : auiFg(theme, 0.75),
        ),
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: user ? TextDirection.rtl : TextDirection.ltr,
        children: <Widget>[
          Flexible(child: text),
          const SizedBox(width: 8),
          Text(
            widget.message.time,
            style: auiMono(
              context,
              color: auiFg(theme, _hovered ? 0.3 : 0),
            ).copyWith(
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
