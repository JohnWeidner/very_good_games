import 'dart:math';

import 'package:very_good_games/games/signal/logic/signal_calculator.dart';
import 'package:very_good_games/games/signal/models/models.dart';

/// Deterministic puzzle generation from a daily seed.
///
/// Pure function: same seed always produces the same puzzle.
/// After generating the puzzle layout, a solver finds the minimum number
/// of walls needed to satisfy all tower constraints.
class PuzzleGenerator {
  /// Generates a puzzle from the given [seed].
  ///
  /// Returns the player-facing puzzle grid (towers + empty cells, no walls)
  /// and the minimum number of walls required to solve it.
  static ({Grid puzzle, int solutionWallCount}) generate(int seed) {
    final absSeed = seed.abs();
    final random = Random(absSeed);
    final size = absSeed % 3 == 0 ? 6 : 5;

    // Target ranges from the plan.
    final minTowers = size == 5 ? 3 : 4;
    final maxTowers = size == 5 ? 5 : 7;
    final minWalls = size == 5 ? 4 : 6;
    final maxWalls = size == 5 ? 8 : 12;

    final towerCount = minTowers + random.nextInt(maxTowers - minTowers + 1);
    final wallCount = minWalls + random.nextInt(maxWalls - minWalls + 1);

    // Step 1: Place towers on random non-overlapping positions.
    final totalCells = size * size;
    final positions = List.generate(totalCells, (i) => i)..shuffle(random);
    final towerIndices = positions.take(towerCount).toSet();

    // Step 2: Place walls on remaining positions.
    final availableForWalls =
        positions.where((i) => !towerIndices.contains(i)).toList();
    final wallIndices = availableForWalls.take(wallCount).toSet();

    // Step 3: Build the solution grid.
    final solutionCells = List<Cell>.generate(totalCells, (i) {
      if (towerIndices.contains(i)) return Cell.tower(0);
      if (wallIndices.contains(i)) return Cell.wall;
      return Cell.empty;
    });
    final solutionGrid = Grid(size: size, cells: solutionCells);

    // Step 4: Compute signal counts from solution and set tower targets.
    final signals = SignalCalculator.calculate(solutionGrid);
    final puzzleCells = List<Cell>.generate(totalCells, (i) {
      if (towerIndices.contains(i)) {
        final row = i ~/ size;
        final col = i % size;
        return Cell.tower(signals[(row, col)]!);
      }
      return Cell.empty;
    });

    final puzzle = Grid(size: size, cells: puzzleCells);

    // Step 5: Find the minimum walls needed to solve the puzzle.
    final minWallCount = _MinWallSolver(puzzle).solve();

    return (puzzle: puzzle, solutionWallCount: minWallCount);
  }
}

/// Optimized solver that finds the minimum walls to satisfy all towers.
///
/// Key optimizations over naive backtracking:
/// - Only considers cells that are in at least one tower's ray (others
///   have no effect on signals)
/// - Uses a mutable cell array instead of immutable Grid copies
/// - Computes signals incrementally: only recalculates towers whose
///   rays pass through the modified cell
/// - Prunes immediately when any tower drops below its target
class _MinWallSolver {
  _MinWallSolver(this.puzzle)
    : size = puzzle.size,
      _cells = List<Cell>.of(puzzle.cells);

  final Grid puzzle;
  final int size;
  final List<Cell> _cells;

  late final List<({int row, int col, int target})> _towers = _buildTowers();
  late final List<int> _currentSignals = _computeAllSignals();

  // For each cell index, which tower indices have this cell in a ray.
  late final List<List<int>> _cellToTowers = _buildCellToTowers();

  // Only cells worth considering — those in at least one tower's ray.
  late final List<int> _candidateCells = _buildCandidateCells();

  List<({int row, int col, int target})> _buildTowers() {
    final towers = <({int row, int col, int target})>[];
    for (final pos in puzzle.towerPositions) {
      final tower = puzzle.cellAt(pos.$1, pos.$2) as Tower;
      towers.add((row: pos.$1, col: pos.$2, target: tower.targetCount));
    }
    return towers;
  }

