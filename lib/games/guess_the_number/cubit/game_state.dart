part of 'game_cubit.dart';

/// The overall game status.
enum GameStatus {
  /// Game is active — player is browsing the card tray.
  playing,

  /// A question card is staged — player is picking parameters.
  selectingParam,

  /// Player has filled all params — waiting for confirm/cancel.
  readyToConfirm,

  /// Player has guessed the correct number.
  won,

  /// Score reached zero — game over.
  lost,
}

/// The state of a Guess the Number game.
class GameState extends Equatable {
  /// Creates a [GameState].
  const GameState({
    required this.cells,
    required this.targetNumber,
    this.status = GameStatus.playing,
    this.usedQuestionTypes = const {},
    this.activeQuestionType,
    this.highlightedCell,
    this.firstParam,
    this.questionCount = 0,
    this.elapsedSeconds = 0,
    this.timerStarted = false,
    this.score,
    this.lastResult,
  });

  /// The visual state of each of the 400 cells.
  final List<CellState> cells;

  /// The target number the player is trying to guess.
  final int targetNumber;

  /// Current game status.
  final GameStatus status;

  /// Question types that have been used (and cannot be reused).
  final Set<QuestionType> usedQuestionTypes;

  /// The question type currently staged on the card, if any.
  final QuestionType? activeQuestionType;

  /// The cell index currently under the player's finger (0-based).
  final int? highlightedCell;

  /// The parameter value for this question (1-based number or raw digit).
  final int? firstParam;

  /// How many questions the player has asked.
  final int questionCount;

  /// Seconds elapsed since the first question was played.
  final int elapsedSeconds;

  /// Whether the timer has started (first question played).
  final bool timerStarted;

  /// Final score (non-null only when [status] is [GameStatus.won]).
  final int? score;

  /// Feedback text from the last question result.
  final String? lastResult;

  /// The number of cells still in [CellState.possible] state.
  int get remainingCount => cells.where((c) => c == CellState.possible).length;

  /// The live score based on current questions and time.
  int get currentScore => ScoreCalculator.calculate(
    questions: questionCount,
    seconds: elapsedSeconds,
  );

  /// The 1-based number for a given cell index.
  static int numberForIndex(int index) => index + 1;

  /// Whether the staged card is ready to confirm.
  ///
  /// True when we have a no-param question staged, or all required
  /// params are filled.
  bool get canConfirm => status == GameStatus.readyToConfirm;

  /// Creates a copy with the given fields replaced.
  GameState copyWith({
    List<CellState>? cells,
    int? targetNumber,
    GameStatus? status,
    Set<QuestionType>? usedQuestionTypes,
    QuestionType? Function()? activeQuestionType,
    int? Function()? highlightedCell,
    int? Function()? firstParam,
    int? questionCount,
    int? elapsedSeconds,
    bool? timerStarted,
    int? Function()? score,
    String? Function()? lastResult,
  }) {
    return GameState(
      cells: cells ?? this.cells,
      targetNumber: targetNumber ?? this.targetNumber,
      status: status ?? this.status,
      usedQuestionTypes: usedQuestionTypes ?? this.usedQuestionTypes,
      activeQuestionType: activeQuestionType != null
          ? activeQuestionType()
          : this.activeQuestionType,
      highlightedCell: highlightedCell != null
          ? highlightedCell()
          : this.highlightedCell,
      firstParam: firstParam != null ? firstParam() : this.firstParam,
      questionCount: questionCount ?? this.questionCount,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      timerStarted: timerStarted ?? this.timerStarted,
      score: score != null ? score() : this.score,
      lastResult: lastResult != null ? lastResult() : this.lastResult,
    );
  }

  @override
  List<Object?> get props => [
    cells,
    targetNumber,
    status,
    usedQuestionTypes,
    activeQuestionType,
    highlightedCell,
    firstParam,
    questionCount,
    elapsedSeconds,
    timerStarted,
    score,
    lastResult,
  ];
}
