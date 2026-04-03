/// The category of a question type, used for visual grouping in the card tray.
enum QuestionCategory {
  /// Comparison questions.
  comparison,

  /// Math property questions.
  math,

  /// Guess the exact number.
  guess,

  /// Special moves (shotgun, hand grenade).
  special,
}

/// A question type the player can ask to eliminate numbers from the grid.
///
/// Each type can only be used once per game, except [equals] which
/// is repeatable.
enum QuestionType {
  /// Is the target less than N?
  lessThan(
    label: '< N',
    description: 'Less than',
    category: QuestionCategory.comparison,
    paramCount: 1,
  ),

  /// Is the target odd?
  isOdd(
    label: 'odd?',
    description: 'Is odd',
    category: QuestionCategory.math,
    paramCount: 0,
  ),

  /// Is the target divisible by N?
  isDivisibleBy(
    label: '÷ N',
    description: 'Divisible by',
    category: QuestionCategory.math,
    paramCount: 1,
    usesDigitPicker: true,
    pickerValues: [2, 3, 5, 7, 11, 13, 17, 19],
  ),

  /// Is the target prime?
  isPrime(
    label: 'prime?',
    description: 'Is prime',
    category: QuestionCategory.math,
    paramCount: 0,
  ),

  /// Does the target's ones digit equal N (0–9)?
  onesDigitIs(
    label: 'ends in',
    description: 'Ones digit is',
    category: QuestionCategory.math,
    paramCount: 1,
    usesDigitPicker: true,
  ),

  /// Guess the exact number. Can be used multiple times.
  equals(
    label: '= N',
    description: 'Guess exact',
    category: QuestionCategory.guess,
    paramCount: 1,
    isRepeatable: true,
  ),

  /// Picks 50 random numbers — if the target is among them,
  /// eliminates everything else. Otherwise eliminates just those 50.
  shotgun(
    label: 'shotgun',
    description: 'Lucky 50 gamble',
    category: QuestionCategory.special,
    paramCount: 0,
  ),

  /// Eliminates 20 closest remaining cells to the chosen cell.
  handGrenade(
    label: 'grenade',
    description: 'Area eliminate',
    category: QuestionCategory.special,
    paramCount: 1,
  );

  const QuestionType({
    required this.label,
    required this.description,
    required this.category,
    required this.paramCount,
    this.isRepeatable = false,
    this.usesDigitPicker = false,
    this.pickerValues,
  });

  /// Short label shown on the card (e.g., '< N').
  final String label;

  /// Plain-language description (e.g., 'Less than').
  final String description;

  /// Category for visual grouping.
  final QuestionCategory category;

  /// Number of parameters required (0, 1, or 2).
  final int paramCount;

  /// Whether this question can be used more than once.
  final bool isRepeatable;

  /// Whether this question uses a digit picker instead of the grid.
  final bool usesDigitPicker;

  /// Custom values to display in the digit picker.
  ///
  /// When `null` and [usesDigitPicker] is `true`, defaults to 0–9.
  final List<int>? pickerValues;
}
