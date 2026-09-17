import 'package:flutter/material.dart';

import '../core/message_part.dart';

/// The wire key naming the component to render. `$`-prefixed keys stay
/// framework-reserved, so a component may use `type`, `status`, `variant`, …
/// as ordinary props.
const String generativeUiTypeKey = r'$type';

/// The deepest tree that is rendered or serialized; input is model-produced,
/// so a runaway response stops here instead of overflowing the stack.
const int generativeUiMaxDepth = 64;

/// Keys the framework reserves: everything else is a component prop.
const Set<String> generativeUiReservedKeys = <String>{
  generativeUiTypeKey,
  r'$key',
  r'$action',
  r'$status',
  'children',
};

/// One node of the model-emitted tree.
class GenerativeUiNode {
  const GenerativeUiNode({
    required this.type,
    required this.props,
    required this.children,
    this.key,
    this.action,
    this.status,
  });

  /// The component name.
  final String type;

  /// Inline props, reserved keys removed.
  final Map<String, Object?> props;

  /// The nested children, already parsed.
  final List<GenerativeUiNode> children;

  final String? key;

  /// The action name a clickable node fires.
  final String? action;

  final String? status;

  /// The action a clickable node fires, and the props it carries along.
  ({String name, Map<String, Object?> props, String? nodeId})? get actionRef =>
      action == null
          ? null
          : (
              name: action!,
              props: props,
              nodeId: props['id'] as String?,
            );

