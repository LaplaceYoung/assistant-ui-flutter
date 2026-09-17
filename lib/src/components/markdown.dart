import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'math_renderer.dart';
import 'mermaid_diagram.dart';
import 'syntax_highlighter.dart';
import 'theme.dart';
import 'tooltip_icon_button.dart';

/// Markdown renderer for message text.
///
/// Covers what chat answers actually use: paragraphs, headings, bullet and
/// ordered lists, fenced code with a language label, block quotes, horizontal
/// rules, and inline code, bold, italic, strikethrough and links.
///
/// It is streaming-safe: an unclosed fence or an unfinished `**` renders as
/// literal text instead of throwing, so partial tokens look right mid-stream.
class AssistantMarkdown extends StatelessWidget {
  const AssistantMarkdown({
    super.key,
    required this.text,
    this.style,
    this.codeStyle,
    this.trailing,
    this.onTapLink,
    this.spacing = 10,
    this.mermaidDiagram,
    this.mathRenderer,
  });

  final String text;
  final TextStyle? style;
  final TextStyle? codeStyle;

  /// Renders a ```mermaid fence; without it the fence shows the source with
  /// the mermaid element's "could not be rendered" note.
  final Widget Function(BuildContext context, String code)? mermaidDiagram;

  /// Renders `$$…$$`; without it the block shows its TeX source in the math
  /// element's serif style. Inline `$…$` always uses that styled source — the
  /// inline parser runs outside the tree, so a host that wants inline math
  /// rendered calls `parseInline(..., mathRenderer:)` itself. Without a host
  /// renderer the built-in typesetter draws the expression.
  final Widget Function(BuildContext context, String tex, bool display)?
      mathRenderer;

  /// Appended to the last block — the streaming cursor goes here.
  final Widget? trailing;

  final ValueChanged<String>? onTapLink;

  /// Vertical gap between blocks.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final TextStyle base = style ?? theme.body(context);
    final TextStyle code = codeStyle ?? theme.code(context);
    final List<_Block> blocks = _parseBlocks(text);

