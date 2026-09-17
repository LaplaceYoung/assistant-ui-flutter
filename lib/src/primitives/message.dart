import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../core/message.dart';
import '../core/message_part.dart';
import '../core/runtime_api.dart';
import 'state.dart';
import 'thread.dart';

/// Builds the UI for one tool call.
typedef AuiToolUIBuilder = Widget Function(
  BuildContext context,
  ToolCallPart part,
);

/// Builds the UI for one data part.
typedef AuiDataUIBuilder = Widget Function(BuildContext context, DataPart part);

/// Per-part override. Return null to fall back to the default rendering.
typedef AuiPartBuilder = Widget? Function(
  BuildContext context,
  MessagePart part,
  int index,
  PartStatus status,
);

/// Container for a single message: publishes message state to everything below
/// it and tracks hover, which the action bar consumes for auto-hide.
class AuiMessage extends StatefulWidget {
  const AuiMessage({
    super.key,
    this.message,
    this.isLast,
    required this.child,
  });

  /// Defaults to the message the enclosing [AuiThreadMessages] is iterating.
  final ThreadMessage? message;
  final bool? isLast;
  final Widget child;

  @override
  State<AuiMessage> createState() => _AuiMessageState();
}

class _AuiMessageState extends State<AuiMessage> {
  final ValueNotifier<bool> _hovered = ValueNotifier<bool>(false);
  AuiMessageRegistry? _registry;
  GlobalKey? _registryKey;
  String? _messageId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String messageId = _resolveMessage(context).id;
    final AuiMessageRegistry? registry =
        AuiMessageRegistryScope.maybeOf(context);
    final bool idChanged = messageId != _messageId;

