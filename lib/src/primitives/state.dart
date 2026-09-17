import 'package:flutter/widgets.dart';

import '../core/message.dart';
import '../core/runtime_api.dart';
import 'runtime_provider.dart';

/// Builds a widget from a slice of runtime state, rebuilding only when that
/// slice changes — the Flutter equivalent of `useAuiState(selector)`.
///
/// ```dart
/// AuiStateBuilder<bool>(
///   selector: (state) => state.thread.isRunning,
///   builder: (context, isRunning) => Text(isRunning ? 'Thinking…' : 'Ready'),
/// );
/// ```
class AuiStateBuilder<T> extends StatefulWidget {
  const AuiStateBuilder({
    super.key,
    required this.selector,
    required this.builder,
  });

  final T Function(AuiState state) selector;
  final Widget Function(BuildContext context, T value) builder;

  @override
  State<AuiStateBuilder<T>> createState() => _AuiStateBuilderState<T>();
}

class _AuiStateBuilderState<T> extends State<AuiStateBuilder<T>> {
  T? _value;
  bool _hasValue = false;

  @override
  Widget build(BuildContext context) {
    final AssistantRuntime runtime = AuiRuntimeProvider.of(context);
    // Message scope changes come from the widget tree, not the runtime.
    final MessageState? message =
        AuiMessageScope.maybeOf(context)?.state;
    final T selected = widget.selector(
      runtime.state.withMessage(message),
    );
    if (!_hasValue || selected != _value) {
      _value = selected;
      _hasValue = true;
    }
    return AnimatedBuilder(
      animation: runtime,
      builder: (BuildContext context, Widget? _) {
        final T next = widget.selector(
          runtime.state.withMessage(AuiMessageScope.maybeOf(context)?.state),
        );
        if (!_hasValue || next != _value) {
          _value = next;
          _hasValue = true;
        }
        return widget.builder(context, _value as T);
      },
    );
  }
}

/// Renders [child] only while [condition] holds.
///
/// The selector receives the same state shape as assistant-ui's `AuiIf`:
/// `state.thread`, `state.composer`, and `state.message` inside a message.
class AuiIf extends StatelessWidget {
  const AuiIf({
    super.key,
    required this.condition,
    required this.child,
    this.fallback,
  });

  final bool Function(AuiState state) condition;
  final Widget child;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return AuiStateBuilder<bool>(
      selector: condition,
      builder: (BuildContext context, bool value) =>
          value ? child : (fallback ?? const SizedBox.shrink()),
    );
  }
}

/// Message-scoped state, available to [AuiIf] and [AuiStateBuilder] inside an
/// `AuiMessage`.
class AuiMessageScope extends InheritedWidget {
  const AuiMessageScope({
    super.key,
    required this.state,
    required super.child,
  });

  final MessageState state;

  static AuiMessageScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuiMessageScope>();

  @override
  bool updateShouldNotify(AuiMessageScope oldWidget) =>
      state.message != oldWidget.state.message || state.isLast != oldWidget.state.isLast;
}

/// The message a thread iterator is currently building.
///
/// `AuiMessage` reads it when no explicit message is passed, mirroring how
/// `MessagePrimitive.Root` picks up the message from its iterator.
class AuiCurrentMessage extends InheritedWidget {
  const AuiCurrentMessage({
    super.key,
    required this.message,
    required this.isLast,
    required super.child,
  });

  final ThreadMessage message;
  final bool isLast;

  static AuiCurrentMessage? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuiCurrentMessage>();

  @override
  bool updateShouldNotify(AuiCurrentMessage oldWidget) =>
      message != oldWidget.message || isLast != oldWidget.isLast;
}

/// Convenience for reading runtime operations, mirroring `useAui()`.
///
/// ```dart
/// AuiApi.of(context).thread.cancelRun();
/// ```
abstract final class AuiApi {
  static AssistantRuntime of(BuildContext context) =>
      AuiRuntimeProvider.of(context);
}