    if (blocks.isEmpty) {
      return trailing == null
          ? const SizedBox.shrink()
          : Text.rich(TextSpan(style: base, children: <InlineSpan>[
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: trailing!,
              ),
            ]));
    }

    final List<Widget> children = <Widget>[];
    for (int i = 0; i < blocks.length; i++) {
      if (i > 0) children.add(SizedBox(height: spacing));
      // Math and Mermaid blocks hand their engine-specific work to the host.
      final _Block block = blocks[i];
      if (block is _CodeBlock &&
          block.language.toLowerCase() == 'mermaid') {
        children.add(
          AssistantMermaidDiagram(
            code: block.code,
            diagram: mermaidDiagram?.call(context, block.code),
          ),
        );
        continue;
      }
      if (block is _MathBlock) {
        final String tex = block.tex;
        children.add(
          // A host renderer wins; otherwise the built-in typesetter draws it,
          // and an empty expression falls back to the styled source.
          mathRenderer?.call(context, tex, true) ??
              (tex.trim().isEmpty
                  ? _MathFallback(tex: tex, theme: theme, display: true)
                  : AssistantMath(tex, display: true)),
        );
        continue;
      }
      children.add(
        block.build(
          context,
          base: base,
          code: code,
          theme: theme,
          onTapLink: onTapLink,
          trailing: i == blocks.length - 1 ? trailing : null,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  static List<_Block> _parseBlocks(String source) {
    final List<_Block> blocks = <_Block>[];
    final List<String> lines = source.split('\n');
    int i = 0;

    while (i < lines.length) {
      final String line = lines[i];
      final String trimmed = line.trimLeft();

      // Fenced code block.
      final RegExpMatch? math = RegExp(r'^\s*\$\$(.+?)\$\$\s*$').firstMatch(line);
      if (math != null) {
        blocks.add(_MathBlock(math.group(1)!));
        i++;
        continue;
      }
      final RegExpMatch? fence = RegExp(r'^\s*```(\S*)\s*$').firstMatch(line);
      if (fence != null) {
        final String language = fence.group(1) ?? '';
        final List<String> body = <String>[];
        i++;
        while (i < lines.length && !RegExp(r'^\s*```\s*$').hasMatch(lines[i])) {
          body.add(lines[i]);
          i++;
        }
        if (i < lines.length) i++; // closing fence, or end of an open stream
        blocks.add(_CodeBlock(body.join('\n'), language));
        continue;
      }

      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      // Horizontal rule.
      if (RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$').hasMatch(line)) {
        blocks.add(const _DividerBlock());
        i++;
        continue;
      }

      // Heading.
      final RegExpMatch? heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        blocks.add(_HeadingBlock(
          heading.group(2)!.trim(),
          heading.group(1)!.length,
        ));
        i++;
        continue;
      }

      // Block quote.
      if (trimmed.startsWith('>')) {
        final List<String> body = <String>[];
        while (i < lines.length && lines[i].trimLeft().startsWith('>')) {
          body.add(lines[i].trimLeft().substring(1).trimLeft());
          i++;
        }
        blocks.add(_QuoteBlock(body.join('\n')));
        continue;
      }

      // Lists.
      final RegExp bullet = RegExp(r'^(\s*)([-*+])\s+(.*)$');
      final RegExp ordered = RegExp(r'^(\s*)(\d+)[.)]\s+(.*)$');
      if (bullet.hasMatch(line) || ordered.hasMatch(line)) {
        final List<_ListItem> items = <_ListItem>[];
        while (i < lines.length) {
          final RegExpMatch? asBullet = bullet.firstMatch(lines[i]);
          final RegExpMatch? asOrdered = ordered.firstMatch(lines[i]);
          if (asBullet != null) {
            items.add(_ListItem(
              indent: asBullet.group(1)!.length,
              marker: '•',
              text: asBullet.group(3)!,
            ));
          } else if (asOrdered != null) {
            items.add(_ListItem(
              indent: asOrdered.group(1)!.length,
              marker: '${asOrdered.group(2)}.',
              text: asOrdered.group(3)!,
            ));
          } else {
            break;
          }
          i++;
        }
        blocks.add(_ListBlock(items));
        continue;
      }

      // Pipe table: a row, a separator row, then body rows.
      if (trimmed.startsWith('|') &&
          i + 1 < lines.length &&
          RegExp(r'^\s*\|[\s:|-]+\|\s*$').hasMatch(lines[i + 1])) {
        final List<String> header = _tableCells(lines[i]);
        final List<List<String>> body = <List<String>>[];
        i += 2;
        while (i < lines.length && lines[i].trimLeft().startsWith('|')) {
          body.add(_tableCells(lines[i]));
          i++;
        }
        blocks.add(_TableBlock(header, body));
        continue;
      }

      // Paragraph: consecutive non-empty lines that do not start a new block.
      final List<String> paragraph = <String>[];
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          !_startsBlock(lines[i])) {
        paragraph.add(lines[i].trim());
        i++;
      }
      blocks.add(_ParagraphBlock(paragraph.join('\n')));
    }
    return blocks;
  }

  static bool _startsBlock(String line) {
    final String trimmed = line.trimLeft();
    return RegExp(r'^```').hasMatch(trimmed) ||
        RegExp(r'^#{1,6}\s').hasMatch(trimmed) ||
        trimmed.startsWith('>') ||
        trimmed.startsWith('|') ||
        RegExp(r'^\s*([-*+])\s+').hasMatch(line) ||
        RegExp(r'^\s*\d+[.)]\s+').hasMatch(line) ||
        RegExp(r'^\s*([-*_])(\s*\1){2,}\s*$').hasMatch(line);
  }

  /// Splits `| a | b |` into `[a, b]`.
  static List<String> _tableCells(String line) {
    String trimmed = line.trim();
    if (trimmed.startsWith('|')) trimmed = trimmed.substring(1);
    if (trimmed.endsWith('|')) trimmed = trimmed.substring(0, trimmed.length - 1);
    return trimmed.split('|').map((String cell) => cell.trim()).toList();
  }
}

sealed class _Block {
  const _Block();

  Widget build(
    BuildContext context, {
    required TextStyle base,
    required TextStyle code,
    required AssistantTheme theme,
    required ValueChanged<String>? onTapLink,
    required Widget? trailing,
  });
}

class _ParagraphBlock extends _Block {
  const _ParagraphBlock(this.text);

  final String text;

  @override
  Widget build(
    BuildContext context, {
    required TextStyle base,
    required TextStyle code,
    required AssistantTheme theme,
    required ValueChanged<String>? onTapLink,
    required Widget? trailing,
  }) {
    return Text.rich(
      TextSpan(
        style: base,
        children: <InlineSpan>[
          ...parseInline(text, base: base, code: code, theme: theme, onTapLink: onTapLink),
          if (trailing != null)
            WidgetSpan(alignment: PlaceholderAlignment.middle, child: trailing),
        ],
      ),
    );
  }
}

