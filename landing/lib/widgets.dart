import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'landing_theme.dart';

/// Centres page content at `max-w-7xl` with the site's gutters.
class ContentColumn extends StatelessWidget {
  const ContentColumn({
    super.key,
    required this.child,
    this.maxWidth = LandingText.contentMaxWidth,
    this.padding = const EdgeInsets.symmetric(horizontal: LandingText.gutter),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(padding: padding, child: child),
        ),
      );
}

/// `WHAT YOU INSTALL` style label.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return Text(
      text.toUpperCase(),
      style: LandingText.eyebrow(context)
          .copyWith(color: color ?? colors.mutedForeground),
    );
  }
}

/// Pill button: solid `primary` for the main call to action, bordered for the
/// secondary.
class LandingButton extends StatefulWidget {
  const LandingButton({
    super.key,
    required this.label,
    this.onPressed,
    this.solid = false,
    this.icon,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool solid;
  final IconData? icon;

  /// The nav's smaller chip: 12.8px label, 0/10 padding.
  final bool compact;

  @override
  State<LandingButton> createState() => _LandingButtonState();
}

class _LandingButtonState extends State<LandingButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    final Color background = widget.solid
        ? (_hovered ? colors.foreground : colors.primary)
        : Colors.transparent;
    final Color foreground = widget.solid
        ? colors.primaryForeground
        : (_hovered ? colors.foreground : colors.mutedForeground);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          // The live CTA is 32px tall with 0/12 padding and an 8px radius; the
          // nav chip is the same box with a 12.8px label and 0/10 padding.
          height: widget.compact ? 28 : 32,
          padding: EdgeInsets.symmetric(horizontal: widget.compact ? 10 : 12),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                widget.label,
                style: (widget.compact
                        ? LandingText.small(context).copyWith(fontSize: 12.8)
                        : LandingText.button(context))
                    .copyWith(color: foreground, fontWeight: FontWeight.w500),
              ),
              if (widget.icon != null) ...<Widget>[
                const SizedBox(width: 6),
                Icon(widget.icon, size: 15, color: foreground),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// `npx assistant-ui init` chip with a copy affordance.
class CommandChip extends StatefulWidget {
  const CommandChip({super.key, required this.command, this.fontSize = 14});

  final String command;
  final double fontSize;

  @override
  State<CommandChip> createState() => _CommandChipState();
}

class _CommandChipState extends State<CommandChip> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            widget.command,
            style: LandingText.mono(context, size: widget.fontSize)
                .copyWith(color: colors.foreground),
          ),
          const SizedBox(width: 10),
          Tooltip(
            message: 'Copy',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: widget.command));
                  if (!mounted) return;
                  setState(() => _copied = true);
                  await Future<void>.delayed(const Duration(seconds: 2));
                  if (mounted) setState(() => _copied = false);
                },
                child: Icon(
                  _copied ? Icons.check : Icons.copy,
                  size: 14,
                  color: colors.mutedForeground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Text link with the site's trailing arrow.
class ArrowLink extends StatefulWidget {
  const ArrowLink({super.key, required this.label, this.onPressed, this.color});

  final String label;
  final VoidCallback? onPressed;
  final Color? color;

  @override
  State<ArrowLink> createState() => _ArrowLinkState();
}

class _ArrowLinkState extends State<ArrowLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    final Color color = widget.color ?? colors.foreground;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              widget.label,
              style: LandingText.small(context).copyWith(
                color: color,
                decoration: _hovered ? TextDecoration.underline : null,
                decorationColor: color,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedSlide(
              duration: const Duration(milliseconds: 120),
              offset: Offset(_hovered ? 0.15 : 0, 0),
              child: Text('→', style: LandingText.small(context).copyWith(color: color)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Code block with the site's line styling: muted card, mono type, tinted
/// tokens, optional highlighted lines and a copy button.
class CodeBlock extends StatelessWidget {
  const CodeBlock({
    super.key,
    required this.code,
    this.highlightedLines = const <int>[],
    this.showLineNumbers = true,
    this.maxLines,
  });

  final String code;

  /// 1-based line numbers drawn on the accent surface with a left bar.
  final List<int> highlightedLines;

  final bool showLineNumbers;

  /// For previews that clip long samples.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    final List<String> lines = code.split('\n');
    final int count = maxLines == null ? lines.length : maxLines!.clamp(0, lines.length);

    return Container(
      decoration: BoxDecoration(
        color: colors.muted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int i = 0; i < count; i++)
            _CodeLine(
              number: showLineNumbers ? i + 1 : null,
              text: lines[i],
              highlighted: highlightedLines.contains(i + 1),
              colors: colors,
            ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(right: 12, left: 12, top: 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: Tooltip(
                message: 'Copy',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => Clipboard.setData(ClipboardData(text: code)),
                    child: Icon(Icons.copy, size: 13, color: colors.mutedForeground),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeLine extends StatelessWidget {
  const _CodeLine({
    required this.number,
    required this.text,
    required this.highlighted,
    required this.colors,
  });

  final int? number;
  final String text;
  final bool highlighted;
  final LandingColors colors;

  @override
  Widget build(BuildContext context) {
    final Widget line = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
      child: RichText(
        text: TextSpan(
          style: LandingText.mono(context).copyWith(color: colors.codePlain),
          children: highlightCode(text, colors),
        ),
      ),
    );

    return Container(
      decoration: highlighted
          ? BoxDecoration(
              color: colors.accent,
              border: Border(left: BorderSide(color: colors.mutedForeground, width: 2)),
            )
          : null,
      child: number == null
          ? line
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 36,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      '$number',
                      textAlign: TextAlign.right,
                      style: LandingText.mono(context, size: 11)
                          .copyWith(color: colors.mutedForeground.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: line),
              ],
            ),
    );
  }
}

/// Small syntax colouriser for the two languages the page shows (TSX-ish).
List<TextSpan> highlightCode(String line, LandingColors colors) {
  final List<TextSpan> spans = <TextSpan>[];
  final RegExp token = RegExp(
    r'(\/\/.*$)'
    r'|("(?:[^"\\]|\\.)*")'
    r'|\b(import|from|export|default|function|return|const|new|as)\b'
    r'|\b([A-Z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)*)\b'
    r'|\b(\d+(?:\.\d+)?)\b',
    multiLine: true,
  );

  int index = 0;
  for (final RegExpMatch match in token.allMatches(line)) {
    if (match.start > index) {
      spans.add(TextSpan(text: line.substring(index, match.start)));
    }
    final String text = match.group(0)!;
    final Color color;
    if (match.group(1) != null) {
      color = colors.codeComment;
    } else if (match.group(2) != null) {
      color = colors.codeString;
    } else if (match.group(3) != null) {
      color = colors.codeKeyword;
    } else if (match.group(4) != null) {
      color = colors.codeType;
    } else {
      color = colors.codePlain;
    }
    spans.add(TextSpan(text: text, style: TextStyle(color: color)));
    index = match.end;
  }
  if (index < line.length) {
    spans.add(TextSpan(text: line.substring(index)));
  }
  if (spans.isEmpty) spans.add(TextSpan(text: line));
  return spans;
}

/// Typographic stand-in for a vendor logo.
///
/// Fidelity gap: the site ships the vendors' SVG marks; reproducing those
/// assets is out of scope, so each is rendered as a mark plus its wordmark in
/// the site's muted treatment.
class LogoMark extends StatelessWidget {
  const LogoMark({
    super.key,
    required this.name,
    this.mark,
    this.emphasizeWord = false,
  });

  final String name;
  final IconData? mark;

  /// Renders the first word in the heavier weight, the way most of these
  /// wordmarks read (Google Cloud, ONLYOFFICE).
  final bool emphasizeWord;

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    final Widget label = emphasizeWord && name.contains(' ')
        ? RichText(
            text: TextSpan(
              style: LandingText.lead(context).copyWith(
                fontSize: 17,
                color: colors.mutedForeground,
              ),
              children: <TextSpan>[
                TextSpan(
                  text: name.split(' ').first,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: ' ${name.split(' ').skip(1).join(' ')}'),
              ],
            ),
          )
        : Text(
            name,
            style: LandingText.lead(context).copyWith(
              fontSize: 17,
              color: colors.mutedForeground,
              fontWeight: FontWeight.w500,
            ),
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (mark != null) ...<Widget>[
          Icon(mark, size: 20, color: colors.mutedForeground),
          const SizedBox(width: 8),
        ],
        label,
      ],
    );
  }
}

/// Quote card used by the social-proof strip.
class QuoteCard extends StatelessWidget {
  const QuoteCard({
    super.key,
    required this.text,
    required this.handle,
    this.width = 300,
  });

  final String text;
  final String handle;
  final double width;

  @override
  Widget build(BuildContext context) {
    final LandingColors colors = LandingColors.of(context);
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            text,
            style: LandingText.small(context).copyWith(color: colors.foreground, height: 1.6),
          ),
          const SizedBox(height: 10),
          Text(
            handle,
            style: LandingText.small(context).copyWith(color: colors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

/// Hairline divider matching `border-t` with `border-foreground/10`.
class Hairline extends StatelessWidget {
  const Hairline({super.key});

  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: LandingColors.of(context).border);
}
