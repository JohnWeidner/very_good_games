part of 'chromix_cubit.dart';

/// The status of a Chromix puzzle game.
enum ChromixStatus {
  /// Puzzle is being generated.
  loading,

  /// Game is active — player is placing/mixing colors.
  playing,

  /// All non-blockers filled and distribution matches target — game complete.
  won,
}

/// State for [ChromixCubit].
class ChromixState extends Equatable {
  /// Creates a [ChromixState].
  const ChromixState({
    required this.grid,
    required this.target,
    required this.optimalMoves,
    this.status = ChromixStatus.playing,
    this.moveCount = 0,
    this.undoCount = 0,
    this.moveHistory = const [],
    this.dragOrigin,
    this.dragColor,
    this.hasContiguityViolation = false,
    this.score,
  });

  /// Creates a loading state before the puzzle is generated.
  ChromixState.loading()
    : grid = ChromixGrid(cells: List.filled(16, const EmptyCell())),
      target = const {},
      optimalMoves = 0,
      status = ChromixStatus.loading,
      moveCount = 0,
      undoCount = 0,
      moveHistory = const [],
      dragOrigin = null,
      dragColor = null,
      hasContiguityViolation = false,
      score = null;

  /// The current grid with the player's placements.
  final ChromixGrid grid;

  /// Target color distribution to match.
  final Map<ChromixColor, int> target;

  /// Minimum moves from the generator (for star calculation).
  final int optimalMoves;

  /// Current game status.
  final ChromixStatus status;

  /// Total placements (never decremented on undo).
  final int moveCount;

  /// Total undo presses.
  final int undoCount;

  /// Undo stack of previous cell states.
  final List<MoveRecord> moveHistory;

  /// The cell the player is currently dragging from (transient, not persisted).
  final ({int row, int col})? dragOrigin;

  /// The primary color being dragged (transient, not persisted).
  final ChromixColor? dragColor;

  /// Whether any color whose count matches its target is non-contiguous.
  final bool hasContiguityViolation;

  /// Final score, computed on win.
  final int? score;

  /// Current color distribution (delegates to grid).
  Map<ChromixColor, int> get currentDistribution => grid.colorDistribution;

  /// Star rating (1–3) based on score and optimal moves.
  int get stars => score != null ? chromixStars(score!, optimalMoves) : 0;

  /// Creates a copy with the given fields replaced.
  ChromixState copyWith({
    ChromixGrid? grid,
    Map<ChromixColor, int>? target,
    int? optimalMoves,
    ChromixStatus? status,
    int? moveCount,
    int? undoCount,
    List<MoveRecord>? moveHistory,
    ({int row, int col})? Function()? dragOrigin,
    ChromixColor? Function()? dragColor,
    bool? hasContiguityViolation,
    int? Function()? score,
  }) {
    return ChromixState(
      grid: grid ?? this.grid,
      target: target ?? this.target,
      optimalMoves: optimalMoves ?? this.optimalMoves,
      status: status ?? this.status,
      moveCount: moveCount ?? this.moveCount,
      undoCount: undoCount ?? this.undoCount,
      moveHistory: moveHistory ?? this.moveHistory,
      dragOrigin: dragOrigin != null ? dragOrigin() : this.dragOrigin,
      dragColor: dragColor != null ? dragColor() : this.dragColor,
      hasContiguityViolation:
          hasContiguityViolation ?? this.hasContiguityViolation,
      score: score != null ? score() : this.score,
    );
  }

  @override
  List<Object?> get props => [
    grid,
    target,
    optimalMoves,
    status,
    moveCount,
    undoCount,
    moveHistory,
    dragOrigin,
    dragColor,
    hasContiguityViolation,
    score,
  ];
}