class _HeadingBlock extends _Block {
  const _HeadingBlock(this.text, this.level);

  final String text;
  final int level;

  @override
  Widget build(
    BuildContext context, {
    required TextStyle base,
    required TextStyle code,
    required AssistantTheme theme,
    required ValueChanged<String>? onTapLink,
    required Widget? trailing,
  }) {
    final double scale = switch (level) {
      1 => 1.5,
      2 => 1.3,
      3 => 1.15,
      _ => 1.0,
    };
    final TextStyle headingStyle = base.copyWith(
      fontSize: (base.fontSize ?? 14) * scale,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
    return Padding(
      padding: EdgeInsets.only(top: level <= 2 ? 4 : 2),
      child: Text.rich(
        TextSpan(
          style: headingStyle,
          children: <InlineSpan>[
            ...parseInline(text, base: headingStyle, code: code, theme: theme, onTapLink: onTapLink),
            if (trailing != null)
              WidgetSpan(alignment: PlaceholderAlignment.middle, child: trailing),
          ],
        ),
      ),
    );
  }
}

/// Colors a token from the coldark palettes the syntax-highlighter element
/// ships, so a fenced block in a message matches a standalone highlight.
Color _tokenColor(AuiTokenKind kind, AssistantTheme theme) {
  final AuiHighlightPalette palette =
      theme.brightness == Brightness.dark
          ? AuiHighlightPalette.dark
          : AuiHighlightPalette.light;
  return switch (kind) {
    AuiTokenKind.plain => palette.plain,
    AuiTokenKind.comment => palette.comment,
    AuiTokenKind.string => palette.string,
    AuiTokenKind.number => palette.number,
    AuiTokenKind.keyword => palette.keyword,
    AuiTokenKind.type => palette.type,
    AuiTokenKind.function => palette.function,
    AuiTokenKind.builtin => palette.builtin,
  };
}

class _CodeBlock extends _Block {
  const _CodeBlock(this.code, this.language);

  final String code;
  final String language;

  @override
  Widget build(
    BuildContext context, {
    required TextStyle base,
    required TextStyle code,
    required AssistantTheme theme,
    required ValueChanged<String>? onTapLink,
    required Widget? trailing,
  }) {
    // The copy affordance only makes sense once the block has settled.
    final bool copyable = trailing == null;
    return Container(
      decoration: BoxDecoration(
        color: theme.muted,
        borderRadius: BorderRadius.circular(theme.cardRadius),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, language.isEmpty ? 0 : 8, 12, 0),
                  child: language.isEmpty
                      ? const SizedBox.shrink()
                      : Text(
                          language,
                          style: theme
                              .small(context)
                              .copyWith(fontWeight: FontWeight.w500),
                        ),
                ),
              ),
              if (copyable)
                Padding(
                  padding: const EdgeInsets.only(right: 6, top: 4),
                  child: AssistantTooltipIconButton(
                    icon: Icons.copy,
                    tooltip: 'Copy code',
                    size: 26,
                    iconSize: 13,
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: this.code),
                    ),
                  ),
                ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Text.rich(
              TextSpan(
                style: code,
                children: <InlineSpan>[
                  // The tokenized form of the same text: the `syntax-highlighter`
                  // element decides the colors, this block keeps the framing.
                  if (language.isEmpty)
                    TextSpan(text: this.code)
                  else
                    TextSpan(
                      children: <InlineSpan>[
                        for (final AuiCodeToken token
                            in tokenizeAuiCode(this.code, language))
                          TextSpan(
                            text: token.text,
                            style: TextStyle(
                              color: _tokenColor(token.kind, theme),
                            ),
                          ),
                      ],
                    ),
                  if (trailing != null)
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: trailing,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Display math: `$$ … $$` on its own, which Flutter cannot typeset without a
/// host renderer.
class _MathBlock extends _Block {
  const _MathBlock(this.tex);

  final String tex;

  @override
  Widget build(
    BuildContext context, {
    required TextStyle base,
    required TextStyle code,
    required AssistantTheme theme,
    required ValueChanged<String>? onTapLink,
    required Widget? trailing,
  }) {
    return _MathFallback(tex: tex, theme: theme, display: true);
  }
}

/// The TeX source rendered the way the math element draws it, for hosts that
/// have no typesetter.
class _MathFallback extends StatelessWidget {
  const _MathFallback({
    required this.tex,
    required this.theme,
    required this.display,
  });

  final String tex;
  final AssistantTheme theme;
  final bool display;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: display
          ? BoxDecoration(
              color: theme.muted,
              borderRadius: BorderRadius.circular(theme.cardRadius),
              border: Border.all(color: theme.border),
            )
          : null,
      padding: display
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : EdgeInsets.zero,
      child: display
          ? Center(
              child: Text(
                tex,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontFamilyFallback: const <String>['Times New Roman'],
                  fontSize: 17,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                  color: theme.foreground,
                ),
              ),
            )
          : Text(
              tex,
              style: TextStyle(
                fontFamily: 'serif',
                fontFamilyFallback: const <String>['Times New Roman'],
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: theme.foreground,
              ),
            ),
    );
  }
}

class _QuoteBlock extends _Block {
  const _QuoteBlock(this.text);

