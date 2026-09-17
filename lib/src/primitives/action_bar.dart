import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/adapters.dart';
import '../core/message.dart';
import '../core/runtime_api.dart';
import 'message.dart';
import 'runtime_provider.dart';
import 'state.dart';

/// When an action bar hides itself.
enum AuiActionBarAutohide {
  /// Always visible.
  never,

  /// Visible on the last message, hidden elsewhere until hovered.
  notLast,

  /// Always hidden until hovered.
  always,
}

/// Container for message actions.
///
/// Must sit inside an `AuiMessage`: it reads message state, hover, and the
/// thread's run state from the enclosing scopes.
class AuiActionBar extends StatelessWidget {
  const AuiActionBar({
    super.key,
    required this.child,
    this.hideWhenRunning = false,
    this.autohide = AuiActionBarAutohide.never,
    this.floatWhenHidden = false,
  });

  final Widget child;
  final bool hideWhenRunning;
  final AuiActionBarAutohide autohide;

  /// Keeps the layout space when hidden and fades the bar out, so hovering
  /// does not shift the message.
  final bool floatWhenHidden;

  @override
  Widget build(BuildContext context) {
    final ValueNotifier<bool>? hovered = AuiMessageHoverScope.maybeOf(context);

    return AuiStateBuilder<bool>(
      selector: (AuiState state) {
        if (hideWhenRunning && state.thread.isRunning) return false;
        final MessageState? message = state.message;
        return switch (autohide) {
          AuiActionBarAutohide.never => true,
          AuiActionBarAutohide.notLast => message?.isLast ?? true,
          AuiActionBarAutohide.always => false,
        };
      },
      builder: (BuildContext context, bool visibleWhenIdle) {
        Widget wrap(bool visible) {
          if (!visible) {
            return floatWhenHidden
                ? IgnorePointer(child: Opacity(opacity: 0, child: child))
                : const SizedBox.shrink();
          }
          return child;
        }

        if (hovered == null) return wrap(visibleWhenIdle);
        return ValueListenableBuilder<bool>(
          valueListenable: hovered,
          builder: (BuildContext context, bool isHovered, Widget? _) =>
              wrap(visibleWhenIdle || isHovered),
        );
      },
    );
  }
}

/// Copies the message text, flipping to a "copied" state for a moment.
class AuiActionBarCopy extends StatefulWidget {
  const AuiActionBarCopy({
    super.key,
    this.child,
    this.copiedChild,
    this.copiedDuration = const Duration(seconds: 3),
    this.builder,
  }) : assert(
          child != null || builder != null,
          'Provide a child or a builder',
        );

  final Widget? child;

  /// Shown instead of [child] while the copied state lasts.
  final Widget? copiedChild;

  final Duration copiedDuration;

  /// Full control over the enabled and copied states.
  final Widget Function(BuildContext context, bool enabled, bool copied)? builder;

  @override
  State<AuiActionBarCopy> createState() => _AuiActionBarCopyState();
}

