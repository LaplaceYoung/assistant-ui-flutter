import 'package:flutter/material.dart';

import '../core/runtime_api.dart';
import 'runtime_provider.dart';
import 'state.dart';

/// Navigates between the alternative answers of a message.
///
/// Regenerating a message or editing a user message adds a branch instead of
/// discarding the previous answer, so the picker is how a reader flips back.
class AuiBranchPicker extends StatelessWidget {
  const AuiBranchPicker({
    super.key,
    required this.child,
    this.spacing = 2,
    this.alignment = MainAxisAlignment.start,
  });

  final Widget child;
  final double spacing;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: alignment,
        children: <Widget>[child],
      );
}

/// Switches to the previous branch.
class AuiBranchPickerPrevious extends StatelessWidget {
  const AuiBranchPickerPrevious({
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
    return AuiStateBuilder<({String id, int index, bool enabled})?>(
      selector: (AuiState state) {
        final MessageState? message = state.message;
        if (message == null) return null;
        return (
          id: message.message.id,
          index: message.branchIndex,
          enabled: message.branchIndex > 0 && state.thread.capabilities.branching,
        );
      },
      builder: (
        BuildContext context,
        ({String id, int index, bool enabled})? value,
      ) {
        if (value == null) return const SizedBox.shrink();
        return _BranchButton(
          enabled: value.enabled,
          onTap: () =>
              runtime.thread.switchToBranch(value.id, value.index - 1),
          fallbackOpacity: 0.3,
          builder: builder,
          child: child,
        );
      },
    );
  }
}

/// Switches to the next branch.
class AuiBranchPickerNext extends StatelessWidget {
  const AuiBranchPickerNext({
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
    return AuiStateBuilder<({String id, int index, int count, bool enabled})?>(
      selector: (AuiState state) {
        final MessageState? message = state.message;
        if (message == null) return null;
        return (
          id: message.message.id,
          index: message.branchIndex,
          count: message.branchCount,
          enabled: message.branchIndex < message.branchCount - 1 &&
              state.thread.capabilities.branching,
        );
      },
      builder: (
        BuildContext context,
        ({String id, int index, int count, bool enabled})? value,
      ) {
        if (value == null) return const SizedBox.shrink();
        return _BranchButton(
          enabled: value.enabled,
          onTap: () =>
              runtime.thread.switchToBranch(value.id, value.index + 1),
          fallbackOpacity: 0.3,
          builder: builder,
          child: child,
        );
      },
    );
  }
}

/// The current position, `2/3`, rendered only when more than one branch
/// exists.
class AuiBranchPickerNumber extends StatelessWidget {
  const AuiBranchPickerNumber({super.key, this.builder});

  final Widget Function(BuildContext context, int index, int count)? builder;

  @override
  Widget build(BuildContext context) {
    return AuiStateBuilder<({int index, int count})?>(
      selector: (AuiState state) {
        final MessageState? message = state.message;
        if (message == null) return null;
        return (index: message.branchIndex, count: message.branchCount);
      },
      builder: (BuildContext context, ({int index, int count})? value) {
        if (value == null || value.count <= 1) return const SizedBox.shrink();
        if (builder != null) {
          return builder!(context, value.index, value.count);
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Align(
            alignment: Alignment.center,
            child: Text(
              '${value.index + 1}/${value.count}',
              style: DefaultTextStyle.of(context).style.copyWith(
                    fontSize: 12,
                    fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
                  ),
            ),
          ),
        );
      },
    );
  }
}

class _BranchButton extends StatelessWidget {
  const _BranchButton({
    required this.enabled,
    required this.onTap,
    required this.fallbackOpacity,
    required this.builder,
    required this.child,
  });

  final bool enabled;
  final VoidCallback onTap;
  final double fallbackOpacity;
  final Widget Function(BuildContext context, bool enabled)? builder;
  final Widget? child;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: builder?.call(context, enabled) ??
            IgnorePointer(
              ignoring: !enabled,
              child: Opacity(
                opacity: enabled ? 1 : fallbackOpacity,
                child: child,
              ),
            ),
      );
}
