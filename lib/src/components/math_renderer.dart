import 'package:flutter/material.dart';

import 'math_block.dart';

/// One node of a parsed expression.
sealed class MathNode {
  const MathNode();
}

/// A plain run of characters.
class MathText extends MathNode {
  const MathText(
    this.text, {
    this.italic = false,
    this.size = 1,
    this.bold = false,
  });

  /// `\\mathbf{…}` renders upright and heavy.
  final bool bold;
  final String text;

  /// Variables render italic, operators upright — TeX's own convention.
  final bool italic;

  /// A multiplier on the ambient size.
  final double size;
}

/// `\frac{over}{under}`.
class MathFraction extends MathNode {
  const MathFraction(this.over, this.under, {this.size = 1});
  final List<MathNode> over;
  final List<MathNode> under;
  final double size;
}

/// `\sqrt{…}`.
class MathRadical extends MathNode {
  const MathRadical(this.body, {this.size = 1});
  final List<MathNode> body;
  final double size;
}

/// A base with an optional superscript and subscript: `x^2`, `\sum_{i=0}^{n}`.
/// A row kept together, used where an accent's argument cannot carry the mark.
class MathGroup extends MathNode {
  const MathGroup(this.nodes, {this.size = 1});

  final List<MathNode> nodes;
  final double size;
}

class MathScript extends MathNode {
  const MathScript({
    required this.base,
    this.superscript,
    this.subscript,
    this.size = 1,
  });

  final List<MathNode> base;
  final List<MathNode>? superscript;
  final List<MathNode>? subscript;
  final double size;
}

/// `\begin{matrix}` and friends: a grid of cells, one row per `\\`, one cell
/// per `&`. The environments TeX spells out are the ones a chat answer uses.
class MathEnvironment extends MathNode {
  const MathEnvironment({
    required this.kind,
    required this.rows,
    this.size = 1,
  });

  final MathEnvironmentKind kind;

  /// Rows of cells; each cell is a parsed row of nodes.
  final List<List<List<MathNode>>> rows;
  final double size;
}

/// Which delimiters an environment draws, if any.
enum MathEnvironmentKind { matrix, pmatrix, bmatrix, cases, aligned }

/// How the parser and the renderer talk.
const Map<String, String> _symbols = <String, String>{
  'alpha': 'α', 'beta': 'β', 'gamma': 'γ', 'delta': 'δ', 'epsilon': 'ε',
  'varepsilon': 'ε', 'zeta': 'ζ', 'eta': 'η', 'theta': 'θ', 'iota': 'ι',
  'kappa': 'κ', 'lambda': 'λ', 'mu': 'μ', 'nu': 'ν', 'xi': 'ξ', 'pi': 'π',
  'rho': 'ρ', 'sigma': 'σ', 'tau': 'τ', 'upsilon': 'υ', 'phi': 'φ',
  'varphi': 'φ', 'chi': 'χ', 'psi': 'ψ', 'omega': 'ω',
  'Gamma': 'Γ', 'Delta': 'Δ', 'Theta': 'Θ', 'Lambda': 'Λ', 'Xi': 'Ξ',
  'Pi': 'Π', 'Sigma': 'Σ', 'Phi': 'Φ', 'Psi': 'Ψ', 'Omega': 'Ω',
  'sum': '∑', 'prod': '∏', 'int': '∫', 'infty': '∞', 'partial': '∂',
  'nabla': '∇', 'cdot': '·', 'times': '×', 'div': '÷', 'pm': '±', 'mp': '∓',
  'le': '≤', 'leq': '≤', 'ge': '≥', 'geq': '≥', 'ne': '≠', 'neq': '≠',
  'approx': '≈', 'equiv': '≡', 'to': '→', 'rightarrow': '→',
  'leftarrow': '←', 'Rightarrow': '⇒', 'in': '∈', 'notin': '∉',
  'ldots': '…', 'cdots': '⋯', 'dots': '…', 'vdots': '⋮',
  'ddots': '⋱', 'quad': ' ', 'qquad': '  ',
  'subset': '⊂', 'cup': '∪', 'cap': '∩', 'forall': '∀', 'exists': '∃',
  'angle': '∠', 'deg': '°', 'prime': '′',
};

