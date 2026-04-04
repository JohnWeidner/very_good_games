part of 'signal_cubit.dart';

/// The status of a Signal puzzle game.
enum SignalStatus {
  /// Puzzle is being generated.
  loading,

  /// Game is active — player is placing/removing walls.
  playing,

  /// All towers are satisfied — game complete.
  won,
}

/// State for [SignalCubit].
class SignalState extends Equatable {
  /// Creates a [SignalState].
  const SignalState({
    required this.grid,
    required this.towerSignals,
    required this.solutionWallCount,
    this.status = SignalStatus.playing,
    this.moveCount = 0,
    this.score,
  });

  /// Creates a loading state before the puzzle is generated.
  SignalState.loading()
    : grid = Grid(size: 0, cells: const []),
      towerSignals = const {},
      solutionWallCount = 0,
      status = SignalStatus.loading,
      moveCount = 0,
      score = null;

  /// The current grid with the player's wall placements.
  final Grid grid;

  /// Current signal reach per tower position.
  final Map<(int, int), int> towerSignals;

  /// Number of walls in the generated solution (for display).
  final int solutionWallCount;

  /// Current game status.
  final SignalStatus status;

  /// Total cell state changes (every toggle counts as +1).
  final int moveCount;

  /// Final score, computed on win.
  final int? score;

  /// Number of walls currently placed on the grid.
  int get wallCount => grid.cells.whereType<WallCell>().length;

  /// Whether the player has reached the wall placement limit.
  bool get atWallLimit => wallCount >= solutionWallCount;

  /// Cells that are in a signal ray path from any tower.
  ///
  /// Computed from [grid] and [towerSignals] by casting rays from each
  /// tower in 4 cardinal directions.
  Set<(int, int)> get signaledCells {
    final signaled = <(int, int)>{};
    const directions = [(-1, 0), (1, 0), (0, -1), (0, 1)];

    for (final towerPos in grid.towerPositions) {
      final (tRow, tCol) = towerPos;
      for (final (dr, dc) in directions) {
        var r = tRow + dr;
        var c = tCol + dc;
        while (r >= 0 && r < grid.size && c >= 0 && c < grid.size) {
          final cell = grid.cellAt(r, c);
          if (cell is WallCell || cell is Tower) break;
          signaled.add((r, c));
          r += dr;
          c += dc;
        }
      }
    }

    return signaled;
  }

  /// Creates a copy with the given fields replaced.
  SignalState copyWith({
    Grid? grid,
    Map<(int, int), int>? towerSignals,
    int? solutionWallCount,
    SignalStatus? status,
    int? moveCount,
    int? Function()? score,
  }) {
    return SignalState(
      grid: grid ?? this.grid,
      towerSignals: towerSignals ?? this.towerSignals,
      solutionWallCount: solutionWallCount ?? this.solutionWallCount,
      status: status ?? this.status,
      moveCount: moveCount ?? this.moveCount,
      score: score != null ? score() : this.score,
    );
  }

  @override
  List<Object?> get props => [
    grid,
    towerSignals,
    solutionWallCount,
    status,
    moveCount,
    score,
  ];
}