    if (idChanged && _messageId != null) {
      _registry?.remove(_messageId!);
      _registryKey = null;
    }
    _messageId = messageId;
    _registry = registry;
    if (_registryKey == null && registry != null) {
      _registryKey = registry.keyFor(messageId);
    }
  }

  @override
  void dispose() {
    if (_messageId != null) _registry?.remove(_messageId!);
    _hovered.dispose();
    super.dispose();
  }

  ThreadMessage _resolveMessage(BuildContext context) {
    final ThreadMessage? explicit = widget.message;
    if (explicit != null) return explicit;
    final AuiCurrentMessage? current = AuiCurrentMessage.maybeOf(context);
    assert(
      current != null,
      'AuiMessage needs a message: pass one, or render it inside '
      'AuiThreadMessages.',
    );
    return current!.message;
  }

  @override
  Widget build(BuildContext context) {
    final ThreadMessage fallback = _resolveMessage(context);
    final bool isLast =
        widget.isLast ?? (AuiCurrentMessage.maybeOf(context)?.isLast ?? true);

    return AuiStateBuilder<({ThreadMessage message, bool isSpeaking})?>(
      selector: (AuiState state) {
        final ThreadMessage? message = state.thread.messageById(fallback.id);
        if (message == null) return null;
        return (
          message: message,
          isSpeaking: state.thread.speakingMessageId == message.id,
        );
      },
      builder: (
        BuildContext context,
        ({ThreadMessage message, bool isSpeaking})? value,
      ) {
        if (value == null) return const SizedBox.shrink();
        return AuiMessageHoverScope(
          hovered: _hovered,
          child: KeyedSubtree(
            key: _registryKey,
            child: Listener(
              onPointerDown: (_) => _hovered.value = true,
              onPointerHover: (_) => _hovered.value = true,
              onPointerCancel: (_) => _hovered.value = false,
              child: MouseRegion(
                onEnter: (_) => _hovered.value = true,
                onExit: (_) => _hovered.value = false,
                child: AuiMessageScope(
                  state: MessageState(
                    message: value.message,
                    isLast: isLast,
                    isSpeaking: value.isSpeaking,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Hover state of the enclosing message, consumed by `AuiActionBar`.
class AuiMessageHoverScope extends InheritedWidget {
  const AuiMessageHoverScope({
    super.key,
    required this.hovered,
    required super.child,
  });

  final ValueNotifier<bool> hovered;

  static ValueNotifier<bool>? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AuiMessageHoverScope>()
      ?.hovered;

  @override
  bool updateShouldNotify(AuiMessageHoverScope oldWidget) =>
      hovered != oldWidget.hovered;
}

/// One part inside a group handed to [AuiPartGroupBuilder].
@immutable
class AuiPartGroupMember {
  const AuiPartGroupMember({
    required this.part,
    required this.index,
    required this.status,
  });

  final MessagePart part;
  final int index;
  final PartStatus status;
}

/// Upstream's `groupBy`: return a key to fold this part into the group of the
/// part before it, or null to render it on its own.
typedef AuiPartGroupKey = String? Function(MessagePart part, int index);

/// Renders a run of consecutive parts that share a group key. The default
/// stacks the parts' own UIs the way they would have rendered ungrouped.
typedef AuiPartGroupBuilder = Widget Function(
  BuildContext context,
  String group,
  List<AuiPartGroupMember> members,
);

/// Renders every part of the current message.
///
/// Defaults follow the upstream pipeline: text renders as text with a
/// streaming indicator while it is the running part, images render inline,
/// tool calls render their registered UI or nothing, and reasoning, source,
/// file and data parts render nothing unless a builder is supplied.
///
/// [groupBy] plus [partGroupBuilder] are the `MessagePrimitive.GroupedParts`
/// mechanism: consecutive parts with the same non-null key render as one
/// block, which is how a run of tool calls collapses into a single card.
class AuiMessageParts extends StatelessWidget {
  const AuiMessageParts({
    super.key,
    this.partBuilder,
    this.toolUIs = const <String, AuiToolUIBuilder>{},
    this.fallbackToolUI,
    this.dataUIs = const <String, AuiDataUIBuilder>{},
    this.fallbackDataUI,
    this.textStyle,
    this.runningIndicator,
    this.spacing = 8,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    this.groupBy,
    this.partGroupBuilder,
  });

  final AuiPartBuilder? partBuilder;
  final Map<String, AuiToolUIBuilder> toolUIs;
  final AuiToolUIBuilder? fallbackToolUI;
  final Map<String, AuiDataUIBuilder> dataUIs;
  final AuiDataUIBuilder? fallbackDataUI;

  /// Applied to text parts; the styled layer supplies the theme's body style.
  final TextStyle? textStyle;

  /// Rendered after a text part that is still streaming. Defaults to a
  /// blinking block cursor.
  final Widget? runningIndicator;

  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;

  /// Groups runs of parts; see [AuiPartGroupKey].
  final AuiPartGroupKey? groupBy;

  /// Renders one group; without it grouped parts stack as if ungrouped.
  final AuiPartGroupBuilder? partGroupBuilder;

  @override
  Widget build(BuildContext context) {
    return AuiStateBuilder<MessageState?>(
      selector: (AuiState state) => state.message,
      builder: (BuildContext context, MessageState? messageState) {
        if (messageState == null) return const SizedBox.shrink();
        final ThreadMessage message = messageState.message;
        final List<Widget> children = <Widget>[];
        final String? Function(MessagePart, int)? groupBy = this.groupBy;

        int index = 0;
        while (index < message.content.length) {
          final MessagePart part = message.content[index];
          final PartStatus status = message.partStatus(index);
          final String? key = groupBy?.call(part, index);
          if (key != null) {
            final List<AuiPartGroupMember> members = <AuiPartGroupMember>[];
            while (index < message.content.length &&
                groupBy!(message.content[index], index) == key) {
              members.add(
                AuiPartGroupMember(
                  part: message.content[index],
                  index: index,
                  status: message.partStatus(index),
                ),
              );
              index++;
            }
            final Widget? group = partGroupBuilder?.call(context, key, members) ??
                _defaultGroup(context, members);
            if (group != null) {
              if (children.isNotEmpty) children.add(SizedBox(height: spacing));
              children.add(group);
            }
            continue;
          }
          final Widget? widget =
              partBuilder?.call(context, part, index, status) ??
                  _defaultPart(context, part, status);
          index++;
          if (widget == null) continue;
          if (children.isNotEmpty) children.add(SizedBox(height: spacing));
          children.add(widget);
        }
        if (children.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: crossAxisAlignment,
          mainAxisSize: MainAxisSize.min,
          children: children,
        );
      },
    );
  }

  Widget? _defaultGroup(
    BuildContext context,
    List<AuiPartGroupMember> members,
  ) {
    final List<Widget> children = <Widget>[];
    for (final AuiPartGroupMember member in members) {
      final Widget? widget = partBuilder?.call(
            context,
            member.part,
            member.index,
            member.status,
          ) ??
          _defaultPart(context, member.part, member.status);
      if (widget == null) continue;
      if (children.isNotEmpty) children.add(SizedBox(height: spacing));
      children.add(widget);
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: crossAxisAlignment,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget? _defaultPart(
    BuildContext context,
    MessagePart part,
    PartStatus status,
  ) {
    switch (part) {
      case TextPart():
        return AuiMessagePartText(
          part: part,
          status: status,
          style: textStyle,
          runningIndicator: runningIndicator,
        );
      case ImagePart():
        return AuiMessagePartImage(part: part);
      case ToolCallPart():
        return (toolUIs[part.toolName] ?? fallbackToolUI)?.call(context, part);
      case DataPart():
        return (dataUIs[part.name] ?? fallbackDataUI)?.call(context, part);
      case ReasoningPart():
      case SourcePart():
      case QuotePart():
      case FilePart():
        return null;
    }
  }
}

/// Text of a text part, plus a streaming indicator while it is the running
/// part.
class AuiMessagePartText extends StatelessWidget {
  const AuiMessagePartText({
    super.key,
    required this.part,
    this.status = PartStatus.complete,
    this.style,
    this.runningIndicator,
    this.softWrap = true,
  });

  final TextPart part;
  final PartStatus status;
  final TextStyle? style;
  final Widget? runningIndicator;
  final bool softWrap;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: style,
        children: <InlineSpan>[
          TextSpan(text: part.text),
          if (status == PartStatus.running)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: runningIndicator ?? const AuiStreamingCursor(),
            ),
        ],
      ),
      softWrap: softWrap,
    );
  }
}

/// Renders [child] only while the part at [index] is still streaming.
class AuiMessagePartInProgress extends StatelessWidget {
  const AuiMessagePartInProgress({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) => AuiStateBuilder<bool>(
        selector: (AuiState state) =>
            state.message?.message.partStatus(index) == PartStatus.running,
        builder: (BuildContext context, bool running) =>
            running ? child : const SizedBox.shrink(),
      );
}

/// Inline image part, supporting `data:` URIs and remote URLs.
class AuiMessagePartImage extends StatelessWidget {
  const AuiMessagePartImage({
    super.key,
    required this.part,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
  });

  final ImagePart part;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (part.image.startsWith('data:')) {
      final int comma = part.image.indexOf(',');
      if (comma != -1) {
        try {
          return Image.memory(
            base64Decode(part.image.substring(comma + 1)),
            width: width,
            height: height,
            fit: fit,
          );
        } on FormatException {
          return const SizedBox.shrink();
        }
      }
    }
    return Image.network(
      part.image,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

/// Blinking block cursor shown while text is streaming.
class AuiStreamingCursor extends StatefulWidget {
  const AuiStreamingCursor({super.key, this.height = 14, this.width = 2});

  final double height;
  final double width;

  @override
  State<AuiStreamingCursor> createState() => _AuiStreamingCursorState();
}

class _AuiStreamingCursorState extends State<AuiStreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color =
        DefaultTextStyle.of(context).style.color ?? const Color(0xFF000000);
    return FadeTransition(
      opacity: Tween<double>(begin: 0.25, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