/// Multi-letter names that render upright.
const Set<String> _operators = <String>{
  'sin', 'cos', 'tan', 'log', 'ln', 'exp', 'lim', 'max', 'min', 'det',
};

/// Parses a TeX-ish expression into a node tree. Unknown commands are kept as
/// text rather than dropped, so an unsupported construct still reads.
List<MathNode> parseMath(String source, {double size = 1}) {
  final _MathParser parser = _MathParser(source, size);
  return parser.parseRow();
}

class _MathParser {
  _MathParser(this.source, this.size);

  final String source;
  final double size;
  int index = 0;

  bool get done => index >= source.length;

  List<MathNode> parseRow({bool stopAtBrace = false}) {
    final List<MathNode> nodes = <MathNode>[];
    final StringBuffer pending = StringBuffer();
    bool pendingItalic = false;

    void flush() {
      if (pending.isEmpty) return;
      nodes.add(MathText(pending.toString(), italic: pendingItalic, size: size));
      pending.clear();
    }

    while (!done) {
      final String char = source[index];
      if (stopAtBrace && char == '}') {
        index++;
        break;
      }
      if (char == '{') {
        index++;
        flush();
        nodes.addAll(_group(parseRow(stopAtBrace: true)));
        continue;
      }
      if (char == '\\') {
        index++;
        final String command = _readCommand();
        if (command == 'begin') {
          flush();
          final MathNode? environment = _environment(size);
          if (environment != null) nodes.add(environment);
          continue;
        }
        if (command == 'end') {
          // A stray \end without its \begin: skip its name.
          _verbatimGroup();
          continue;
        }
        final MathNode? symbol = _commandNode(command, size);
        flush();
        if (symbol != null) nodes.add(symbol);
        continue;
      }
      if (char == '^' || char == '_') {
        index++;
        flush();
        final List<MathNode> script = _argument(size * 0.65);
        final MathNode? previous = nodes.isNotEmpty ? nodes.removeLast() : null;
        final MathNode base = previous ?? const MathText('', size: 1);
        if (previous is MathScript) {
          nodes.add(
            char == '^'
                ? MathScript(
                    base: previous.base,
                    superscript: script,
                    subscript: previous.subscript,
                    size: previous.size,
                  )
                : MathScript(
                    base: previous.base,
                    superscript: previous.superscript,
                    subscript: script,
                    size: previous.size,
                  ),
          );
        } else {
          nodes.add(
            char == '^'
                ? MathScript(base: <MathNode>[base], superscript: script, size: size)
                : MathScript(base: <MathNode>[base], subscript: script, size: size),
          );
        }
        continue;
      }
      if (char == ' ') {
        index++;
        flush();
        continue;
      }
      // Variables are italic, digits and operators are not.
      final bool italic = RegExp(r'[A-Za-z]').hasMatch(char);
      if (pending.isNotEmpty && italic != pendingItalic) flush();
      pendingItalic = italic;
      pending.write(char);
      index++;
    }
    flush();
    return nodes;
  }

  String _readCommand() {
    final StringBuffer name = StringBuffer();
    while (!done && RegExp(r'[A-Za-z]').hasMatch(source[index])) {
      name.write(source[index]);
      index++;
    }
    if (name.isEmpty && !done) {
      // A single escaped character, e.g. `\{`.
      final String char = source[index];
      index++;
      return char;
    }
    return name.toString();
  }

  /// The `{…}` (or single token) that follows a command or a script marker.
  List<MathNode> _argument(double nextSize) {
    while (!done && source[index] == ' ') {
      index++;
    }
    if (done) return const <MathNode>[];
    if (source[index] == '{') {
      index++;
      final _MathParser nested = _MathParser(source, nextSize)..index = index;
      final List<MathNode> nodes = nested.parseRow(stopAtBrace: true);
      index = nested.index;
      return nodes;
    }
    final String char = source[index];
    index++;
    if (char == '\\') {
      final String command = _readCommand();
      return <MathNode>[_commandNode(command, nextSize) ?? MathText('\\$command')];
    }
    return <MathNode>[MathText(char, italic: RegExp(r'[A-Za-z]').hasMatch(char), size: nextSize)];
  }

