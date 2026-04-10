import 'package:equatable/equatable.dart';

/// Direction a lever deflects a ball.
enum LeverDirection {
  /// Deflects left (col - 1).
  left,

  /// Deflects right (col + 1).
  right;

  /// Returns the opposite direction.
  LeverDirection get opposite =>
      this == LeverDirection.left ? LeverDirection.right : LeverDirection.left;
}

/// A toggle lever positioned on the board that deflects balls.
///
/// When a ball arrives at this lever's position, it deflects in
/// [direction], then the lever flips to the opposite direction.
class Lever extends Equatable {
  /// Creates a [Lever] at ([row], [col]) pointing in [direction].
  const Lever({required this.row, required this.col, required this.direction});

  /// Deserializes a [Lever] from JSON.
  factory Lever.fromJson(Map<String, dynamic> json) {
    return Lever(
      row: json['row'] as int,
      col: json['col'] as int,
      direction: LeverDirection.values.byName(json['direction'] as String),
    );
  }

  /// Row position on the board.
  final int row;

  /// Column position on the board.
  final int col;

  /// Current deflection direction.
  final LeverDirection direction;

  /// Returns a new lever with the direction flipped.
  Lever flip() => Lever(row: row, col: col, direction: direction.opposite);

  /// Serializes this lever to JSON.
  Map<String, dynamic> toJson() => {
    'row': row,
    'col': col,
    'direction': direction.name,
  };

  @override
  List<Object?> get props => [row, col, direction];
}
