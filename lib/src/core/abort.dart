import 'dart:async';

/// Thrown when an aborted operation is awaited or checked.
class AbortException implements Exception {
  const AbortException([this.message = 'Operation aborted']);

  final String message;

  @override
  String toString() => 'AbortException: $message';
}

/// A web-style abort signal handed to [ChatModelAdapter] runs.
///
/// Adapters should stop their work when the signal fires — usually by passing
/// it to the HTTP client or by checking [isAborted] between chunks.
class AbortSignal {
  AbortSignal._();

  bool _aborted = false;
  Object? _reason;
  final List<void Function()> _listeners = <void Function()>[];

  bool get isAborted => _aborted;

  /// The value passed to [AbortController.abort], if any.
  Object? get reason => _reason;

  void throwIfAborted() {
    if (_aborted) throw AbortException(_reason?.toString() ?? 'Operation aborted');
  }

  void addListener(void Function() listener) {
    if (_aborted) {
      listener();
      return;
    }
    _listeners.add(listener);
  }

  void removeListener(void Function() listener) => _listeners.remove(listener);

  /// Completes when the signal aborts (immediately if it already has).
  Future<void> get onAbort {
    if (_aborted) return Future<void>.value();
    final Completer<void> completer = Completer<void>();
    addListener(completer.complete);
    return completer.future;
  }

  void _abort(Object? reason) {
    if (_aborted) return;
    _aborted = true;
    _reason = reason;
    final List<void Function()> listeners = List<void Function()>.of(_listeners);
    _listeners.clear();
    for (final void Function() listener in listeners) {
      listener();
    }
  }
}

/// Creates an [AbortSignal] and lets the owner fire it.
class AbortController {
  AbortController();

  final AbortSignal signal = AbortSignal._();

  bool get isAborted => signal.isAborted;

  void abort([Object? reason]) => signal._abort(reason);
}