  /// Strips one layer of braces from an already parsed group.
  List<MathNode> _group(List<MathNode> nodes) => nodes;

  MathNode? _commandNode(String command, double atSize) {
    final String? symbol = _symbols[command];
    if (symbol != null) return MathText(symbol, size: atSize);
    if (_operators.contains(command)) {
      return MathText(command, size: atSize);
    }
    switch (command) {
      case 'frac':
      case 'dfrac':
        return MathFraction(
          _argument(atSize),
          _argument(atSize),
          size: atSize,
        );
      case 'sqrt':
        return MathRadical(_argument(atSize), size: atSize);
      case 'hat':
      case 'widehat':
      case 'bar':
      case 'overline':
      case 'vec':
      case 'tilde':
      case 'dot':
      case 'ddot':
        return _accented(command, atSize);
      case 'mathbf':
        return MathText(_verbatimGroup(), bold: true, size: atSize);
      case 'mathcal':
      case 'mathbb':
        // The blackboard letters TeX carries; anything else keeps its own
        // glyphs, so the expression still reads.
        return MathText(_blackboard(_verbatimGroup()), size: atSize);
      case 'text':
      case 'mathrm':
        // Verbatim: spaces inside \text{} are part of the words.
        return MathText(_verbatimGroup(), size: atSize);
      case ',':
      case ';':
      case ':':
      case ' ':
        return MathText(' ', size: atSize);
      case '!':
        return null;
      case 'left':
      case 'right':
        // A sizing hint with no Dart equivalent; the delimiter follows.
        return null;
      default:
        return MathText('\\$command', size: atSize);
    }
  }

  /// Reads `{env}` and everything up to its `\end{env}`, splitting rows on
  /// `\\` and cells on `&`. Returns null for an environment this renderer does
  /// not draw, leaving the source to be shown instead.
  MathNode? _environment(double atSize) {
    final String name = _verbatimGroup().trim();
    final MathEnvironmentKind? kind = switch (name) {
      'matrix' => MathEnvironmentKind.matrix,
      'pmatrix' => MathEnvironmentKind.pmatrix,
      'bmatrix' => MathEnvironmentKind.bmatrix,
      'cases' => MathEnvironmentKind.cases,
      'aligned' || 'align' || 'align*' => MathEnvironmentKind.aligned,
      _ => null,
    };
    if (kind == null) {
      // Not an environment this renderer draws: keep the source verbatim, so
      // the reader sees what was written rather than a silently dropped block.
      final String body = _skipEnvironment(name);
      return MathText('\\begin{$name}$body\\end{$name}', size: atSize);
    }

    final List<List<List<MathNode>>> rows = <List<List<MathNode>>>[];
    List<List<MathNode>> cells = <List<MathNode>>[];
    int depth = 1;
    final StringBuffer buffer = StringBuffer();

    void endCell() {
      cells.add(_MathParser(buffer.toString(), atSize).parseRow());
      buffer.clear();
    }

    void endRow() {
      endCell();
      rows.add(cells);
      cells = <List<MathNode>>[];
    }

    while (!done) {
      final String char = source[index];
      if (char == '\\') {
        final int mark = index;
        index++;
        final String command = _readCommand();
        if (command == 'begin') {
          depth++;
          buffer.write('\\begin');
          continue;
        }
        if (command == 'end') {
          depth--;
          if (depth == 0) {
            _verbatimGroup();
            break;
          }
          buffer.write('\\end');
          continue;
        }
        if (depth == 1 && command.isEmpty) {
          // `\\` — the row ends here.
          endRow();
          continue;
        }
        buffer.write(source.substring(mark, index));
        continue;
      }
      if (char == '&' && depth == 1) {
        endCell();
        index++;
        continue;
      }
      buffer.write(char);
      index++;
    }
    if (buffer.isNotEmpty || cells.isNotEmpty) endRow();
    if (rows.isEmpty) return null;
    return MathEnvironment(kind: kind, rows: rows, size: atSize);
  }