  /// Parses a node, or returns null when it is not renderable yet. The legacy
  /// `component` key is accepted as an alias for the type.
  static GenerativeUiNode? fromJson(Object? raw, {int depth = 0}) {
    if (depth > generativeUiMaxDepth) return null;
    if (raw is! Map<String, Object?>) return null;
    final Object? type =
        raw[generativeUiTypeKey] ?? raw['component'] ?? raw[r'$component'];
    if (type is! String || type.isEmpty) return null;

    final Map<String, Object?> props = <String, Object?>{};
    for (final MapEntry<String, Object?> entry in raw.entries) {
      if (generativeUiReservedKeys.contains(entry.key)) continue;
      if (entry.key == 'component') continue;
      props[entry.key] = entry.value;
    }

    final List<GenerativeUiNode> children = <GenerativeUiNode>[];
    final Object? rawChildren = raw['children'];
    void collect(Object? value) {
      if (value is List<Object?>) {
        for (final Object? entry in value) {
          collect(entry);
        }
        return;
      }
      final GenerativeUiNode? child =
          GenerativeUiNode.fromJson(value, depth: depth + 1);
      if (child != null) children.add(child);
    }

    collect(rawChildren);

    return GenerativeUiNode(
      type: type,
      props: props,
      children: children,
      key: raw[r'$key'] as String?,
      action: raw[r'$action'] as String?,
      status: raw[r'$status'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        generativeUiTypeKey: type,
        if (key != null) r'$key': key,
        if (action != null) r'$action': action,
        if (status != null) r'$status': status,
        ...props,
        if (children.isNotEmpty)
          'children': <Map<String, Object?>>[
            for (final GenerativeUiNode child in children) child.toJson(),
          ],
      };
}

/// Parses a model payload: a single node, or a list of them.
List<GenerativeUiNode> parseGenerativeUi(Object? payload) {
  final List<GenerativeUiNode> nodes = <GenerativeUiNode>[];
  void collect(Object? value) {
    if (value is List<Object?>) {
      for (final Object? entry in value) {
        collect(entry);
      }
      return;
    }
    final GenerativeUiNode? node = GenerativeUiNode.fromJson(value);
    if (node != null) nodes.add(node);
  }

  collect(payload);
  return nodes;
}

/// Serializes a tree back to JSX-like source: the "view source" of what the
/// model produced. Faithful textual rendering, not a parser — text children
/// are verbatim unless [escape] is set, when a child holding `<`, `>`, `&`,
/// `{` or `}` becomes a quoted expression.
String generativeUiToJsx(
  Object? node, {
  bool escape = false,
  bool pretty = false,
}) =>
    _toJsx(node, 0, escape, pretty, 0);

String _toJsx(Object? node, int depth, bool escape, bool pretty, int indent) {
  if (depth > generativeUiMaxDepth) return '';
  if (node == null || node is bool) return '';
  if (node is String) return _childText(node, escape);
  if (node is num) return '$node';
  if (node is List<Object?>) {
    if (pretty) {
      return _blockLines(node, depth, escape, indent).join('\n');
    }
    return node
        .map((Object? child) => _toJsx(child, depth + 1, escape, false, 0))
        .join();
  }
  if (node is! Map<String, Object?>) return '';

  final Object? type = node[generativeUiTypeKey] ?? node['component'];
  if (type is! String) return '';
  final StringBuffer attrs = StringBuffer(_attr('key', node[r'$key']));
  for (final MapEntry<String, Object?> entry in node.entries) {
    if (generativeUiReservedKeys.contains(entry.key)) continue;
    if (entry.key == 'component') continue;
    attrs.write(_attr(entry.key, entry.value));
  }

  final Object? children = node['children'];
  final String pad = '  ' * indent;

  if (!pretty) {
    final String inner =
        children == null ? '' : _toJsx(children, depth + 1, escape, false, 0);
    return inner.isEmpty
        ? '<$type$attrs />'
        : '<$type$attrs>$inner</$type>';
  }

  if (children == null || !_hasElementChild(children)) {
    final String inner =
        children == null ? '' : _toJsx(children, depth + 1, escape, false, 0);
    return inner.isEmpty
        ? '$pad<$type$attrs />'
        : '$pad<$type$attrs>$inner</$type>';
  }

  final List<String> lines =
      _blockLines(children, depth + 1, escape, indent + 1);
  if (lines.isEmpty) return '$pad<$type$attrs />';
  return '$pad<$type$attrs>\n${lines.join('\n')}\n$pad</$type>';
}

bool _hasElementChild(Object? node, [int depth = 0]) {
  if (depth > generativeUiMaxDepth) return false;
  if (node is List<Object?>) {
    return node.any((Object? child) => _hasElementChild(child, depth + 1));
  }
  return node is Map<String, Object?> &&
      (node[generativeUiTypeKey] ?? node['component']) is String;
}

List<String> _blockLines(Object? node, int depth, bool escape, int indent) {
  if (depth > generativeUiMaxDepth) return const <String>[];
  if (node == null || node is bool) return const <String>[];
  if (node is List<Object?>) {
    return <String>[
      for (final Object? child in node)
        ..._blockLines(child, depth + 1, escape, indent),
    ];
  }
  if (node is String) return <String>['${'  ' * indent}${_childText(node, escape)}'];
  if (node is num) return <String>['${'  ' * indent}$node'];
  final String rendered = _toJsx(node, depth, escape, true, indent);
  return rendered.isEmpty ? const <String>[] : <String>[rendered];
}

String _childText(String value, bool escape) {
  final String quoted = escape && value.contains(RegExp(r'[<>&{}]'))
      ? '{$value}'
      : value;
  return quoted;
}

String _attr(String key, Object? value) {
  if (value == null) return '';
  if (value == true) return ' $key';
  if (value is String) {
    return value.contains('"') || value.contains('\n')
        ? ' $key={${_json(value)}}'
        : ' $key="$value"';
  }
  return ' $key={${_json(value)}}';
}

String _json(Object? value) {
  if (value is String) return '"${value.replaceAll('"', r'\"')}"';
  if (value is num || value is bool) return '$value';
  if (value is List<Object?>) {
    return '[${value.map(_json).join(',')}]';
  }
  if (value is Map<String, Object?>) {
    return '{${value.entries.map((MapEntry<String, Object?> e) => '${_json(e.key)}:${_json(e.value)}').join(',')}}';
  }
  return 'null';
}

/// Builds a widget for one node.
typedef GenerativeUiBuilder = Widget Function(
  BuildContext context,
  GenerativeUiNode node,
  GenerativeUiRenderContext render,
);

/// What a builder needs to render its children and fire actions.
class GenerativeUiRenderContext {
  const GenerativeUiRenderContext({this.registry, this.onAction});

  final GenerativeUiRegistry? registry;

  /// Called with the action name and the node that fired it.
  final void Function(String action, GenerativeUiNode node)? onAction;

  /// Renders the children of [node].
  List<Widget> children(GenerativeUiNode node) => <Widget>[
        for (final GenerativeUiNode child in node.children)
          GenerativeUi(node: child, registry: registry, onAction: onAction),
      ];
}

/// The host's component vocabulary: a name per renderer.
class GenerativeUiRegistry {
  const GenerativeUiRegistry(this.builders);

  /// The vocabulary the reference implementation ships for simple trees.
  factory GenerativeUiRegistry.standard() =>
      const GenerativeUiRegistry(<String, GenerativeUiBuilder>{
        'Text': _text,
        'Heading': _heading,
        'Card': _card,
        'Stack': _stack,
        'Button': _button,
        'Alert': _alert,
        'Image': _image,
      });

  final Map<String, GenerativeUiBuilder> builders;

  GenerativeUiRegistry merge(GenerativeUiRegistry other) => GenerativeUiRegistry(
        <String, GenerativeUiBuilder>{...builders, ...other.builders},
      );

  GenerativeUiBuilder? operator [](String type) => builders[type];
}

/// Renders one node with the registry, falling back to a readable placeholder
/// for a component the host has not registered.
class GenerativeUi extends StatelessWidget {
  const GenerativeUi({
    super.key,
    required this.node,
    this.registry,
    this.onAction,
  });

  final GenerativeUiNode node;
  final GenerativeUiRegistry? registry;
  final void Function(String action, GenerativeUiNode node)? onAction;

  @override
  Widget build(BuildContext context) {
    final GenerativeUiRenderContext render = GenerativeUiRenderContext(
      registry: registry,
      onAction: onAction,
    );
    final GenerativeUiBuilder? builder = registry?[node.type];
    final Widget child = builder != null
        ? builder(context, node, render)
        : _unknown(context, node);

    final String? action = node.action;
    if (action == null || onAction == null) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onAction!(action, node),
      child: child,
    );
  }

  Widget _unknown(BuildContext context, GenerativeUiNode node) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          node.type,
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
      );
}