  List<int> _computeAllSignals() {
    return [
      for (final t in _towers) _computeSignal(t.row, t.col),
    ];
  }

  int _computeSignal(int tRow, int tCol) {
    var count = 0;
    for (final (dr, dc) in _directions) {
      var r = tRow + dr;
      var c = tCol + dc;
      while (r >= 0 && r < size && c >= 0 && c < size) {
        final cell = _cells[r * size + c];
        if (cell is WallCell || cell is Tower) break;
        count++;
        r += dr;
        c += dc;
      }
    }
    return count;
  }

  List<List<int>> _buildCellToTowers() {
    final mapping = List.generate(size * size, (_) => <int>[]);

    for (var ti = 0; ti < _towers.length; ti++) {
      final t = _towers[ti];
      for (final (dr, dc) in _directions) {
        var r = t.row + dr;
        var c = t.col + dc;
        while (r >= 0 && r < size && c >= 0 && c < size) {
          final cell = puzzle.cellAt(r, c);
          if (cell is Tower) break;
          mapping[r * size + c].add(ti);
          r += dr;
          c += dc;
        }
      }
    }

    return mapping;
  }

  List<int> _buildCandidateCells() {
    final candidates = <int>[];
    for (var i = 0; i < _cells.length; i++) {
      if (_cells[i] is EmptyCell && _cellToTowers[i].isNotEmpty) {
        candidates.add(i);
      }
    }
    return candidates;
  }

  bool get _isSolved {
    for (var i = 0; i < _towers.length; i++) {
      if (_currentSignals[i] != _towers[i].target) return false;
    }
    return true;
  }

  bool get _anyUnderTarget {
    for (var i = 0; i < _towers.length; i++) {
      if (_currentSignals[i] < _towers[i].target) return true;
    }
    return false;
  }

  static const _timeLimit = Duration(seconds: 5);
  late final Stopwatch _stopwatch;
  bool _timedOut = false;

  /// The best (lowest) wall count for which a solution was found,
  /// or `null` if none found yet.
  int? _bestFound;

  int solve() {
    if (_isSolved) return 0;

    _stopwatch = Stopwatch()..start();

    for (var k = 1; k <= _candidateCells.length; k++) {
      if (_timedOut) break;
      if (_search(k, 0, 0)) return k;
    }

    // Timed out — return best found, or fall back to candidate count.
    return _bestFound ?? _candidateCells.length;
  }

  bool _search(int target, int placed, int startIndex) {
    if (_timedOut) return false;

    // Check timeout periodically (every 1000 nodes to avoid
    // Stopwatch overhead on every call).
    if (placed == 0 || (startIndex & 0x3FF) == 0) {
      if (_stopwatch.elapsed >= _timeLimit) {
        _timedOut = true;
        return false;
      }
    }

    if (placed == target) {
      if (_isSolved) {
        _bestFound = target;
        return true;
      }
      return false;
    }
    if (_anyUnderTarget) return false;
    if (_candidateCells.length - startIndex < target - placed) return false;

    for (var i = startIndex; i < _candidateCells.length; i++) {
      final ci = _candidateCells[i];

      // Place wall.
      _cells[ci] = Cell.wall;
      final affectedTowers = _cellToTowers[ci];
      final savedSignals = [
        for (final ti in affectedTowers) _currentSignals[ti],
      ];
      for (final ti in affectedTowers) {
        _currentSignals[ti] = _computeSignal(
          _towers[ti].row,
          _towers[ti].col,
        );
      }

      if (_search(target, placed + 1, i + 1)) {
        // Undo for caller (iterative deepening retries).
        _cells[ci] = Cell.empty;
        for (var j = 0; j < affectedTowers.length; j++) {
          _currentSignals[affectedTowers[j]] = savedSignals[j];
        }
        return true;
      }

      // Undo wall.
      _cells[ci] = Cell.empty;
      for (var j = 0; j < affectedTowers.length; j++) {
        _currentSignals[affectedTowers[j]] = savedSignals[j];
      }
    }

    return false;
  }

  static const _directions = [(-1, 0), (1, 0), (0, -1), (0, 1)];
}