  /// Consumes an environment's body and returns it as written.
  String _skipEnvironment(String name) {
    final int start = index;
    int depth = 1;
    while (!done) {
      if (source[index] == '\\') {
        final int mark = index;
        index++;
        final String command = _readCommand();
        if (command == 'begin') {
          depth++;
        } else if (command == 'end') {
          depth--;
          if (depth == 0) {
            final String body = source.substring(start, mark);
            _verbatimGroup();
            return body;
          }
        }
        continue;
      }
      index++;
    }
    return source.substring(start);
  }

  /// Applies the accent that follows: a combining mark over the argument's own
  /// glyphs, which is how a host-free typewriter draws `\hat{x}` and `\vec{x}`.
  MathNode _accented(String command, double atSize) {
    final List<MathNode> argument = _argument(atSize);
    final String mark = switch (command) {
      'hat' || 'widehat' => '\u0302',
      'bar' || 'overline' => '\u0304',
      'vec' => '\u20D7',
      'tilde' => '\u0303',
      'dot' => '\u0307',
      'ddot' => '\u0308',
      _ => '',
    };
    final StringBuffer text = StringBuffer();
    for (final MathNode node in argument) {
      if (node is! MathText) {
        // A fraction or a script cannot carry a combining mark: keep the
        // argument as it is rather than dropping it.
        return MathGroup(argument, size: atSize);
      }
      text.write(node.text);
    }
    final String body = text.toString();
    if (body.isEmpty) return MathGroup(argument, size: atSize);
    // The mark rides on the last glyph.
    return MathText(
      body.substring(0, body.length - 1) + body[body.length - 1] + mark,
      size: atSize,
    );
  }

  /// `\mathbb{R}` and friends: the blackboard letters when one is the whole
  /// argument, otherwise the argument unchanged.
  static String _blackboard(String body) {
    const Map<String, String> letters = <String, String>{
      'R': '\u211D',
      'N': '\u2115',
      'Z': '\u2124',
      'Q': '\u211A',
      'C': '\u2102',
      'P': '\u2119',
    };
    final String trimmed = body.trim();
    return trimmed.length == 1 && letters.containsKey(trimmed)
        ? letters[trimmed]!
        : body;
  }

  /// Reads a `{…}` group as written, whitespace included.
  String _verbatimGroup() {
    while (!done && source[index] == ' ') {
      index++;
    }
    if (done) return '';
    if (source[index] != '{') {
      final String char = source[index];
      index++;
      return char;
    }
    index++;
    final int start = index;
    int depth = 1;
    while (!done && depth > 0) {
      if (source[index] == '{') depth++;
      if (source[index] == '}') depth--;
      if (depth == 0) break;
      index++;
    }
    final String text = source.substring(start, index);
    if (!done && source[index] == '}') index++;
    return text;
  }
}

/// Renders an expression with no host typesetter: fractions, radicals, scripts
/// and the symbol table above.
class AssistantMath extends StatelessWidget {
  const AssistantMath(
    this.tex, {
    super.key,
    this.size = 18,
    this.color,
    this.display = false,
  });

  final String tex;
  final double size;
  final Color? color;

  /// Display math is centred and a little larger, like `$$…$$`.
  final bool display;

  @override
  Widget build(BuildContext context) {
    final List<MathNode> nodes = parseMath(tex, size: 1);
    final double base = display ? size * 1.15 : size;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: display ? 6 : 0),
      child: MathRow(nodes: nodes, size: base, color: color),
    );
  }
}

/// Lays a node list out left to right, aligned on the math axis.
class MathRow extends StatelessWidget {
  const MathRow({
    super.key,
    required this.nodes,
    required this.size,
    this.color,
  });

  final List<MathNode> nodes;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        for (final MathNode node in nodes)
          MathNodeView(node: node, size: size, color: color),
      ],
    );
  }
}

/// One node, rendered.
class MathNodeView extends StatelessWidget {
  const MathNodeView({
    super.key,
    required this.node,
    required this.size,
    this.color,
  });

