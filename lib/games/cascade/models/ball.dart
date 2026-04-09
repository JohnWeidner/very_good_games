/// Identifies one of the three balls in a Cascade puzzle.
enum BallId {
  /// Ball 1 (red).
  ball1,

  /// Ball 2 (blue).
  ball2,

  /// Ball 3 (yellow).
  ball3;

  /// Display label (1, 2, or 3).
  String get label => switch (this) {
    BallId.ball1 => '1',
    BallId.ball2 => '2',
    BallId.ball3 => '3',
  };
}
