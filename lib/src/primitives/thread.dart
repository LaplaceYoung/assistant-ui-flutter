import 'package:flutter/widgets.dart';

import '../core/message.dart';
import '../core/runtime_api.dart';
import 'runtime_provider.dart';
import 'state.dart';

/// Where the thread anchors when new content arrives.
enum AuiTurnAnchor {
  /// Classic chat behavior: stay pinned to the bottom.
  bottom,

  /// Pin the latest user message to the top so the answer flows below it.
  top,
}

/// Root of a thread layout. Just a stretched `Column`, so the viewport and the
/// footer stack the way a chat screen expects.
class AuiThread extends StatelessWidget {
  const AuiThread({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
}

/// The common thread composition: viewport on top, footer pinned below it.
class AuiThreadLayout extends StatelessWidget {
  const AuiThreadLayout({
    super.key,
    required this.viewport,
    this.footer,
  });

  final Widget viewport;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => AuiThread(
        children: <Widget>[
          Expanded(child: viewport),
          if (footer != null) footer!,
        ],
      );
}

/// Scrollable message container with auto-scroll.
///
/// Auto-scroll follows new content while the reader stays near the bottom, and
/// stops as soon as they scroll up. With [AuiTurnAnchor.top] a new run instead
/// scrolls the latest user message to the top of the viewport.
class AuiThreadViewport extends StatefulWidget {
  const AuiThreadViewport({
    super.key,
    required this.child,
    this.autoScroll,
    this.turnAnchor = AuiTurnAnchor.bottom,
    this.padding = EdgeInsets.zero,
    this.physics,
    this.scrollToBottomOnRunStart = true,
    this.scrollToBottomOnInitialize = true,
    this.unpinnedOverlay,
  });

  final Widget child;

  /// Defaults to true for [AuiTurnAnchor.bottom] and false for
  /// [AuiTurnAnchor.top].
  final bool? autoScroll;

  final AuiTurnAnchor turnAnchor;
  final EdgeInsets padding;
  final ScrollPhysics? physics;
  final bool scrollToBottomOnRunStart;
  final bool scrollToBottomOnInitialize;

  /// Floated over the bottom edge while the reader has scrolled away from the
  /// newest message; tapping it scrolls back (`scroll-anchor`). The viewport
  /// owns the scroll position, so it owns the tap.
  final Widget? unpinnedOverlay;

  @override
  State<AuiThreadViewport> createState() => _AuiThreadViewportState();
}

class _AuiThreadViewportState extends State<AuiThreadViewport> {
  final ScrollController _controller = ScrollController();
  final AuiMessageRegistry _registry = AuiMessageRegistry();

  AssistantRuntime? _runtime;
  bool _stickToBottom = true;
  int _lastMessageCount = 0;
  bool _wasRunning = false;

  bool get _autoScroll =>
      widget.autoScroll ?? widget.turnAnchor == AuiTurnAnchor.bottom;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    if (!identical(_runtime, runtime)) {
      _runtime?.removeListener(_onRuntimeChanged);
      _runtime = runtime..addListener(_onRuntimeChanged);
      _lastMessageCount = runtime.state.thread.messages.length;
    }
  }

  @override
  void dispose() {
    _runtime?.removeListener(_onRuntimeChanged);
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final double distanceFromBottom =
        _controller.position.maxScrollExtent - _controller.position.pixels;
    _stickToBottom = distanceFromBottom < 56;
  }

  void _onRuntimeChanged() {
    final AssistantRuntime? runtime = _runtime;
    if (runtime == null || !mounted) return;

    final ThreadState thread = runtime.state.thread;
    final int messageCount = thread.messages.length;
    final bool wasEmpty = _lastMessageCount == 0;
    final bool runStarted = thread.isRunning && !_wasRunning;
    final bool newMessage = messageCount != _lastMessageCount;

    _wasRunning = thread.isRunning;
    _lastMessageCount = messageCount;

    if (runStarted && widget.turnAnchor == AuiTurnAnchor.top) {
      _anchorLatestTurn();
      return;
    }
    if (runStarted && widget.scrollToBottomOnRunStart && _autoScroll) {
      _scrollToBottom();
      return;
    }
    if (wasEmpty && messageCount > 0) {
      if (widget.scrollToBottomOnInitialize && _autoScroll) _scrollToBottom();
      return;
    }
    if (_autoScroll && (newMessage || thread.isRunning) && _stickToBottom) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.jumpTo(_controller.position.maxScrollExtent);
    });
  }

  /// Pins the latest user message to the top of the viewport.
  void _anchorLatestTurn() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ThreadMessage? userMessage =
          _runtime?.state.thread.lastUserMessage;
      if (userMessage == null) return;
      final BuildContext? target = _registry.contextOf(userMessage.id);
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _jumpToBottom() {
    if (!_controller.hasClients) return;
    _controller.animateTo(
      _controller.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget list = ListView(
      controller: _controller,
      padding: widget.padding,
      physics: widget.physics,
      children: <Widget>[widget.child],
    );
    if (widget.unpinnedOverlay == null) {
      return AuiMessageRegistryScope(registry: _registry, child: list);
    }
    return AuiMessageRegistryScope(
      registry: _registry,
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: list),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: AnimatedOpacity(
                opacity: _stickToBottom ? 0 : 1,
                duration: const Duration(milliseconds: 150),
                child: IgnorePointer(
                  ignoring: _stickToBottom,
                  child: GestureDetector(
                    onTap: _jumpToBottom,
                    child: widget.unpinnedOverlay,
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

/// Keeps the [BuildContext] of each rendered message so the viewport can scroll
/// to a specific one. Populated by `AuiMessage`.
class AuiMessageRegistry {
  final Map<String, GlobalKey> _keys = <String, GlobalKey>{};

  GlobalKey keyFor(String messageId) =>
      _keys.putIfAbsent(messageId, GlobalKey.new);

  BuildContext? contextOf(String messageId) => _keys[messageId]?.currentContext;

  void remove(String messageId) => _keys.remove(messageId);
}

class AuiMessageRegistryScope extends InheritedWidget {
  const AuiMessageRegistryScope({
    super.key,
    required this.registry,
    required super.child,
  });

  final AuiMessageRegistry registry;

  static AuiMessageRegistry? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AuiMessageRegistryScope>()
      ?.registry;

  @override
  bool updateShouldNotify(AuiMessageRegistryScope oldWidget) =>
      registry != oldWidget.registry;
}

/// Iterator over the thread's messages.
///
/// ```dart
/// AuiThreadMessages(
///   builder: (context, message, isLast) =>
///       AuiMessage(child: MyBubble(message: message)),
/// );
/// ```
class AuiThreadMessages extends StatelessWidget {
  const AuiThreadMessages({
    super.key,
    required this.builder,
    this.separator,
  });

  final Widget Function(
    BuildContext context,
    ThreadMessage message,
    bool isLast,
  ) builder;
  final Widget? separator;

  @override
  Widget build(BuildContext context) {
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    return AnimatedBuilder(
      animation: runtime,
      builder: (BuildContext context, Widget? _) {
        final List<ThreadMessage> messages = runtime.state.thread.messages;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < messages.length; i++) ...<Widget>[
              if (separator != null && i > 0) separator!,
              AuiCurrentMessage(
                message: messages[i],
                isLast: i == messages.length - 1,
                child: Builder(
                  builder: (BuildContext context) =>
                      builder(context, messages[i], i == messages.length - 1),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Footer slot of a thread, placed below the viewport. Use it for the composer.
class AuiThreadFooter extends StatelessWidget {
  const AuiThreadFooter({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      );
}

/// Scrolls the nearest scrollable to its end when tapped — the
/// "jump to latest" control.
/// Scrolls the thread to the end when tapped — upstream's `scroll-anchor`
/// affordance.
///
/// [showWhenUnpinned] drives the pill the way upstream does: it appears only
/// while the viewport is not pinned to the bottom, so a reader who scrolled up
/// gets one tap back to the newest message.
class AuiThreadScrollToBottom extends StatefulWidget {
  const AuiThreadScrollToBottom({
    super.key,
    required this.child,
    this.showWhenUnpinned = false,
    this.bottomOffset = 16,
  });

  final Widget child;

  /// Hides the child unless the viewport is scrolled away from the end.
  final bool showWhenUnpinned;

  /// Distance from the bottom of the list when floating the child.
  final double bottomOffset;

  @override
  State<AuiThreadScrollToBottom> createState() =>
      _AuiThreadScrollToBottomState();
}

class _AuiThreadScrollToBottomState extends State<AuiThreadScrollToBottom> {
  ScrollPosition? _position;
  bool _atEnd = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ScrollPosition? position = Scrollable.maybeOf(context)?.position;
    if (position == _position) return;
    _position?.removeListener(_onScroll);
    _position = position;
    _position?.addListener(_onScroll);
    _onScroll();
  }

  @override
  void dispose() {
    _position?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final ScrollPosition? position = _position;
    if (position == null) return;
    final bool atEnd =
        position.maxScrollExtent - position.pixels <= 24;
    if (atEnd != _atEnd) setState(() => _atEnd = atEnd);
  }

  void _jump() {
    final ScrollPosition? position = _position;
    if (position == null) return;
    position.animateTo(
      position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hidden = widget.showWhenUnpinned && _atEnd;
    return GestureDetector(
      onTap: _jump,
      child: AnimatedOpacity(
        opacity: hidden ? 0 : 1,
        duration: const Duration(milliseconds: 150),
        child: AnimatedScale(
          scale: hidden ? 0.9 : 1,
          duration: const Duration(milliseconds: 150),
          child: IgnorePointer(
            ignoring: hidden,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