  final MathNode node;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color resolved =
        color ?? DefaultTextStyle.of(context).style.color ?? Colors.black;
    final MathNode current = node;
    switch (current) {
      case MathText():
        return Text(
          current.text,
          style: TextStyle(
            fontSize: size * current.size,
            color: resolved,
            fontStyle: current.italic ? FontStyle.italic : FontStyle.normal,
            fontWeight: current.bold ? FontWeight.w700 : null,
            fontFamily: current.italic ? 'serif' : null,
            height: 1.2,
          ),
        );
      case MathFraction():
        // The bar is the box's centre, so the row's axis runs through it.
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              MathRow(nodes: current.over, size: size * 0.92, color: resolved),
              Container(
                height: 1,
                constraints: BoxConstraints(minWidth: size * 0.6),
                color: resolved,
              ),
              MathRow(nodes: current.under, size: size * 0.92, color: resolved),
            ],
          ),
        );
      case MathRadical():
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '√',
              style: TextStyle(fontSize: size * 1.15, color: resolved),
            ),
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: resolved, width: 1)),
              ),
              padding: EdgeInsets.only(top: size * 0.08, left: size * 0.06),
              child: MathRow(nodes: current.body, size: size * 0.95, color: resolved),
            ),
          ],
        );
      case MathGroup():
        return MathRow(
          nodes: current.nodes,
          size: size * current.size,
          color: resolved,
        );
      case MathEnvironment():
        return _EnvironmentView(environment: current, size: size, color: resolved);
      case MathScript():
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            MathRow(nodes: current.base, size: size * current.size, color: resolved),
            Padding(
              padding: EdgeInsets.only(left: size * 0.06),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // The scripts hang off the base's axis: the superscript
                  // rises above it, the subscript drops below.
                  if (current.superscript != null)
                    Transform.translate(
                      offset: Offset(0, -size * 0.28),
                      child: MathRow(
                        nodes: current.superscript!,
                        size: size * 0.62,
                        color: resolved,
                      ),
                    ),
                  if (current.subscript != null)
                    Transform.translate(
                      offset: Offset(0, size * 0.28),
                      child: MathRow(
                        nodes: current.subscript!,
                        size: size * 0.62,
                        color: resolved,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
    }
  }
}

/// The block helper: the derivation steps the math element shows, with the
/// final expression typeset by [AssistantMath] instead of a host renderer.
class AssistantMathDisplay extends StatelessWidget {
  const AssistantMathDisplay({
    super.key,
    required this.steps,
    required this.visibleSteps,
    this.label,
  });

  final List<MathStep> steps;
  final int visibleSteps;
  final String? label;

  @override
  Widget build(BuildContext context) => AssistantMathBlock(
        steps: steps,
        visibleSteps: visibleSteps,
        label: label,
      );
}

/// A [MathStep] whose expression is typeset rather than passed in as a widget.
MathStep typesetStep(String expression, {String? note}) => MathStep(
      expression: AssistantMath(expression, display: true),
      note: note,
    );

/// Draws an environment: cells in a grid, with the delimiters its kind asks for.
class _EnvironmentView extends StatelessWidget {
  const _EnvironmentView({
    required this.environment,
    required this.size,
    required this.color,
  });

  final MathEnvironment environment;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double gutter = size * 0.35;
    final Widget grid = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        for (final (int rowIndex, List<List<MathNode>> cells)
            in environment.rows.indexed) ...<Widget>[
          if (rowIndex > 0) SizedBox(height: size * 0.42),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              for (final (int cellIndex, List<MathNode> cell)
                  in cells.indexed) ...<Widget>[
                if (cellIndex > 0) SizedBox(width: gutter * 2),
                MathRow(nodes: cell, size: size * 0.92, color: color),
              ],
            ],
          ),
        ],
      ],
    );

    final String? left = switch (environment.kind) {
      MathEnvironmentKind.pmatrix => '(',
      MathEnvironmentKind.bmatrix => '[',
      MathEnvironmentKind.cases => '{',
      _ => null,
    };
    final String? right = switch (environment.kind) {
      MathEnvironmentKind.pmatrix => ')',
      MathEnvironmentKind.bmatrix => ']',
      _ => null,
    };
    if (left == null && right == null) return grid;

    // The delimiters stretch with the grid, which is what makes `cases` read.
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (left != null)
            Text(
              left,
              style: TextStyle(fontSize: size * 2.2, height: 0.9, color: color),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.18),
            child: grid,
          ),
          if (right != null)
            Text(
              right,
              style: TextStyle(fontSize: size * 2.2, height: 0.9, color: color),
            ),
        ],
      ),
    );
  }
}
