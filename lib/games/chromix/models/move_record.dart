import 'package:equatable/equatable.dart';
import 'package:very_good_games/games/chromix/models/chromix_cell.dart';

/// An entry in the undo stack, recording the previous state of a cell.
class MoveRecord extends Equatable {
  /// Creates a [MoveRecord] for the cell at [cellIndex] with its
  /// [previousCell] state before the move.
  const MoveRecord({required this.cellIndex, required this.previousCell});

  /// Deserializes a [MoveRecord] from JSON.
  factory MoveRecord.fromJson(Map<String, dynamic> json) {
    return MoveRecord(
      cellIndex: json['cellIndex'] as int,
      previousCell: ChromixCell.fromJson(
        json['previousCell'] as Map<String, dynamic>,
      ),
    );
  }

  /// The flat index of the cell that was modified.
  final int cellIndex;

  /// The cell state before the move was applied.
  final ChromixCell previousCell;

  /// Serializes this record to JSON.
  Map<String, dynamic> toJson() => {
    'cellIndex': cellIndex,
    'previousCell': previousCell.toJson(),
  };

  @override
  List<Object?> get props => [cellIndex, previousCell];
}
