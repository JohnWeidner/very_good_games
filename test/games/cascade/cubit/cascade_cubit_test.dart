import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/games/cascade/cubit/cascade_cubit.dart';
import 'package:very_good_games/games/cascade/logic/logic.dart';
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

/// Finds a slot assignment permutation that loses for seed 42.
/// Tries all 6 permutations and returns one that fails.
List<BallId>? _findLosingPermutation(CascadeBoard board) {
  final perms = <List<BallId>>[
    [BallId.ball1, BallId.ball2, BallId.ball3],
    [BallId.ball1, BallId.ball3, BallId.ball2],
    [BallId.ball2, BallId.ball1, BallId.ball3],
    [BallId.ball2, BallId.ball3, BallId.ball1],
    [BallId.ball3, BallId.ball1, BallId.ball2],
    [BallId.ball3, BallId.ball2, BallId.ball1],
  ];
  for (final perm in perms) {
    final result = BallSimulator.simulate(
      board: board,
      slotAssignments: perm,
    );
    if (!result.isWin) return perm;
  }
  return null;
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

      cubit.assignBall(BallId.ball1, 2);

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

      cubit
        ..unassignBall(2)
        ..drop();

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

      cubit.drop();

      expect(cubit.state.status, CascadeStatus.dropping);
      expect(cubit.state.attempts, 1);
      expect(cubit.state.dropResult, isNotNull);
      await cubit.close();
    });

    test('completeDrop transitions to failed on wrong assignment',
        () async {
      final cubit = CascadeCubit(
        dailySeed: 42,
        dateKey: '2026-04-08',
        storageRepository: storageRepository,
      );
      await _waitForReady(cubit);

      // Find a losing permutation for this board.
      final losingPerm = _findLosingPermutation(cubit.state.board);
      expect(losingPerm, isNotNull, reason: 'No losing perm found');

      // Apply the losing assignment.
      for (var i = 0; i < losingPerm!.length; i++) {
        cubit.assignBall(losingPerm[i], i);
      }

      cubit
        ..drop()
        ..completeDrop();

      expect(cubit.state.status, CascadeStatus.failed);
      expect(cubit.state.score, isNull);
      await cubit.close();
    });

    test('completeDrop sets score on win', () async {
      // Use BallSimulator to brute-force the winning configuration
      // (ball permutation + lever states) for seed 42.
      final generated = PuzzleGenerator.generate(42);
      final leverCount = generated.board.levers.length;
      final perms = <List<BallId>>[
        [BallId.ball1, BallId.ball2, BallId.ball3],
        [BallId.ball1, BallId.ball3, BallId.ball2],
        [BallId.ball2, BallId.ball1, BallId.ball3],
        [BallId.ball2, BallId.ball3, BallId.ball1],
        [BallId.ball3, BallId.ball1, BallId.ball2],
        [BallId.ball3, BallId.ball2, BallId.ball1],
      ];

      List<BallId>? winningPerm;
      List<int>? leverFlipIndices;

      for (final perm in perms) {
        for (var mask = 0; mask < (1 << leverCount); mask++) {
          final levers = <Lever>[
            for (var i = 0; i < leverCount; i++)
              (mask >> i) & 1 == 0
                  ? generated.board.levers[i]
                  : generated.board.levers[i].flip(),
          ];
          final board = CascadeBoard(
            levers: levers,
            binOrder: generated.board.binOrder,
          );
          final result =
              BallSimulator.simulate(board: board, slotAssignments: perm);
          if (result.isWin) {
            winningPerm = perm;
            // Identify which levers need to be flipped from initial.
            leverFlipIndices = [
              for (var i = 0; i < leverCount; i++)
                if ((mask >> i) & 1 == 1) i,
            ];
            break;
          }
        }
        if (winningPerm != null) break;
      }
      expect(winningPerm, isNotNull, reason: 'No winning config found');

      final cubit = CascadeCubit(
        dailySeed: 42,
        dateKey: '2026-04-08',
        storageRepository: storageRepository,
      );
      await _waitForReady(cubit);

      // Apply the winning lever flips.
      for (final i in leverFlipIndices!) {
        cubit.flipLever(i);
      }
      // Apply the winning ball assignment.
      for (var i = 0; i < winningPerm!.length; i++) {
        cubit.assignBall(winningPerm[i], i);
      }

      cubit
        ..drop()
        ..completeDrop();

      expect(cubit.state.status, CascadeStatus.won);
      expect(cubit.state.score, cascadeScore(1));
      await cubit.close();
    });

    test('reset restores pre-drop state', () async {
      final cubit = CascadeCubit(
        dailySeed: 42,
        dateKey: '2026-04-08',
        storageRepository: storageRepository,
      );
      await _waitForReady(cubit);

      // Find a losing permutation to guarantee failed state.
      final losingPerm = _findLosingPermutation(cubit.state.board);
      expect(losingPerm, isNotNull, reason: 'No losing perm found');

      // Flip a lever and apply losing assignment before dropping.
      final lever0Before = cubit.state.board.levers[0].direction;
      cubit.flipLever(0);

      for (var i = 0; i < losingPerm!.length; i++) {
        cubit.assignBall(losingPerm[i], i);
      }

      final preDropLevers = cubit.state.board.levers.toList();
      final preDropSlots =
          List<BallId?>.of(cubit.state.slotAssignments);

      cubit
        ..drop()
        ..completeDrop();

      // Guaranteed to be failed since we used a losing permutation.
      expect(cubit.state.status, CascadeStatus.failed);

      cubit.reset();
      expect(cubit.state.status, CascadeStatus.configuring);
      expect(cubit.state.slotAssignments, preDropSlots);
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
      expect(cubit.state.attempts, 1);
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
        ..assignBall(BallId.ball1, 2);
      expect(cubit.state.status, CascadeStatus.dropping);

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

      await Future<void>.delayed(Duration.zero);

      verify(
        () => storageRepository.saveSession(
          any(that: contains('cascade_state_')),
          any(that: isNotNull),
        ),
      ).called(greaterThan(0));

      await cubit.close();
    });

    test('restores session from storage', () async {
      // Generate the puzzle to know the expected board.
      final generated = PuzzleGenerator.generate(42);

      // Mock a saved session.
      when(
        () => storageRepository.getSession('cascade_state_2026-04-08'),
      ).thenReturn({
        'levers': generated.board.levers.map((l) => l.toJson()).toList(),
        'slotAssignments': ['ball3', 'ball1', 'ball2'],
        'attempts': 2,
        'status': 'configuring',
      });

      final cubit = CascadeCubit(
        dailySeed: 42,
        dateKey: '2026-04-08',
        storageRepository: storageRepository,
      );
      await _waitForReady(cubit);

      expect(cubit.state.status, CascadeStatus.configuring);
      expect(cubit.state.attempts, 2);
      expect(
        cubit.state.slotAssignments,
        [BallId.ball3, BallId.ball1, BallId.ball2],
      );
      await cubit.close();
    });

    test('dropping status in session restores as failed', () async {
      final generated = PuzzleGenerator.generate(42);

      when(
        () => storageRepository.getSession('cascade_state_2026-04-08'),
      ).thenReturn({
        'levers': generated.board.levers.map((l) => l.toJson()).toList(),
        'slotAssignments': ['ball1', 'ball2', 'ball3'],
        'attempts': 1,
        'status': 'dropping',
      });

      final cubit = CascadeCubit(
        dailySeed: 42,
        dateKey: '2026-04-08',
        storageRepository: storageRepository,
      );
      await _waitForReady(cubit);

      expect(cubit.state.status, CascadeStatus.failed);
      await cubit.close();
    });

    test('corrupted session is cleared and fresh puzzle emitted',
        () async {
      when(
        () => storageRepository.getSession('cascade_state_2026-04-08'),
      ).thenReturn({'invalid': 'data'});

      final cubit = CascadeCubit(
        dailySeed: 42,
        dateKey: '2026-04-08',
        storageRepository: storageRepository,
      );
      await _waitForReady(cubit);

      expect(cubit.state.status, CascadeStatus.configuring);
      expect(cubit.state.attempts, 0);

      verify(
        () => storageRepository.saveSession(
          'cascade_state_2026-04-08',
          null,
        ),
      ).called(1);

      await cubit.close();
    });
  });
}
