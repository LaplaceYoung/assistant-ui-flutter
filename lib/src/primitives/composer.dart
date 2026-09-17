import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/attachments.dart';
import '../core/runtime_api.dart';
import 'composer_triggers.dart';
import 'runtime_provider.dart';
import 'state.dart';

/// How Enter submits.
enum AuiSubmitMode {
  /// Keyboard submission disabled.
  none,

  /// Enter submits, Shift+Enter inserts a newline.
  enter,

  /// Ctrl/Cmd+Enter submits, Enter inserts a newline.
  ctrlEnter,
}

/// Text input wired to the composer.
///
/// Placed in a thread it composes a new message; placed inside an
/// `AuiMessage` it edits that message. The runtime decides based on the
/// composer's editing state, so the same widget serves both.
class AuiComposerInput extends StatefulWidget {
  const AuiComposerInput({
    super.key,
    this.placeholder,
    this.submitMode = AuiSubmitMode.enter,
    this.cancelOnEscape = true,
    this.autofocus = false,
    this.maxLines = 6,
    this.minLines = 1,
    this.style,
    this.textAlignVertical,
    this.keyboardType = TextInputType.multiline,
    this.controller,
    this.focusNode,
    this.decoration,
    this.onSubmitted,
  });

  final String? placeholder;
  final AuiSubmitMode submitMode;
  final bool cancelOnEscape;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final TextStyle? style;
  final TextAlignVertical? textAlignVertical;
  final TextInputType? keyboardType;

  /// Optional externally-owned controller, for hosts that need to drive the
  /// field themselves.
  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Optional decoration; when supplied it replaces the default styling.
  final InputDecoration? decoration;

  final ValueChanged<String>? onSubmitted;

  @override
  State<AuiComposerInput> createState() => _AuiComposerInputState();
}

