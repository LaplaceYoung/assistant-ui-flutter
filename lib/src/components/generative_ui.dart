import 'package:flutter/material.dart';

import 'markdown.dart';

/// Renders one component of a generative-UI payload.
typedef AuiGenerativeUIRenderer = Widget Function(
  BuildContext context,
  Map<String, Object?> properties,
  List<Widget> children,
);

/// Component name → renderer, the Dart side of a generative-UI library.
typedef AuiGenerativeUILibrary = Map<String, AuiGenerativeUIRenderer>;

/// The library upstream ships styled: a `Markdown` component rendered with
/// GitHub-flavored markdown. Everything else falls through to the host.
final AuiGenerativeUILibrary auiStyledGenerativeUILibrary =
    <String, AuiGenerativeUIRenderer>{
  'Markdown': (
    BuildContext context,
    Map<String, Object?> properties,
    List<Widget> children,
  ) {
    final Object? value = properties['value'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (value is String && value.isNotEmpty) AssistantMarkdown(text: value),
        ...children,
      ],
    );
  },
};

/// Renders the component a tool asked for, from a library of renderers — the
/// `generative-ui` element.
///
/// Upstream's library is a registry the runtime consults; the port keeps the
/// same shape, with [auiStyledGenerativeUILibrary] as the default entry set.
class AuiGenerativeUI extends StatelessWidget {
  const AuiGenerativeUI({
    super.key,
    required this.component,
    this.properties = const <String, Object?>{},
    this.children = const <Widget>[],
    this.library,
    this.fallback,
  });

  /// Component name, e.g. `Markdown`.
  final String component;

  /// Props the model supplied.
  final Map<String, Object?> properties;

  /// Nested components.
  final List<Widget> children;

  /// Overrides or extends [auiStyledGenerativeUILibrary].
  final AuiGenerativeUILibrary? library;

  /// Rendered when no renderer matches; upstream renders nothing.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final AuiGenerativeUIRenderer? renderer =
        library?[component] ?? auiStyledGenerativeUILibrary[component];
    if (renderer == null) return fallback ?? const SizedBox.shrink();
    return renderer(context, properties, children);
  }
}
