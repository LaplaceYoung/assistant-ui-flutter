import 'package:flutter/material.dart';

import 'theme.dart';

/// Coldark palettes, taken from `prism-coldark-{cold,dark}.css` (MIT) — the
/// two themes upstream hands to Prism.
@immutable
class AuiHighlightPalette {
  const AuiHighlightPalette({
    required this.background,
    required this.plain,
    required this.comment,
    required this.keyword,
    required this.string,
    required this.number,
    required this.type,
    required this.function,
    required this.builtin,
  });

  final Color background;
  final Color plain;
  final Color comment;
  final Color keyword;
  final Color string;
  final Color number;
  final Color type;
  final Color function;
  final Color builtin;

  static const AuiHighlightPalette light = AuiHighlightPalette(
    background: Color(0xFFE3EAF2),
    plain: Color(0xFF111B27),
    comment: Color(0xFF3C526D),
    keyword: Color(0xFFA04900),
    string: Color(0xFF116B00),
    number: Color(0xFF755F00),
    type: Color(0xFF005A8E),
    function: Color(0xFF7C00AA),
    builtin: Color(0xFFAF00AF),
  );

  static const AuiHighlightPalette dark = AuiHighlightPalette(
    background: Color(0xFF111B27),
    plain: Color(0xFFE3EAF2),
    comment: Color(0xFF8DA1B9),
    keyword: Color(0xFFE9AE7E),
    string: Color(0xFF91D076),
    number: Color(0xFFE6D37A),
    type: Color(0xFF6CB8E6),
    function: Color(0xFFC699E3),
    builtin: Color(0xFFF4ADF4),
  );

  static AuiHighlightPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// One run of highlighted code.
@immutable
class AuiCodeToken {
  const AuiCodeToken(this.text, this.kind);

  final String text;
  final AuiTokenKind kind;
}

/// What a token is, for coloring.
enum AuiTokenKind {
  plain,
  comment,
  string,
  number,
  keyword,
  type,
  function,
  builtin,
}

/// Code with syntax coloring — the `syntax-highlighter` element.
///
/// Upstream mounts Prism (`PrismAsyncLight`) with the coldark themes; the port
/// ships its own small tokenizer instead, because Flutter has no Prism and
/// pulling a JS grammar engine in would dwarf the element. The palettes are
/// the same, the token classes are the ones this tokenizer can prove.
class AssistantSyntaxHighlighter extends StatelessWidget {
  const AssistantSyntaxHighlighter({
    super.key,
    required this.code,
    this.language = 'dart',
    this.padding = const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
    this.radius = 8,
    this.palette,
    this.style,
  });

  final String code;

  /// `dart`, `typescript`, `javascript`, `python`, `json`, `bash`.
  final String language;