class _AuiActionBarCopyState extends State<AuiActionBarCopy> {
  Timer? _resetTimer;
  bool _copied = false;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy(ThreadMessage message) async {
    await Clipboard.setData(ClipboardData(text: message.text));
    if (!mounted) return;
    setState(() => _copied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(widget.copiedDuration, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuiStateBuilder<({ThreadMessage message, bool enabled})?>(
      selector: (AuiState state) {
        final MessageState? message = state.message;
        if (message == null) return null;
        final bool enabled = message.message.text.trim().isNotEmpty &&
            !message.message.isRunning;
        return (message: message.message, enabled: enabled);
      },
      builder: (
        BuildContext context,
        ({ThreadMessage message, bool enabled})? value,
      ) {
        if (value == null) return const SizedBox.shrink();
        if (widget.builder != null) {
          return _Tappable(
            enabled: value.enabled,
            onTap: () => _copy(value.message),
            child: widget.builder!(context, value.enabled, _copied),
          );
        }
        return _Tappable(
          enabled: value.enabled,
          onTap: () => _copy(value.message),
          child: _copied && widget.copiedChild != null
              ? widget.copiedChild!
              : IgnorePointer(
                  ignoring: !value.enabled,
                  child: Opacity(
                    opacity: value.enabled ? 1 : 0.4,
                    child: widget.child,
                  ),
                ),
        );
      },
    );
  }
}

/// Regenerates the message as a new branch.
class AuiActionBarReload extends StatelessWidget {
  const AuiActionBarReload({
    super.key,
    this.child,
    this.builder,
  }) : assert(
          child != null || builder != null,
          'Provide a child or a builder',
        );

  final Widget? child;
  final Widget Function(BuildContext context, bool enabled)? builder;

  @override
  Widget build(BuildContext context) {
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    return AuiStateBuilder<({String id, bool enabled})?>(
      selector: (AuiState state) {
        final MessageState? message = state.message;
        if (message == null) return null;
        return (
          id: message.message.id,
          enabled: !state.thread.isRunning &&
              message.message.role == MessageRole.assistant &&
              state.thread.capabilities.reload,
        );
      },
      builder: (BuildContext context, ({String id, bool enabled})? value) {
        if (value == null) return const SizedBox.shrink();
        return _Tappable(
          enabled: value.enabled,
          onTap: () => runtime.thread.reload(messageId: value.id),
          child: builder?.call(context, value.enabled) ??
              IgnorePointer(
                ignoring: !value.enabled,
                child: Opacity(
                  opacity: value.enabled ? 1 : 0.4,
                  child: child,
                ),
              ),
        );
      },
    );
  }
}

/// Opens the message in the composer for editing.
class AuiActionBarEdit extends StatelessWidget {
  const AuiActionBarEdit({
    super.key,
    this.child,
    this.builder,
  }) : assert(
          child != null || builder != null,
          'Provide a child or a builder',
        );

  final Widget? child;
  final Widget Function(BuildContext context, bool enabled)? builder;

  @override
  Widget build(BuildContext context) {
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    return AuiStateBuilder<({String id, bool enabled})?>(
      selector: (AuiState state) {
        final MessageState? message = state.message;
        if (message == null) return null;
        return (
          id: message.message.id,
          enabled: !message.message.isEditing &&
              state.thread.capabilities.edit,
        );
      },
      builder: (BuildContext context, ({String id, bool enabled})? value) {
        if (value == null) return const SizedBox.shrink();
        return _Tappable(
          enabled: value.enabled,
          onTap: () => runtime.thread.beginEdit(value.id),
          child: builder?.call(context, value.enabled) ??
              IgnorePointer(
                ignoring: !value.enabled,
                child: Opacity(
                  opacity: value.enabled ? 1 : 0.4,
                  child: child,
                ),
              ),
        );
      },
    );
  }
}

/// Reads the message aloud, toggling into a stop state while it plays.
///
/// Disabled without a [SpeechSynthesisAdapter] — upstream gates speech on the
/// adapter being configured.
class AuiActionBarSpeak extends StatelessWidget {
  const AuiActionBarSpeak({
    super.key,
    this.child,
    this.stopChild,
    this.builder,
  }) : assert(child != null || builder != null, 'Provide a child or a builder');

  final Widget? child;

  /// Shown while the message is being read.
  final Widget? stopChild;

  /// Full control over the enabled and speaking states.
  final Widget Function(BuildContext context, bool enabled, bool speaking)?
      builder;

  @override
  Widget build(BuildContext context) {
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    return AuiStateBuilder<({String id, bool enabled, bool speaking})?>(
      selector: (AuiState state) {
        final MessageState? message = state.message;
        if (message == null) return null;
        return (
          id: message.message.id,
          enabled: state.thread.capabilities.speech &&
              message.message.text.trim().isNotEmpty,
          speaking: message.isSpeaking,
        );
      },
      builder: (
        BuildContext context,
        ({String id, bool enabled, bool speaking})? value,
      ) {
        if (value == null) return const SizedBox.shrink();
        return _Tappable(
          enabled: value.enabled,
          onTap: () => value.speaking
              ? runtime.thread.stopSpeaking()
              : runtime.thread.speak(value.id),
          child: builder?.call(context, value.enabled, value.speaking) ??
              IgnorePointer(
                ignoring: !value.enabled,
                child: Opacity(
                  opacity: value.enabled ? 1 : 0.4,
                  child: value.speaking ? (stopChild ?? child) : child,
                ),
              ),
        );
      },
    );
  }
}

/// Rates the message. The button reports its own submitted state and calls the
/// runtime's feedback adapter.
class AuiActionBarFeedback extends StatefulWidget {
  const AuiActionBarFeedback({
    super.key,
    required this.type,
    this.child,
    this.submittedChild,
    this.builder,
  }) : assert(child != null || builder != null, 'Provide a child or a builder');

  final FeedbackType type;
  final Widget? child;

  /// Shown after a successful submission.
  final Widget? submittedChild;

  /// Full control over the enabled and submitted states.
  final Widget Function(BuildContext context, bool enabled, bool submitted)?
      builder;

  @override
  State<AuiActionBarFeedback> createState() => _AuiActionBarFeedbackState();
}

class _AuiActionBarFeedbackState extends State<AuiActionBarFeedback> {
  bool _submitted = false;

  @override
  Widget build(BuildContext context) {
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    return AuiStateBuilder<({String id, bool enabled})?>(
      selector: (AuiState state) {
        final MessageState? message = state.message;
        if (message == null) return null;
        return (
          id: message.message.id,
          enabled: state.thread.capabilities.feedback,
        );
      },
      builder: (BuildContext context, ({String id, bool enabled})? value) {
        if (value == null) return const SizedBox.shrink();
        return _Tappable(
          enabled: value.enabled,
          onTap: () async {
            await runtime.thread.submitFeedback(
              messageId: value.id,
              type: widget.type,
            );
            if (mounted) setState(() => _submitted = true);
          },
          child: widget.builder?.call(context, value.enabled, _submitted) ??
              IgnorePointer(
                ignoring: !value.enabled,
                child: Opacity(
                  opacity: value.enabled ? 1 : 0.4,
                  child: _submitted && widget.submittedChild != null
                      ? widget.submittedChild
                      : widget.child,
                ),
              ),
        );
      },
    );
  }
}

class _Tappable extends StatelessWidget {
  const _Tappable({
    required this.enabled,
    required this.onTap,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: child,
      );
}