// --- the standard vocabulary ---------------------------------------------------

String _string(GenerativeUiNode node, String key) {
  final Object? value = node.props[key];
  return value is String ? value : (value?.toString() ?? '');
}

Widget _text(BuildContext context, GenerativeUiNode node, GenerativeUiRenderContext render) =>
    Text(
      _string(node, 'text').isEmpty ? _collectText(node) : _string(node, 'text'),
      style: TextStyle(
        fontSize: switch (_string(node, 'size')) {
          'sm' => 13,
          'lg' => 17,
          'xl' => 20,
          '2xl' => 24,
          '3xl' => 30,
          _ => 15,
        },
        fontWeight: switch (_string(node, 'weight')) {
          'medium' => FontWeight.w500,
          'semibold' => FontWeight.w600,
          'bold' => FontWeight.w700,
          _ => FontWeight.w400,
        },
        color: switch (_string(node, 'color')) {
          'secondary' => Theme.of(context).textTheme.bodySmall?.color,
          'emphasis' => Theme.of(context).colorScheme.onSurface,
          'alpha-70' => Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
          _ => null,
        },
      ),
    );

Widget _heading(BuildContext context, GenerativeUiNode node, GenerativeUiRenderContext render) =>
    Text(
      _string(node, 'text').isEmpty ? _collectText(node) : _string(node, 'text'),
      style: Theme.of(context).textTheme.titleMedium,
    );

Widget _card(BuildContext context, GenerativeUiNode node, GenerativeUiRenderContext render) =>
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_string(node, 'title').isNotEmpty) ...<Widget>[
            Text(
              _string(node, 'title'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
          ],
          ...render.children(node),
        ],
      ),
    );

