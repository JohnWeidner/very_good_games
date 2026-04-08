import 'package:very_good_games/games/chromix/logic/color_mixer.dart';
import 'package:very_good_games/games/chromix/logic/contiguity_checker.dart';
import 'package:very_good_games/games/chromix/models/models.dart';

/// Result of solving a Chromix puzzle.
typedef SolveResult = ({bool isUnique, int optimalMoves});

/// Backtracking solver that verifies a Chromix puzzle has a unique solution.
///
/// For each empty cell, tries placing each of the 3 primaries.
/// For each pre-filled primary cell, tries layering each of the 2 other
/// primaries or leaving it as-is.
/// Prunes branches when any color count exceeds the target.
class PuzzleSolver {
  /// Solves the given [grid] against the [target] color distribution.
  ///
  /// Returns whether the solution is unique and the optimal move count.
  /// If no solution exists, returns `isUnique: false, optimalMoves: 0`.
  static SolveResult solve({
    required ChromixGrid grid,
    required Map<ChromixColor, int> target,
  }) {
    final solver = _Solver(grid: grid, target: target)..run();
    return (
      isUnique: solver.solutionCount == 1,
      optimalMoves: solver.bestMoves ?? 0,
    );
  }
}

class _Solver {
  _Solver({required this.grid, required this.target})
    : _cells = List<ChromixCell>.of(grid.cells);

  final ChromixGrid grid;
  final Map<ChromixColor, int> target;
  final List<ChromixCell> _cells;

  int solutionCount = 0;
  int? bestMoves;

  /// Indices of cells that require decisions (empty or layerable primary).
  late final List<int> _decisionIndices = _buildDecisionIndices();

  List<int> _buildDecisionIndices() {
    final indices = <int>[];
    for (var i = 0; i < _cells.length; i++) {
      final cell = _cells[i];
      if (cell is EmptyCell) {
        indices.add(i);
      } else if (cell is ColorCell &&
          cell.isPreFilled &&
          cell.color.isPrimary) {
        indices.add(i);
      }
    }
    return indices;
  }

  /// Current color counts for pruning.
  final Map<ChromixColor, int> _currentCounts = {};

  void _addColor(ChromixColor color) {
    _currentCounts[color] = (_currentCounts[color] ?? 0) + 1;
  }

  void _removeColor(ChromixColor color) {
    final count = _currentCounts[color]!;
    if (count == 1) {
      _currentCounts.remove(color);
    } else {
      _currentCounts[color] = count - 1;
    }
  }

  bool _exceedsTarget() {
    for (final entry in _currentCounts.entries) {
      final limit = target[entry.key] ?? 0;
      if (entry.value > limit) return true;
    }
    return false;
  }

  bool _matchesTarget() {
    for (final color in ChromixColor.values) {
      final actual = _currentCounts[color] ?? 0;
      final expected = target[color] ?? 0;
      if (actual != expected) return false;
    }
    return true;
  }

  void run() {
    // Initialize counts from pre-filled cells that are NOT decision cells.
    for (var i = 0; i < _cells.length; i++) {
      final cell = _cells[i];
      if (cell is ColorCell && !_decisionIndices.contains(i)) {
        _addColor(cell.color);
      }
    }
    _solve(0, 0);
  }

  void _solve(int decisionIdx, int moves) {
    // Stop after finding 2 solutions — we only care about uniqueness.
    if (solutionCount >= 2) return;

    if (decisionIdx == _decisionIndices.length) {
      if (_matchesTarget() &&
          allGroupsContiguous(ChromixGrid(cells: _cells))) {
        solutionCount++;
        if (bestMoves == null || moves < bestMoves!) {
          bestMoves = moves;
        }
      }
      return;
    }

    final cellIdx = _decisionIndices[decisionIdx];
    final cell = _cells[cellIdx];

    if (cell is EmptyCell) {
      _solveEmptyCell(decisionIdx, cellIdx, moves);
    } else if (cell is ColorCell) {
      _solvePreFilledCell(decisionIdx, cellIdx, cell, moves);
    }
  }

  void _solveEmptyCell(int decisionIdx, int cellIdx, int moves) {
    for (final primary in _primaries) {
      _cells[cellIdx] = ColorCell(primary);
      _addColor(primary);

      if (!_exceedsTarget()) {
        _solve(decisionIdx + 1, moves + 1);
      }

      _removeColor(primary);
      _cells[cellIdx] = const EmptyCell();
    }
  }

  void _solvePreFilledCell(
    int decisionIdx,
    int cellIdx,
    ColorCell cell,
    int moves,
  ) {
    // Option 1: leave as-is (count the pre-filled color).
    _addColor(cell.color);
    if (!_exceedsTarget()) {
      _solve(decisionIdx + 1, moves);
    }
    _removeColor(cell.color);

    // Option 2: layer with each of the other 2 primaries.
    for (final other in _primaries) {
      if (other == cell.color) continue;

      final mixed = ColorMixer.mix(cell.color, other);
      if (mixed == null) continue;

      _cells[cellIdx] = ColorCell(mixed);
      _addColor(mixed);

      if (!_exceedsTarget()) {
        _solve(decisionIdx + 1, moves + 1);
      }

      _removeColor(mixed);
      _cells[cellIdx] = cell;
    }
  }

  static const _primaries = [
    ChromixColor.red,
    ChromixColor.yellow,
    ChromixColor.blue,
  ];
}
