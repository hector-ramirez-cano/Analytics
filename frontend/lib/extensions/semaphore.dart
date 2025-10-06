import 'dart:async';

class Semaphore {
  Completer<void> _completer = Completer();

  /// Returns the current future that listeners can await.
  Future<void> get future {
    return _completer.future;
  }

  /// Signals the semaphore, completing the current future.
  void signal() {

    // complete once, any subsequent calls are just ignored
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  /// Resets the semaphore, if it's not completed, this call is ignored.
  void reset() {
    // if it's complete, reset. Otherwise, ignore
    if (_completer.isCompleted) {
      _completer = Completer<void>();
    }
  }

  /// Whether the semaphore has been signaled.
  bool get isComplete => _completer.isCompleted;
}