Widget _stack(BuildContext context, GenerativeUiNode node, GenerativeUiRenderContext render) {
  final String direction = _string(node, 'direction').isEmpty
      ? 'vertical'
      : _string(node, 'direction');
  final double gap = switch (_string(node, 'gap')) {
    'sm' => 6,
    'lg' => 18,
    _ => 10,
  };
  final List<Widget> children = render.children(node);
  if (direction == 'horizontal') {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < children.length; i++) ...<Widget>[
          if (i > 0) SizedBox(width: gap),
          children[i],
        ],
      ],
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (int i = 0; i < children.length; i++) ...<Widget>[
        if (i > 0) SizedBox(height: gap),
        children[i],
      ],
    ],
  );
}

Widget _button(BuildContext context, GenerativeUiNode node, GenerativeUiRenderContext render) {
  final String variant = _string(node, 'variant').isEmpty
      ? (_string(node, 'style').isEmpty ? 'primary' : _string(node, 'style'))
      : _string(node, 'variant');
  final String label =
      _string(node, 'label').isEmpty ? _string(node, 'text') : _string(node, 'label');
  final bool solid = variant == 'primary';
  final bool danger = variant == 'danger';
  return FilledButton(
    // The button owns its own press: a nested FilledButton would swallow the
    // wrapper's tap, so the action fires here.
    onPressed: node.action == null
        ? null
        : () => render.onAction?.call(node.action!, node),
    style: FilledButton.styleFrom(
      backgroundColor: solid
          ? (danger
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.primary)
          : null,
      foregroundColor: solid
          ? Theme.of(context).colorScheme.onPrimary
          : Theme.of(context).colorScheme.primary,
      side: solid
          ? null
          : BorderSide(color: Theme.of(context).colorScheme.outline),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    child: Text(label),
  );
}

Widget _alert(BuildContext context, GenerativeUiNode node, GenerativeUiRenderContext render) {
  final String tone =
      _string(node, 'tone').isEmpty ? 'info' : _string(node, 'tone');
  final Color color = switch (tone) {
    'success' => const Color(0xFF16A34A),
    'warning' => const Color(0xFFD97706),
    'danger' => Theme.of(context).colorScheme.error,
    _ => Theme.of(context).colorScheme.primary,
  };
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      border: Border.all(color: color.withValues(alpha: 0.4)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (_string(node, 'title').isNotEmpty)
          Text(
            _string(node, 'title'),
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        if (_string(node, 'text').isNotEmpty)
          Text(_string(node, 'text'), style: TextStyle(color: color)),
        ...render.children(node),
      ],
    ),
  );
}

Widget _image(BuildContext context, GenerativeUiNode node, GenerativeUiRenderContext render) {
  final String src = _string(node, 'src').isEmpty
      ? _string(node, 'url')
      : _string(node, 'src');
  final double? size = node.props['size'] is num
      ? (node.props['size']! as num).toDouble()
      : switch (_string(node, 'size')) {
          'sm' => 48,
          'md' => 96,
          'lg' => 180,
          _ => null,
        };
  if (src.isEmpty) {
    return const SizedBox.shrink();
  }
  return Image.network(
    src,
    width: size,
    height: size,
    errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
        const SizedBox.shrink(),
  );
}

String _collectText(GenerativeUiNode node) => <String>[
      for (final GenerativeUiNode child in node.children)
        if (child.type == 'Text')
          _string(child, 'text').isEmpty ? _collectText(child) : _string(child, 'text'),
    ].join(' ');

/// The data part name a generative-UI payload travels under.
const String generativeUiPartName = 'generative-ui';

/// Reads the nodes out of a data part, when it is a generative-UI payload.
List<GenerativeUiNode> generativeUiFromPart(MessagePart part) =>
    part is DataPart && part.name == generativeUiPartName
        ? parseGenerativeUi(part.data)
        : const <GenerativeUiNode>[];
