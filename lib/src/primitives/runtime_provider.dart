import 'package:flutter/widgets.dart';

import '../core/runtime_api.dart';

/// Makes an [AssistantRuntime] available to the primitives below it.
///
/// Wrap your chat UI in this once, the way `AssistantRuntimeProvider` wraps a
/// React tree:
///
/// ```dart
/// final runtime = LocalRuntime(adapter: MyAdapter());
///
/// AuiRuntimeProvider(
///   runtime: runtime,
///   child: const AuiThread(...),
/// );
/// ```
class AuiRuntimeProvider extends InheritedNotifier<AssistantRuntime> {
  const AuiRuntimeProvider({
    super.key,
    required AssistantRuntime runtime,
    required super.child,
  }) : super(notifier: runtime);

  static AssistantRuntime of(BuildContext context) {
    final AssistantRuntime? runtime = maybeOf(context);
    assert(runtime != null, 'No AuiRuntimeProvider found in this context.');
    return runtime!;
  }

  static AssistantRuntime? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AuiRuntimeProvider>()
      ?.notifier;

  @override
  bool updateShouldNotify(AuiRuntimeProvider oldWidget) =>
      notifier != oldWidget.notifier;
}