  final EdgeInsets padding;
  final double radius;
  final AuiHighlightPalette? palette;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final AuiHighlightPalette colors = palette ?? AuiHighlightPalette.of(context);
    final TextStyle base = (style ?? theme.code(context)).copyWith(
      fontSize: 13,
      height: 1.5,
      color: colors.plain,
    );

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(radius),
      ),
      padding: padding,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SelectableText.rich(
          TextSpan(
            children: <TextSpan>[
              for (final AuiCodeToken token in tokenizeAuiCode(code, language))
                TextSpan(
                  text: token.text,
                  style: TextStyle(color: _colorOf(token.kind, colors)),
                ),
            ],
          ),
          style: base,
        ),
      ),
    );
  }

  static Color _colorOf(AuiTokenKind kind, AuiHighlightPalette palette) =>
      switch (kind) {
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

const Map<String, Set<String>> _keywords = <String, Set<String>>{
  'dart': <String>{
    'abstract', 'as', 'async', 'await', 'break', 'case', 'catch', 'class',
    'const', 'continue', 'covariant', 'default', 'deferred', 'do', 'dynamic',
    'else', 'enum', 'export', 'extends', 'extension', 'external', 'factory',
    'false', 'final', 'finally', 'for', 'get', 'hide', 'if', 'implements',
    'import', 'in', 'interface', 'is', 'late', 'library', 'mixin', 'new',
    'null', 'on', 'operator', 'part', 'required', 'rethrow', 'return', 'set',
    'show', 'static', 'super', 'switch', 'sync', 'this', 'throw', 'true',
    'try', 'typedef', 'var', 'void', 'while', 'with', 'yield',
  },
  'typescript': <String>{
    'as', 'async', 'await', 'break', 'case', 'catch', 'class', 'const',
    'continue', 'default', 'delete', 'do', 'else', 'enum', 'export',
    'extends', 'false', 'finally', 'for', 'from', 'function', 'if',
    'implements', 'import', 'in', 'instanceof', 'interface', 'let', 'new',
    'null', 'of', 'return', 'static', 'super', 'switch', 'this', 'throw',
    'true', 'try', 'type', 'typeof', 'undefined', 'var', 'void', 'while',
    'yield',
  },
  'python': <String>{
    'and', 'as', 'assert', 'async', 'await', 'break', 'class', 'continue',
    'def', 'del', 'elif', 'else', 'except', 'False', 'finally', 'for',
    'from', 'global', 'if', 'import', 'in', 'is', 'lambda', 'None', 'not',
    'or', 'pass', 'raise', 'return', 'True', 'try', 'while', 'with', 'yield',
  },
  'bash': <String>{
    'case', 'do', 'done', 'elif', 'else', 'esac', 'fi', 'for', 'function',
    'if', 'in', 'then', 'until', 'while',
  },
};

/// Function-like things Prism colors as builtins.
const Set<String> _builtins = <String>{
  'print', 'len', 'range', 'map', 'filter', 'list', 'set', 'dict', 'str',
  'console', 'require',
};

/// Types spelled in lowercase, which the capitalized-identifier rule would
/// otherwise miss; Prism colors these as `class-name`.
const Set<String> _types = <String>{
  'int', 'double', 'bool', 'num', 'dynamic', 'void', 'Object', 'String',
  'List', 'Map', 'Set', 'Future', 'Stream', 'Widget', 'BuildContext',
};

/// Splits [code] into tokens for [language].
///
/// Deliberately small: comments, strings, numbers, keywords, builtins,
/// capitalized types and identifiers that look like calls.
List<AuiCodeToken> tokenizeAuiCode(String code, String language) {
  final String lang = language.toLowerCase();
  final Set<String> keywords = _keywords[lang] ?? _keywords['typescript']!;
  final bool hashComments = lang == 'python' || lang == 'bash';
  final List<AuiCodeToken> tokens = <AuiCodeToken>[];
  final StringBuffer plain = StringBuffer();

  void flush() {
    if (plain.isEmpty) return;
    tokens.add(AuiCodeToken(plain.toString(), AuiTokenKind.plain));
    plain.clear();
  }

  int i = 0;
  while (i < code.length) {
    final String rest = code.substring(i);

    // Comments.
    final RegExpMatch? comment = hashComments
        ? RegExp(r'^#[^\n]*').firstMatch(rest)
        : null;
    final RegExpMatch? slashComment =
        RegExp(r'^//[^\n]*').firstMatch(rest);
    final RegExpMatch? blockComment =
        RegExp(r'^/\*[\s\S]*?\*/').firstMatch(rest);
    final RegExpMatch? picked = blockComment ?? comment ?? slashComment;
    if (picked != null) {
      flush();
      tokens.add(AuiCodeToken(picked.group(0)!, AuiTokenKind.comment));
      i += picked.group(0)!.length;
      continue;
    }

    // Strings: triple-quoted first, then the single-line forms.
    final String? triple =
        <String>['"""', "'''"]
            .where(rest.startsWith)
            .firstOrNull;
    if (triple != null) {
      final int closing = code.indexOf(triple, i + 3);
      final int stop = closing == -1 ? code.length : closing + 3;
      flush();
      tokens.add(AuiCodeToken(code.substring(i, stop), AuiTokenKind.string));
      i = stop;
      continue;
    }
    final RegExpMatch? string = RegExp(r'^"([^"\\]|\\.)*"').firstMatch(rest) ??
        RegExp(r"^'([^'\\]|\\.)*'").firstMatch(rest) ??
        RegExp(r'^`([^`\\]|\\.)*`').firstMatch(rest);
    if (string != null) {
      flush();
      tokens.add(AuiCodeToken(string.group(0)!, AuiTokenKind.string));
      i += string.group(0)!.length;
      continue;
    }

    // Numbers.
    final RegExpMatch? number =
        RegExp(r'^\d+(\.\d+)?([eE][+-]?\d+)?').firstMatch(rest);
    if (number != null) {
      flush();
      tokens.add(AuiCodeToken(number.group(0)!, AuiTokenKind.number));
      i += number.group(0)!.length;
      continue;
    }

    // Words.
    final RegExpMatch? word = RegExp(r'^[A-Za-z_$][A-Za-z0-9_$]*').firstMatch(rest);
    if (word != null) {
      final String text = word.group(0)!;
      final String after = rest.substring(text.length);
      final AuiTokenKind? kind = keywords.contains(text)
          ? AuiTokenKind.keyword
          : _builtins.contains(text)
              ? AuiTokenKind.builtin
              : _types.contains(text) || RegExp(r'^[A-Z]').hasMatch(text)
                  ? AuiTokenKind.type
                  : after.startsWith('(')
                      ? AuiTokenKind.function
                      : null;
      if (kind == null) {
        plain.write(text);
      } else {
        flush();
        tokens.add(AuiCodeToken(text, kind));
      }
      i += text.length;
      continue;
    }

    plain.write(code[i]);
    i++;
  }
  flush();
  return tokens;
}
