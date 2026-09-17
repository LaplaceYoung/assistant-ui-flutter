import 'package:flutter/material.dart';

import 'surfaces.dart';
import 'theme.dart';

/// One line of a canvas document.
@immutable
class AssistantCanvasLine {
  const AssistantCanvasLine(this.text, {this.heading = false});

  final String text;
  final bool heading;
}

/// A message in the canvas's thread pane.
@immutable
class AssistantCanvasMessage {
  const AssistantCanvasMessage({required this.text, this.speaker = 'user'});

  final String text;

  /// `user` renders as a bubble on the right, anything else as plain prose.
  final String speaker;
}

/// Thread beside document: the conversation on one side, the artifact being
/// written on the other — the `canvas-split` element.
///
/// Upstream ships this as seven composable pieces (`Root`, `Thread`,
/// `Message`, `Document`, `Header`, `Body`, `Line`); the Flutter port keeps
/// them as fields on one widget because a Dart host has no element merging to
/// compose them with.
class AssistantCanvasSplit extends StatelessWidget {
  const AssistantCanvasSplit({
    super.key,
    this.messages = const <AssistantCanvasMessage>[],
    required this.title,
    this.version = 1,
    this.saved = false,
    this.lines = const <AssistantCanvasLine>[],
    this.writing = false,
    this.onCopy,
    this.onClose,
  });

  final List<AssistantCanvasMessage> messages;

  final String title;
  final int version;
  final bool saved;
  final List<AssistantCanvasLine> lines;

  /// Draws the blinking caret after the last line.
  final bool writing;

  final VoidCallback? onCopy;
  final VoidCallback? onClose;

  /// Upstream's `md:` breakpoint: below it the panes stack.
  static const double _rowBreakpoint = 768;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 768),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: auiPaper(theme, radius: 20),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool sideBySide = constraints.maxWidth >= _rowBreakpoint;
              final Widget thread = _ThreadPane(
                messages: messages,
                dividerOnRight: sideBySide,
              );
              final Widget document = _DocumentPane(
                title: title,
                version: version,
                saved: saved,
                lines: lines,
                writing: writing,
                onCopy: onCopy,
                onClose: onClose,
              );
              if (!sideBySide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[thread, document],
                );
              }
              return SizedBox(
                height: 320,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(width: 240, child: thread),
                    Expanded(child: document),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ThreadPane extends StatelessWidget {
  const _ThreadPane({required this.messages, required this.dividerOnRight});

  final List<AssistantCanvasMessage> messages;
  final bool dividerOnRight;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: dividerOnRight
              ? BorderSide(color: auiFg(theme, 0.07))
              : BorderSide.none,
          bottom: dividerOnRight
              ? BorderSide.none
              : BorderSide(color: auiFg(theme, 0.07)),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (int index, AssistantCanvasMessage message)
                in messages.indexed)
              Padding(
                padding: EdgeInsets.only(
                  bottom: index == messages.length - 1 ? 0 : 12,
                ),
                child: _Message(message: message),
              ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.message});

  final AssistantCanvasMessage message;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool user = message.speaker == 'user';
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        decoration: user
            ? BoxDecoration(
                color: auiFieldColor(theme),
                borderRadius: BorderRadius.circular(16),
              )
            : null,
        padding: user
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
            : EdgeInsets.zero,
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: auiFg(theme, user ? 0.8 : 0.6),
          ),
        ),
      ),
    );
  }
}

class _DocumentPane extends StatelessWidget {
  const _DocumentPane({
    required this.title,
    required this.version,
    required this.saved,
    required this.lines,
    required this.writing,
    required this.onCopy,
    required this.onClose,
  });

  final String title;
  final int version;
  final bool saved;
  final List<AssistantCanvasLine> lines;
  final bool writing;
  final VoidCallback? onCopy;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final bool dark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: auiFg(theme, 0.07)),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.description_outlined,
                size: 14,
                color: auiFg(theme, 0.35),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
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
              const SizedBox(width: 8),
              Text(
                'v$version',
                style: auiMono(context, color: auiFg(theme, 0.3)),
              ),
              const SizedBox(width: 8),
              if (saved)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.check,
                      size: 12,
                      color: dark
                          ? const Color(0xFF34D399)
                          : const Color(0xFF059669),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'saved',
                      style: auiMono(
                        context,
                        color: dark
                            ? const Color(0xFF34D399)
                            : const Color(0xFF059669),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'editing',
                  style: auiMono(context, color: auiFg(theme, 0.3)),
                ),
              const SizedBox(width: 8),
              AuiIconAction(
                icon: Icons.copy,
                label: 'Copy $title',
                size: 28,
                onPressed: onCopy,
              ),
              const SizedBox(width: 4),
              AuiIconAction(
                icon: Icons.close,
                label: 'Close the canvas',
                size: 28,
                onPressed: onClose,
              ),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 144),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final (int index, AssistantCanvasLine line)
                      in lines.indexed)
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: index == lines.length - 1 && !writing ? 0 : 6,
                      ),
                      child: Text(
                        line.text,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          fontWeight:
                              line.heading ? FontWeight.w500 : FontWeight.w400,
                          color: auiFg(theme, line.heading ? 0.95 : 0.65),
                        ),
                      ),
                    ),
                  if (writing) const _WritingCaret(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WritingCaret extends StatefulWidget {
  const _WritingCaret();

  @override
  State<_WritingCaret> createState() => _WritingCaretState();
}

class _WritingCaretState extends State<_WritingCaret>
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
    return Align(
      alignment: Alignment.centerLeft,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.3, end: 1).animate(_pulse),
        child: Container(
          width: 2,
          height: 14,
          decoration: BoxDecoration(
            color: auiFg(theme, 0.7),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
