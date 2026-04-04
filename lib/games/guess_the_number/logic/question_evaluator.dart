import 'dart:math';

import 'package:very_good_games/games/guess_the_number/logic/prime_checker.dart';
import 'package:very_good_games/games/guess_the_number/models/models.dart';

/// The result of applying a question to the grid.
class QuestionResult {
  /// Creates a [QuestionResult].
  const QuestionResult({
    required this.cells,
    required this.answer,
    required this.eliminatedCount,
  });

  /// The updated cell states after applying the question.
  final List<CellState> cells;

  /// Human-readable answer (e.g., "Is odd? YES").
  final String answer;

  /// How many cells were eliminated by this question.
  final int eliminatedCount;
}

/// Applies a question to the grid and returns the updated cell states.
class QuestionEvaluator {
  QuestionEvaluator._();

  /// Applies [type] with the given parameters against [targetNumber].
  ///
  /// [currentCells] is the current state of all cells.
  /// [param1] and [param2] are the number parameters (1-based).
  /// [random] is injectable for testing shotgun randomness.
  static QuestionResult apply({
    required QuestionType type,
    required int targetNumber,
    required List<CellState> currentCells,
    int? param1,
    int? param2,
    Random? random,
  }) {
    return switch (type) {
      QuestionType.lessThan => _applyComparison(
        currentCells: currentCells,
        targetNumber: targetNumber,
        label: '< $param1',
        test: (n) => n < param1!,
      ),
      QuestionType.isOdd => _applyComparison(
        currentCells: currentCells,
        targetNumber: targetNumber,
        label: 'Is odd',
        test: (n) => n.isOdd,
      ),
      QuestionType.isDivisibleBy => _applyComparison(
        currentCells: currentCells,
        targetNumber: targetNumber,
        label: 'Divisible by $param1',
        test: (n) => param1! > 0 && n % param1 == 0,
      ),
      QuestionType.isPrime => _applyComparison(
        currentCells: currentCells,
        targetNumber: targetNumber,
        label: 'Is prime',
        test: PrimeChecker.isPrime,
      ),
      QuestionType.onesDigitIs => _applyComparison(
        currentCells: currentCells,
        targetNumber: targetNumber,
        label: 'Ends in $param1',
        test: (n) => n % 10 == param1!,
      ),
      QuestionType.equals => _applyEquals(
        currentCells: currentCells,
        targetNumber: targetNumber,
        guess: param1!,
      ),
      QuestionType.shotgun => _applyShotgun(
        currentCells: currentCells,
        targetNumber: targetNumber,
        random: random ?? Random(),
      ),
      QuestionType.handGrenade => _applyHandGrenade(
        currentCells: currentCells,
        targetNumber: targetNumber,
        centerIndex: param1! - 1, // Convert 1-based number to 0-based index.
      ),
    };
  }

  static QuestionResult _applyComparison({
    required List<CellState> currentCells,
    required int targetNumber,
    required String label,
    required bool Function(int number) test,
  }) {
    final targetSatisfies = test(targetNumber);
    final updated = List<CellState>.from(currentCells);
    var eliminated = 0;

    for (var i = 0; i < updated.length; i++) {
      if (updated[i] != CellState.possible) continue;
      final number = i + 1;
      final satisfies = test(number);
      // Eliminate cells that don't match the target's answer.
      if (satisfies != targetSatisfies) {
        updated[i] = CellState.eliminated;
        eliminated++;
      }
    }

    final answer = '$label? ${targetSatisfies ? 'YES' : 'NO'}';
    return QuestionResult(
      cells: updated,
      answer: '$answer — $eliminated eliminated',
      eliminatedCount: eliminated,
    );
  }

  static QuestionResult _applyEquals({
    required List<CellState> currentCells,
    required int targetNumber,
    required int guess,
  }) {
    final updated = List<CellState>.from(currentCells);
    final index = guess - 1;

    if (guess == targetNumber) {
      // Correct guess — eliminate all other possible cells.
      var eliminated = 0;
      for (var i = 0; i < updated.length; i++) {
        if (i != index && updated[i] == CellState.possible) {
          updated[i] = CellState.eliminated;
          eliminated++;
        }
      }
      return QuestionResult(
        cells: updated,
        answer: '= $guess? YES!',
        eliminatedCount: eliminated,
      );
    }

    updated[index] = CellState.wrongGuess;
    return QuestionResult(
      cells: updated,
      answer: '= $guess? NO',
      eliminatedCount: 1,
    );
  }

  static QuestionResult _applyShotgun({
    required List<CellState> currentCells,
    required int targetNumber,
    required Random random,
  }) {
    final updated = List<CellState>.from(currentCells);
    // Pick 50 random unique numbers from the full 1-400 range.
    final allIndices = List.generate(400, (i) => i)..shuffle(random);
    final picked = allIndices.take(50).toSet();

    final targetIndex = targetNumber - 1;
    final targetInPicked = picked.contains(targetIndex);
    var eliminated = 0;

    if (targetInPicked) {
      // Jackpot! Eliminate everything NOT in the picked set.
      for (var i = 0; i < updated.length; i++) {
        if (updated[i] == CellState.possible && !picked.contains(i)) {
          updated[i] = CellState.eliminated;
          eliminated++;
        }
      }
    } else {
      // Miss — eliminate only the picked numbers.
      for (final i in picked) {
        if (updated[i] == CellState.possible) {
          updated[i] = CellState.eliminated;
          eliminated++;
        }
      }
    }

    final hitOrMiss = targetInPicked ? 'HIT' : 'MISS';
    return QuestionResult(
      cells: updated,
      answer: 'Shotgun $hitOrMiss! $eliminated eliminated',
      eliminatedCount: eliminated,
    );
  }

  static QuestionResult _applyHandGrenade({
    required List<CellState> currentCells,
    required int targetNumber,
    required int centerIndex,
  }) {
    final updated = List<CellState>.from(currentCells);
    const columns = 20;
    final centerCol = centerIndex % columns;
    final centerRow = centerIndex ~/ columns;

    // Find all possible cells (excluding target) with their distance.
    final candidates = <(int index, double distance)>[];
    for (var i = 0; i < updated.length; i++) {
      if (updated[i] != CellState.possible) continue;
      if ((i + 1) == targetNumber) continue;
      final col = i % columns;
      final row = i ~/ columns;
      final dx = (col - centerCol).toDouble();
      final dy = (row - centerRow).toDouble();
      candidates.add((i, sqrt(dx * dx + dy * dy)));
    }

    // Sort by distance, take closest 20.
    candidates.sort((a, b) => a.$2.compareTo(b.$2));
    final toEliminate = min(20, candidates.length);
    for (var i = 0; i < toEliminate; i++) {
      updated[candidates[i].$1] = CellState.eliminated;
    }

    return QuestionResult(
      cells: updated,
      answer: 'Grenade! $toEliminate eliminated',
      eliminatedCount: toEliminate,
    );
  }
}
