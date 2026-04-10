part of 'cascade_cubit.dart';

/// The status of a Cascade puzzle game.
enum CascadeStatus {
  /// Puzzle is being generated.
  loading,

  /// Player is assigning balls and flipping levers.
  configuring,

  /// Ball drop animation is in progress.
  dropping,

  /// All 3 balls reached correct bins.
  won,

  /// At least one ball in wrong bin.
  failed,
}

/// Default ball-to-slot assignments: ball1 in slot 0, ball2 in slot 1,
/// ball3 in slot 2. Ready to drop immediately.
const defaultSlotAssignments = [BallId.ball1, BallId.ball2, BallId.ball3];

/// State for [CascadeCubit].
class CascadeState extends Equatable {
  /// Creates a [CascadeState].
  const CascadeState({
    required this.board,
    required this.initialLevers,
    this.status = CascadeStatus.configuring,
    this.slotAssignments = defaultSlotAssignments,
    this.attempts = 0,
    this.dropResult,
    this.score,
  });

  /// Creates a loading state before the puzzle is generated.
  CascadeState.loading()
    : board = CascadeBoard(levers: const [], binOrder: const [0, 1, 2]),
      initialLevers = const [],
      status = CascadeStatus.loading,
      slotAssignments = defaultSlotAssignments,
      attempts = 0,
      dropResult = null,
      score = null;

  /// The current board with lever states.
  final CascadeBoard board;

  /// Initial lever directions for reset.
  final List<Lever> initialLevers;

  /// Current game status.
  final CascadeStatus status;

  /// Ball assignments for the 3 drop slots. Null means unassigned.
  final List<BallId?> slotAssignments;

  /// Number of drop attempts so far.
  final int attempts;

  /// Result of the last drop simulation (populated during/after dropping).
  final DropResult? dropResult;

  /// Final score, computed on win.
  final int? score;

  /// Whether all 3 balls have been assigned to slots.
  bool get allBallsAssigned => slotAssignments.every((s) => s != null);

  /// Star rating (1-3) based on attempts.
  int get stars => score != null ? cascadeStars(attempts) : 0;

  /// Creates a copy with the given fields replaced.
  CascadeState copyWith({
    CascadeBoard? board,
    List<Lever>? initialLevers,
    CascadeStatus? status,
    List<BallId?>? slotAssignments,
    int? attempts,
    DropResult? Function()? dropResult,
    int? Function()? score,
  }) {
    return CascadeState(
      board: board ?? this.board,
      initialLevers: initialLevers ?? this.initialLevers,
      status: status ?? this.status,
      slotAssignments: slotAssignments ?? this.slotAssignments,
      attempts: attempts ?? this.attempts,
      dropResult: dropResult != null ? dropResult() : this.dropResult,
      score: score != null ? score() : this.score,
    );
  }

  @override
  List<Object?> get props => [
    board,
    initialLevers,
    status,
    slotAssignments,
    attempts,
    dropResult,
    score,
  ];
}
