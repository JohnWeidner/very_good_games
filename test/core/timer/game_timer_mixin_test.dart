import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:very_good_games/core/timer/game_timer_mixin.dart';

/// A minimal cubit that uses [GameTimerMixin] for testing.
class _TestCubit extends Cubit<int> with GameTimerMixin<int> {
  _TestCubit() : super(0);

  @override
  void onTimerTick(int elapsedSeconds) {
    emit(elapsedSeconds);
  }

  @override
  Future<void> close() {
    disposeTimer();
    return super.close();
  }
}

void main() {
  group('GameTimerMixin', () {
    late _TestCubit cubit;

    setUp(() {
      cubit = _TestCubit();
    });

    tearDown(() => cubit.close());

    test('initial state has timer not started', () {
      expect(cubit.timerStarted, isFalse);
      expect(cubit.elapsedSeconds, 0);
    });

    test('startTimer sets timerStarted to true', () {
      cubit.startTimer();
      expect(cubit.timerStarted, isTrue);
    });

    test('startTimer is idempotent', () {
      cubit
        ..startTimer()
        ..startTimer();
      expect(cubit.timerStarted, isTrue);
    });

    test('timer ticks every second', () async {
      cubit.startTimer();
      await Future<void>.delayed(const Duration(milliseconds: 2500));
      // Should have ticked at least twice in 2.5 seconds.
      expect(cubit.elapsedSeconds, greaterThanOrEqualTo(2));
      expect(cubit.state, cubit.elapsedSeconds);
    });

    test('pauseTimer stops ticking', () async {
      cubit.startTimer();
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      cubit.pauseTimer();
      final pausedAt = cubit.elapsedSeconds;
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(cubit.elapsedSeconds, pausedAt);
    });

    test('resumeTimer continues from paused value', () async {
      cubit.startTimer();
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      cubit.pauseTimer();
      final pausedAt = cubit.elapsedSeconds;
      cubit.resumeTimer();
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(cubit.elapsedSeconds, greaterThan(pausedAt));
    });

    test('pauseTimer is no-op when timer not started', () {
      cubit.pauseTimer();
      expect(cubit.timerStarted, isFalse);
      expect(cubit.elapsedSeconds, 0);
    });

    test('pauseTimer is no-op when already paused', () async {
      cubit.startTimer();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      cubit.pauseTimer();
      final first = cubit.elapsedSeconds;
      cubit.pauseTimer(); // second pause — no-op
      expect(cubit.elapsedSeconds, first);
    });

    test('resumeTimer is no-op when not paused', () async {
      cubit.startTimer();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final before = cubit.elapsedSeconds;
      cubit.resumeTimer(); // not paused — no-op
      // Should still be ticking normally.
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(cubit.elapsedSeconds, greaterThan(before));
    });

    test('resumeTimer is no-op when timer not started', () {
      cubit.resumeTimer();
      expect(cubit.timerStarted, isFalse);
    });

    test('resetTimer stops and zeroes the timer', () async {
      cubit.startTimer();
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      cubit.resetTimer();
      expect(cubit.elapsedSeconds, 0);
      expect(cubit.timerStarted, isFalse);
      // Confirm no more ticks.
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(cubit.elapsedSeconds, 0);
    });

    test('disposeTimer is safe to call multiple times', () {
      cubit
        ..startTimer()
        ..disposeTimer()
        ..disposeTimer();
      expect(cubit.elapsedSeconds, 0);
    });

    test('initTimer restores saved state', () {
      cubit.initTimer(initialSeconds: 42, alreadyStarted: true);
      expect(cubit.elapsedSeconds, 42);
      expect(cubit.timerStarted, isTrue);
    });

    test(
      'initTimer with alreadyStarted false does not start ticking',
      () async {
        cubit.initTimer(initialSeconds: 10);
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        expect(cubit.elapsedSeconds, 10);
      },
    );

    test('initTimer with alreadyStarted true starts ticking', () async {
      cubit.initTimer(initialSeconds: 10, alreadyStarted: true);
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      expect(cubit.elapsedSeconds, greaterThan(10));
    });
  });

  group('formatElapsedTime', () {
    test('formats zero seconds', () {
      expect(formatElapsedTime(0), '0:00');
    });

    test('formats seconds only', () {
      expect(formatElapsedTime(5), '0:05');
      expect(formatElapsedTime(59), '0:59');
    });

    test('formats minutes and seconds', () {
      expect(formatElapsedTime(60), '1:00');
      expect(formatElapsedTime(125), '2:05');
      expect(formatElapsedTime(3599), '59:59');
    });

    test('formats hours for times >= 60 minutes', () {
      expect(formatElapsedTime(3600), '1:00:00');
      expect(formatElapsedTime(3661), '1:01:01');
      expect(formatElapsedTime(7200), '2:00:00');
    });
  });
}