class _AuiComposerInputState extends State<AuiComposerInput> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  AssistantRuntime? _runtime;
  AuiTriggerController? _triggers;

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = _handleKeyEvent;
    // The controller is the source of truth for what the field shows, so
    // programmatic edits (mention insertion, for example) reach the runtime
    // too — onChanged only fires for user typing.
    _controller.addListener(_mirrorToRuntime);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    if (!identical(_runtime, runtime)) {
      _runtime?.removeListener(_syncFromRuntime);
      _runtime = runtime..addListener(_syncFromRuntime);
      _syncFromRuntime();
    }
    // Trigger popovers watch the caret through the shared controller.
    final AuiTriggerController? triggers = AuiTriggerScope.maybeOf(context);
    if (!identical(_triggers, triggers)) {
      _triggers?.detachText(_controller);
      _triggers = triggers;
      triggers?.attachText(_controller);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_mirrorToRuntime);
    _runtime?.removeListener(_syncFromRuntime);
    _triggers?.detachText(_controller);
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  /// Pushes field edits to the runtime, whatever caused them.
  void _mirrorToRuntime() {
    final AssistantRuntime? runtime = _runtime;
    if (runtime == null) return;
    if (runtime.state.composer.text == _controller.text) return;
    runtime.composer.setText(_controller.text);
  }

  /// Pulls text the runtime set (edit mode, programmatic sends) into the field.
  void _syncFromRuntime() {
    final String text = _runtime?.state.composer.text ?? '';
    if (text == _controller.text) return;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _submit() {
    final AssistantRuntime? runtime = _runtime;
    if (runtime == null) return;
    final ComposerState composer = runtime.state.composer;
    if (!composer.canSend) {
      if (composer.isEditing) runtime.composer.cancel();
      return;
    }
    widget.onSubmitted?.call(composer.text);
    runtime.composer.send();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    // An open trigger popover owns navigation and submission first.
    if (_triggers?.handleKeyEvent(event) ?? false) {
      return KeyEventResult.handled;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;

    if (widget.cancelOnEscape && key == LogicalKeyboardKey.escape) {
      _runtime?.composer.cancel();
      return KeyEventResult.handled;
    }

    final bool isEnter = key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter;
    if (!isEnter) return KeyEventResult.ignored;

    switch (widget.submitMode) {
      case AuiSubmitMode.none:
        return KeyEventResult.ignored;
      case AuiSubmitMode.enter:
        if (keyboard.isShiftPressed) return KeyEventResult.ignored;
        _submit();
        return KeyEventResult.handled;
      case AuiSubmitMode.ctrlEnter:
        if (keyboard.isControlPressed || keyboard.isMetaPressed) {
          _submit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    final InputDecoration decoration = widget.decoration ??
        InputDecoration(
          hintText: widget.placeholder,
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        );
    final Widget field = Material(
      type: MaterialType.transparency,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        style: widget.style,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        keyboardType: widget.keyboardType,
        textAlignVertical: widget.textAlignVertical,
        decoration: decoration,
      ),
    );

    final AuiTriggerController? triggers = _triggers;
    if (triggers == null) return field;
    return KeyedSubtree(key: triggers.anchorKey, child: field);
  }
}

/// Submits the composer: sends a new message, or saves an edit.
class AuiComposerSend extends StatelessWidget {
  const AuiComposerSend({
    super.key,
    this.child,
    this.builder,
    this.onPressed,
  }) : assert(child != null || builder != null, 'Provide a child or a builder');

  final Widget? child;

  /// Full control over the enabled and running states.
  final Widget Function(BuildContext context, bool enabled)? builder;

  /// Runs before the composer submits; return false to veto the send.
  final Future<bool> Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    return AuiStateBuilder<bool>(
      selector: (AuiState state) =>
          state.composer.canSend && !state.thread.isRunning,
      builder: (BuildContext context, bool enabled) {
        // The tap is always accepted and re-checks state, so a tap that lands
        // before the rebuild that would enable the button is not dropped.
        if (builder != null) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _handleTap(runtime),
            child: builder!(context, enabled),
          );
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleTap(runtime),
          child: IgnorePointer(
            ignoring: !enabled,
            child: Opacity(opacity: enabled ? 1 : 0.4, child: child),
          ),
        );
      },
    );
  }

  Future<void> _handleTap(AssistantRuntime runtime) async {
    if (!runtime.state.composer.canSend || runtime.state.thread.isRunning) {
      return;
    }
    final Future<bool> Function()? guard = onPressed;
    if (guard != null && !await guard()) return;
    await runtime.composer.send();
  }
}

/// Leaves edit mode, or clears the composer.
class AuiComposerCancel extends StatelessWidget {
  const AuiComposerCancel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: runtime.composer.cancel,
      child: child,
    );
  }
}

/// Renders each pending attachment of the composer.
class AuiComposerAttachments extends StatelessWidget {
  const AuiComposerAttachments({super.key, required this.builder});

  final Widget Function(
    BuildContext context,
    AuiAttachment attachment,
    int index,
  ) builder;

  @override
  Widget build(BuildContext context) {
    return AuiStateBuilder<List<AuiAttachment>>(
      selector: (AuiState state) => state.composer.attachments,
      builder: (BuildContext context, List<AuiAttachment> attachments) =>
          Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int i = 0; i < attachments.length; i++)
            builder(context, attachments[i], i),
        ],
      ),
    );
  }
}

/// Adds attachments the host picks.
///
/// File picking is platform work; the host supplies [onPick] and returns the
/// files it obtained. The runtime uploads them through its attachment adapter,
/// or inlines them when there is none.
class AuiComposerAddAttachment extends StatelessWidget {
  const AuiComposerAddAttachment({
    super.key,
    required this.child,
    required this.onPick,
  });

  final Widget child;
  final Future<List<PendingAttachment>> Function(BuildContext context) onPick;

  @override
  Widget build(BuildContext context) {
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final List<PendingAttachment> files = await onPick(context);
        for (final PendingAttachment file in files) {
          await runtime.composer.addPendingAttachment(file);
        }
      },
      child: child,
    );
  }
}
