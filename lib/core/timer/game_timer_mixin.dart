import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

/// A mixin on [Cubit] that encapsulates elapsed-time timer logic.
///
/// The timer ticks every second and calls [onTimerTick] with the
/// current elapsed seconds. Each game cubit implements [onTimerTick]
/// to emit its own state with the updated value.
///
/// Usage:
/// ```dart
/// class MyCubit extends Cubit<MyState> with GameTimerMixin {
///   @override
///   void onTimerTick(int elapsedSeconds) {
///     emit(state.copyWith(elapsedSeconds: elapsedSeconds));
///   }
/// }
/// ```
mixin GameTimerMixin<T> on Cubit<T> {
  Timer? _gameTimer;
  int _elapsedSeconds = 0;
  bool _timerStarted = false;

  /// The number of seconds elapsed since the timer started.
  int get elapsedSeconds => _elapsedSeconds;

  /// Whether the timer has been started (first interaction occurred).
  bool get timerStarted => _timerStarted;

  /// Initializes the timer with previously saved state.
  ///
  /// Call this when restoring a session to resume from where the
  /// player left off.
  void initTimer({int initialSeconds = 0, bool alreadyStarted = false}) {
    _elapsedSeconds = initialSeconds;
    _timerStarted = alreadyStarted;
    if (alreadyStarted) {
      _startPeriodicTimer();
    }
  }

  /// Starts the timer. Idempotent — calling twice does not double-tick.
  ///
  /// Called on first player interaction.
  void startTimer() {
    if (_timerStarted) return;
    _timerStarted = true;
    _startPeriodicTimer();
  }

  /// Pauses the timer (e.g. when app is backgrounded).
  ///
  /// No-op if timer is not running or already paused.
  void pauseTimer() {
    if (!_timerStarted || _gameTimer == null) return;
    _gameTimer?.cancel();
    _gameTimer = null;
  }

  /// Resumes the timer after a pause.
  ///
  /// No-op if timer was not paused.
  void resumeTimer() {
    if (!_timerStarted || _gameTimer != null) return;
    _startPeriodicTimer();
  }

  /// Resets the timer to zero and stops it.
  void resetTimer() {
    _gameTimer?.cancel();
    _gameTimer = null;
    _elapsedSeconds = 0;
    _timerStarted = false;
  }

  /// Disposes the internal timer. Safe to call multiple times.
  ///
  /// Must be called in the cubit's `close()` override.
  void disposeTimer() {
    _gameTimer?.cancel();
    _gameTimer = null;
  }

  /// Called on each tick with the current elapsed seconds.
  ///
  /// Implementations should emit their state with the updated value.
  void onTimerTick(int elapsedSeconds);

  void _startPeriodicTimer() {
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isClosed) return;
      _elapsedSeconds++;
      onTimerTick(_elapsedSeconds);
    });
  }
}

/// Formats elapsed seconds as `M:SS` (or `H:MM:SS` for times >= 60 minutes).
String formatElapsedTime(int totalSeconds) {
  if (totalSeconds >= 3600) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '$hours:${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
