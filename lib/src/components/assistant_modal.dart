import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/runtime_api.dart';
import '../primitives/runtime_provider.dart';
import 'surfaces.dart';
import 'theme.dart';

/// Which pane the modal is showing.
enum AssistantModalView { thread, list }

/// The floating assistant: a bubble in the corner that opens a resizable
/// panel with the thread and the thread list — the `assistant-modal` element.
///
/// Upstream keeps the panel size in `localStorage`; the port reports it
/// through [onSizeChange] so the host decides where to persist it.
class AssistantModal extends StatefulWidget {
  const AssistantModal({
    super.key,
    this.thread,
    this.threadList,
    this.title = 'Assistant',
    this.open,
    this.onOpenChange,
    this.initiallyOpen = false,
    this.initialSize,
    this.onSizeChange,
    this.openOnRunStart = true,
    this.newThreadLabel = 'New thread',
  });

  /// The thread body, usually `AssistantThread`.
  final Widget? thread;

  /// The list pane, usually `AssistantThreadList`.
  final Widget? threadList;

  final String title;

  /// Bound open state; when null the widget owns it.
  final bool? open;
  final ValueChanged<bool>? onOpenChange;
  final bool initiallyOpen;

  /// Panel size to start from; clamped to the viewport like upstream.
  final Size? initialSize;
  final ValueChanged<Size>? onSizeChange;

  /// Opens the panel when a run starts, as upstream's event hook does.
  final bool openOnRunStart;

  final String newThreadLabel;

  /// Upstream's floor for the panel.
  static const Size minSize = Size(320, 400);

  /// Room upstream keeps for the bubble and its offset.
  static const Size viewportInset = Size(32, 96);

  /// Nudge per arrow press; shift multiplies it by four.
  static const double resizeStep = 16;

  @override
  State<AssistantModal> createState() => _AssistantModalState();
}

