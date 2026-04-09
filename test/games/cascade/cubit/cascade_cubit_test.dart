import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/cascade/cubit/cascade_cubit.dart';
import 'package:very_good_games/games/cascade/models/models.dart';

class _MockGameStorageRepository extends Mock
    implements GameStorageRepository {}

/// Waits for the cubit to finish loading.
Future<void> _waitForReady(CascadeCubit cubit) async {
  if (cubit.state.status != CascadeStatus.loading) return;
  await cubit.stream.firstWhere(
    (s) => s.status != CascadeStatus.loading,
  );
}

void main() {
  late _MockGameStorageRepository storageRepository;

  setUp(() {
    storageRepository = _MockGameStorageRepository();
    when(() => storageRepository.getSession(any())).thenReturn(null);
    when(
      () => storageRepository.saveSession(any(), any()),
    ).thenAnswer((_) async {});
  });

  group('CascadeCubit', () {
    test('initial state is loading', () async {
      final cubit = CascadeCubit(
        dailySeed: 42,
        dateKey: '2026-04-08',
        storageRepository: storageRepository,
      );

      expect(cubit.state.status, CascadeStatus.loading);
      await cubit.close();
    });

    test('transitions to configuring after initialization', () async {
      final cubit = CascadeCubit(
        dailySeed: 42,
        dateKey: '2026-04-08',
        storageRepository: storageRepository,
      );
      await _waitForReady(cubit);

      expect(cubit.state.status, CascadeStatus.configuring);
      expect(cubit.state.board.levers, isNotEmpty);
      expect(
        cubit.state.slotAssignments,
        [BallId.ball1, BallId.ball2, BallId.ball3],
      );
      expect(cubit.state.attempts, 0);
      await cubit.close();
    });

    test('assignBall swaps balls between slots', () async {
      final cubit = CascadeCubit(
        dailySeed: 42,
        dateKey: '2026-04-08',
        storageRepository: storageRepository,
      );
      await _waitForReady(cubit);

      // Default: [ball1, ball2, ball3]. Move ball1 to slot 2.
      cubit.assignBall(BallId.ball1, 2);

      // ball3 was in slot 2, so it swaps to slot 0.
      expect(cubit.state.slotAssignments[0], BallId.ball3);
      expect(cubit.state.slotAssignments[1], BallId.ball2);
      expect(cubit.state.slotAssignments[2], BallId.ball1);
      await cubit.close();
    });

    test('unassignBall removes ball from slot', () async {
      final cubit = CascadeCubit(
        dailySeed: 42,
        dateKey: '2026-04-08',
        storageRepository: storageRepository,
      );
      await _waitForReady(cubit);

      cubit.unassignBall(0);

      expect(cubit.state.slotAssignments[0], isNull);
      expect(cubit.state.slotAssignments[1], BallId.ball2);
      await cubit.close();
    });

    test('swapSlots swaps two ball assignments', () async {
      final cubit = CascadeCubit(
        dailySeed: 42,
        dateKey: '2026-04-08',
        storageRepository: storageRepository,
      );
      await _waitForReady(cubit);

      // Default: [ball1, ball2, ball3]. Swap 0 and 1.
      cubit.swapSlots(0, 1);

      expect(cubit.state.slotAssignments[0], BallId.ball2);
      expect(cubit.state.slotAssignments[1], BallId.ball1);
      await cubit.close();
    });

    test('flipLever toggles lever direction', () async {
      final cubit = CascadeCubit(
        dailySeed: 42,
        dateKey: '2026-04-08',
        storageRepository: storageRepository,
      );
      await _waitForReady(cubit);

      final originalDir = cubit.state.board.levers[0].direction;
      cubit.flipLever(0);

      expect(
        cubit.state.board.levers[0].direction,
        originalDir.opposite,
      );
      await cubit.close();
    });

    test('drop requires all balls assigned', () async {
      final cubit = CascadeCubit(
        dailySeed: 42,
        dateKey: '2026-04-08',
        storageRepository: storageRepository,
      );
      await _waitForReady(cubit);

      // Unassign one ball, then try to drop.
      cubit
        ..unassignBall(2)
        ..drop();

      // Still configuring because ball3 is not assigned.
      expect(cubit.state.status, CascadeStatus.configuring);
      await cubit.close();
    });

    test('drop transitions to dropping and increments attempts',
        () async {
      final cubit = CascadeCubit(
        dailySeed: 42,
        dateKey: '2026-04-08',
        storageRepository: storageRepository,
      );
      await _waitForReady(cubit);

      // Balls start assigned, can drop immediately.
      cubit.drop();

      expect(cubit.state.status, CascadeStatus.dropping);
      expect(cubit.state.attempts, 1);
      expect(cubit.state.dropResult, isNotNull);
      await cubit.close();
    });

    test('completeDrop transitions to won or failed', () async {
      final cubit = CascadeCubit(
        dailySeed: 42,
        dateKey: '2026-04-08',
        storageRepository: storageRepository,
      );
      await _waitForReady(cubit);

      cubit
        ..drop()
        ..completeDrop();

      expect(
        cubit.state.status,
        anyOf(CascadeStatus.won, CascadeStatus.failed),
      );
      await cubit.close();
    });

    test('reset restores pre-drop state', () async {
      final cubit = CascadeCubit(
        dailySeed: 42,
        dateKey: '2026-04-08',
        storageRepository: storageRepository,
      );
      await _waitForReady(cubit);

      // Flip a lever and rearrange balls before dropping.
      final lever0Before = cubit.state.board.levers[0].direction;
      cubit
        ..flipLever(0)
        ..assignBall(BallId.ball3, 0);

      // Snapshot what the state looks like right before drop.
      final preDropLevers = cubit.state.board.levers.toList();
      final preDropSlots =
          List<BallId?>.of(cubit.state.slotAssignments);

      cubit
        ..drop()
        ..completeDrop();

      if (cubit.state.status == CascadeStatus.failed) {
        cubit.reset();
        expect(cubit.state.status, CascadeStatus.configuring);

        // Slot assignments restored to pre-drop.
        expect(cubit.state.slotAssignments, preDropSlots);

        // Levers restored to pre-drop (with the flip applied).
        expect(
          cubit.state.board.levers[0].direction,
          lever0Before.opposite,
        );
        for (var i = 0; i < preDropLevers.length; i++) {
          expect(
            cubit.state.board.levers[i].direction,
            preDropLevers[i].direction,
          );
        }

        // Attempts preserved.
        expect(cubit.state.attempts, 1);
      }
      await cubit.close();
    });

    test('actions ignored when not in correct status', () async {
      final cubit = CascadeCubit(
        dailySeed: 42,
        dateKey: '2026-04-08',
        storageRepository: storageRepository,
      );
      await _waitForReady(cubit);

      cubit
        ..drop()
        // During dropping, assignment should be ignored.
        ..assignBall(BallId.ball1, 2);
      expect(cubit.state.status, CascadeStatus.dropping);

      // Lever flip during dropping should be ignored.
      final leverDir = cubit.state.board.levers[0].direction;
      cubit.flipLever(0);
      expect(cubit.state.board.levers[0].direction, leverDir);

      await cubit.close();
    });

    test('persists session on assignment', () async {
      final cubit = CascadeCubit(
        dailySeed: 42,
        dateKey: '2026-04-08',
        storageRepository: storageRepository,
      );
      await _waitForReady(cubit);

      cubit.assignBall(BallId.ball1, 2);

      // Allow async persist to complete.
      await Future<void>.delayed(Duration.zero);

      verify(
        () => storageRepository.saveSession(
          any(that: contains('cascade_state_')),
          any(that: isNotNull),
        ),
      ).called(greaterThan(0));

      await cubit.close();
    });
  });
}