  final String text;

  @override
  Widget build(
    BuildContext context, {
    required TextStyle base,
    required TextStyle code,
    required AssistantTheme theme,
    required ValueChanged<String>? onTapLink,
    required Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.border, width: 3)),
      ),
      child: Text.rich(
        TextSpan(
          style: base.copyWith(color: theme.mutedForeground),
          children: <InlineSpan>[
            ...parseInline(text, base: base, code: code, theme: theme, onTapLink: onTapLink),
            if (trailing != null)
              WidgetSpan(alignment: PlaceholderAlignment.middle, child: trailing),
          ],
        ),
      ),
    );
  }
}

class _ListBlock extends _Block {
  const _ListBlock(this.items);

  final List<_ListItem> items;

  @override
  Widget build(
    BuildContext context, {
    required TextStyle base,
    required TextStyle code,
    required AssistantTheme theme,
    required ValueChanged<String>? onTapLink,
    required Widget? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(
              left: items[i].indent * 8,
              top: i == 0 ? 0 : 4,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 22,
                  child: Text(
                    items[i].marker,
                    style: base.copyWith(color: theme.mutedForeground),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: base,
                      children: <InlineSpan>[
                        ...parseInline(
                          items[i].text,
                          base: base,
                          code: code,
                          theme: theme,
                          onTapLink: onTapLink,
                        ),
                        if (trailing != null && i == items.length - 1)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: trailing,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DividerBlock extends _Block {
  const _DividerBlock();

  @override
  Widget build(
    BuildContext context, {
    required TextStyle base,
    required TextStyle code,
    required AssistantTheme theme,
    required ValueChanged<String>? onTapLink,
    required Widget? trailing,
  }) {
    return Container(height: 1, color: theme.border);
  }
}

class _TableBlock extends _Block {
  const _TableBlock(this.header, this.rows);

  final List<String> header;
  final List<List<String>> rows;

  @override
  Widget build(
    BuildContext context, {
    required TextStyle base,
    required TextStyle code,
    required AssistantTheme theme,
    required ValueChanged<String>? onTapLink,
    required Widget? trailing,
  }) {
    TextStyle cellStyle(TextStyle style) =>
        style.copyWith(fontSize: (style.fontSize ?? 14) - 1, height: 1.35);

    Widget cell(String text, bool isHeader) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text.rich(
            TextSpan(
              style: cellStyle(base).copyWith(
                fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
                color: isHeader ? theme.foreground : theme.foreground,
              ),
              children: parseInline(
                text,
                base: cellStyle(base),
                code: code,
                theme: theme,
                onTapLink: onTapLink,
              ),
            ),
          ),
        );

    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.cardRadius),
      child: Table(
        border: TableBorder.all(color: theme.border, width: 1),
        defaultVerticalAlignment: TableCellVerticalAlignment.top,
        children: <TableRow>[
          if (header.isNotEmpty)
            TableRow(
              decoration: BoxDecoration(color: theme.muted),
              children: <Widget>[
                for (final String text in header) cell(text, true),
              ],
            ),
          for (final List<String> row in rows)
            TableRow(
              children: <Widget>[
                for (int i = 0; i < header.length; i++)
                  cell(i < row.length ? row[i] : '', false),
              ],
            ),
        ],
      ),
    );
  }
}

class _ListItem {
  const _ListItem({
    required this.indent,
    required this.marker,
    required this.text,
  });

  final int indent;
  final String marker;
  final String text;
}

/// Parses inline markdown into spans. Public so hosts can reuse it inside
/// custom part renderers.
List<InlineSpan> parseInline(
  String text, {
  required TextStyle base,
  required TextStyle code,
  required AssistantTheme theme,
  ValueChanged<String>? onTapLink,
  /// Builds the widget for `$ … $`; it gets no context because inline parsing
  /// runs outside the tree, so wrap the host renderer in a `Builder` when it
  /// needs one.
  Widget Function(String tex, bool display)? mathRenderer,
}) {
  final List<InlineSpan> spans = <InlineSpan>[];
  final StringBuffer buffer = StringBuffer();

  void flush() {
    if (buffer.isEmpty) return;
    spans.add(TextSpan(text: buffer.toString()));
    buffer.clear();
  }

  int i = 0;
  while (i < text.length) {
    final String rest = text.substring(i);

    // Inline math, `$ … $`; a lone `$` followed by a space is left alone.
    if (rest.startsWith(r'$') && !rest.startsWith(r'$$')) {
      final int end = text.indexOf(r'$', i + 1);
      final String candidate =
          end == -1 ? '' : text.substring(i + 1, end);
      if (end != -1 &&
          candidate.isNotEmpty &&
          !candidate.startsWith(' ') &&
          !candidate.endsWith(' ')) {
        flush();
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            // Inline math uses the host renderer when there is one and the
            // built-in typesetter otherwise.
            child: mathRenderer?.call(candidate, false) ??
                (candidate.trim().isEmpty
                    ? _MathFallback(tex: candidate, theme: theme, display: false)
                    : AssistantMath(candidate, size: 15)),
          ),
        );
        i = end + 1;
        continue;
      }
    }

    // Inline code.
    if (rest.startsWith('`')) {
      final int end = text.indexOf('`', i + 1);
      if (end != -1) {
        flush();
        spans.add(TextSpan(
          text: text.substring(i + 1, end),
          style: code.copyWith(
            backgroundColor: theme.muted,
            fontSize: (base.fontSize ?? 14) - 1,
          ),
        ));
        i = end + 1;
        continue;
      }
    }

    // Bold.
    bool consumedBold = false;
    for (final String marker in <String>['**', '__']) {
      if (!rest.startsWith(marker)) continue;
      final int end = text.indexOf(marker, i + marker.length);
      if (end == -1 || end == i + marker.length) continue;
      flush();
      spans.add(TextSpan(
        text: text.substring(i + marker.length, end),
        style: base.copyWith(fontWeight: FontWeight.w600),
      ));
      i = end + marker.length;
      consumedBold = true;
      break;
    }
    if (consumedBold) continue;

    // Italic.
    if (rest.startsWith('*') && !rest.startsWith('**')) {
      final int end = text.indexOf('*', i + 1);
      if (end != -1 && end > i + 1) {
        flush();
        spans.add(TextSpan(
          text: text.substring(i + 1, end),
          style: base.copyWith(fontStyle: FontStyle.italic),
        ));
        i = end + 1;
        continue;
      }
    }

    // Strikethrough.
    if (rest.startsWith('~~')) {
      final int end = text.indexOf('~~', i + 2);
      if (end != -1 && end > i + 2) {
        flush();
        spans.add(TextSpan(
          text: text.substring(i + 2, end),
          style: base.copyWith(decoration: TextDecoration.lineThrough),
        ));
        i = end + 2;
        continue;
      }
    }

    // Link.
    if (rest.startsWith('[')) {
      final int close = text.indexOf(']', i + 1);
      if (close != -1 && close + 1 < text.length && text[close + 1] == '(') {
        final int paren = text.indexOf(')', close + 2);
        if (paren != -1) {
          final String label = text.substring(i + 1, close);
          final String url = text.substring(close + 2, paren);
          flush();
          spans.add(TextSpan(
            text: label,
            style: base.copyWith(
              color: theme.mutedForeground,
              decoration: TextDecoration.underline,
              decorationColor: theme.mutedForeground,
            ),
            recognizer: onTapLink == null
                ? null
                : (TapGestureRecognizer()..onTap = () => onTapLink(url)),
          ));
          i = paren + 1;
          continue;
        }
      }
    }

    buffer.write(text[i]);
    i++;
  }

  flush();
  return spans;
}