class _AssistantModalState extends State<AssistantModal> {
  late bool _open = widget.open ?? widget.initiallyOpen;
  late Size _size = widget.initialSize ?? const Size(400, 500);
  AssistantModalView _view = AssistantModalView.thread;
  AssistantRuntime? _runtime;
  bool _wasRunning = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    if (identical(runtime, _runtime)) return;
    _runtime?.removeListener(_onRuntime);
    _runtime = runtime..addListener(_onRuntime);
    _wasRunning = runtime.state.thread.isRunning;
  }

  @override
  void dispose() {
    _runtime?.removeListener(_onRuntime);
    super.dispose();
  }

  void _onRuntime() {
    final bool running = _runtime?.state.thread.isRunning ?? false;
    final bool started = running && !_wasRunning;
    _wasRunning = running;
    if (started && widget.openOnRunStart && !_open) {
      setState(() {
        _view = AssistantModalView.thread;
        _open = true;
      });
    }
  }

  void _setOpen(bool open) {
    if (widget.open == null) {
      setState(() {
        _open = open;
        if (open) _view = AssistantModalView.thread;
      });
    }
    widget.onOpenChange?.call(open);
  }

  Size _clamp(Size size, Size viewport) {
    final double maxWidth =
        (viewport.width - AssistantModal.viewportInset.width)
            .clamp(AssistantModal.minSize.width, double.infinity);
    final double maxHeight =
        (viewport.height - AssistantModal.viewportInset.height)
            .clamp(AssistantModal.minSize.height, double.infinity);
    return Size(
      size.width.clamp(AssistantModal.minSize.width, maxWidth),
      size.height.clamp(AssistantModal.minSize.height, maxHeight),
    );
  }

  void _applySize(Size size, Size viewport) {
    final Size next = _clamp(size, viewport);
    setState(() => _size = next);
    widget.onSizeChange?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    final Size viewport = MediaQuery.sizeOf(context);
    final Size clamped = _clamp(_size, viewport);

    return Stack(
      children: <Widget>[
        if (_open)
          Positioned(
            right: 16,
            bottom: 76,
            child: SizedBox(
              width: clamped.width,
              height: clamped.height,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: auiFg(theme, 0.1),
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: theme.brightness == Brightness.dark ? 0.6 : 0.25,
                      ),
                      blurRadius: 48,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _ResizeHandle(
                      onDelta: (Offset delta) => _applySize(
                        Size(_size.width - delta.dx, _size.height - delta.dy),
                        viewport,
                      ),
                      onReset: () => _applySize(
                        widget.initialSize ?? const Size(400, 500),
                        viewport,
                      ),
                    ),
                    _Header(
                      title: widget.title,
                      view: _view,
                      newThreadLabel: widget.newThreadLabel,
                      onViewChange: (AssistantModalView view) =>
                          setState(() => _view = view),
                      onNewThread: () {
                        // `create` switches to the new thread and empties it.
                        _runtime?.threads.create();
                        setState(() => _view = AssistantModalView.thread);
                      },
                      onClose: () => _setOpen(false),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _view.index,
                        children: <Widget>[
                          widget.thread ?? const SizedBox.shrink(),
                          widget.threadList ?? const SizedBox.shrink(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: Semantics(
            button: true,
            expanded: _open,
            label: _open ? 'Close the assistant' : 'Open the assistant',
            child: GestureDetector(
              onTap: () => _setOpen(!_open),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: auiFg(theme, 0.1)),
                ),
                child: Icon(
                  Icons.smart_toy_outlined,
                  size: 20,
                  color: theme.primaryForeground,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The grip that resizes the panel: drag it, or nudge it with the arrows.
class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onDelta, required this.onReset});

  final ValueChanged<Offset> onDelta;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (FocusNode node, KeyEvent event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.space) {
          onReset();
          return KeyEventResult.handled;
        }
        final double step = HardwareKeyboard.instance.isShiftPressed
            ? AssistantModal.resizeStep * 4
            : AssistantModal.resizeStep;
        final double? dx = switch (event.logicalKey) {
          LogicalKeyboardKey.arrowLeft => -step,
          LogicalKeyboardKey.arrowRight => step,
          _ => null,
        };
        final double? dy = switch (event.logicalKey) {
          LogicalKeyboardKey.arrowUp => -step,
          LogicalKeyboardKey.arrowDown => step,
          _ => null,
        };
        if (dx == null && dy == null) return KeyEventResult.ignored;
        // The grip moves the top edge: dragging up grows the panel.
        onDelta(Offset(dx ?? 0, -(dy ?? 0)));
        return KeyEventResult.handled;
      },
      child: Semantics(
        container: true,
        button: true,
        label: 'Resize the panel',
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUpLeftDownRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: onReset,
            onPanUpdate: (DragUpdateDetails details) => onDelta(details.delta),
            child: SizedBox(
              height: 12,
              width: double.infinity,
              child: Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: auiFg(theme(context), 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static AssistantTheme theme(BuildContext context) =>
      AssistantTheme.of(context);
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.view,
    required this.newThreadLabel,
    required this.onViewChange,
    required this.onNewThread,
    required this.onClose,
  });

  final String title;
  final AssistantModalView view;
  final String newThreadLabel;
  final ValueChanged<AssistantModalView> onViewChange;
  final VoidCallback onNewThread;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final AssistantTheme theme = AssistantTheme.of(context);
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: auiFg(theme, 0.1))),
      ),
      padding: const EdgeInsets.only(left: 14, right: 8),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.smart_toy_outlined,
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
                fontSize: 13.5,
                height: 1.2,
                fontWeight: FontWeight.w500,
                color: theme.foreground,
              ),
            ),
          ),
          AuiIconAction(
            icon: view == AssistantModalView.list
                ? Icons.chat_bubble_outline
                : Icons.history,
            label: view == AssistantModalView.list
                ? 'Back to the thread'
                : 'Show the thread list',
            size: 28,
            onPressed: () => onViewChange(
              view == AssistantModalView.list
                  ? AssistantModalView.thread
                  : AssistantModalView.list,
            ),
          ),
          AuiIconAction(
            icon: Icons.add,
            label: newThreadLabel,
            size: 28,
            onPressed: onNewThread,
          ),
          AuiIconAction(
            icon: Icons.close,
            label: 'Close the assistant',
            size: 28,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
