import 'package:equatable/equatable.dart';
import 'package:very_good_games/games/cascade/models/lever.dart';

/// An immutable board for the Cascade ball-routing puzzle.
///
/// Contains [levers] positioned on a 5-column by 7-row grid
/// and a [binOrder] mapping target bins to ball ids.
class CascadeBoard extends Equatable {
  /// Creates a [CascadeBoard].
  CascadeBoard({required List<Lever> levers, required List<int> binOrder})
    : levers = List.unmodifiable(levers),
      binOrder = List.unmodifiable(binOrder);

  /// Deserializes a [CascadeBoard] from JSON.
  factory CascadeBoard.fromJson(Map<String, dynamic> json) {
    return CascadeBoard(
      levers: (json['levers'] as List<dynamic>)
          .map((e) => Lever.fromJson(e as Map<String, dynamic>))
          .toList(),
      binOrder: (json['binOrder'] as List<dynamic>).cast<int>(),
    );
  }

  /// Number of columns on the board.
  static const columns = 5;

  /// Number of rows on the board.
  static const rows = 7;

  /// Drop slot columns (center 3 of the 5 columns).
  static const dropSlotColumns = [1, 2, 3];

  /// The levers on the board (unmodifiable).
  final List<Lever> levers;

  /// Bin order: `binOrder[i]` is the ball index (0, 1, 2)
  /// expected at bin position `i`.
  final List<int> binOrder;

  /// Returns a new board with the lever at [index] flipped.
  CascadeBoard flipLever(int index) {
    final newLevers = List<Lever>.of(levers);
    newLevers[index] = newLevers[index].flip();
    return CascadeBoard(levers: newLevers, binOrder: binOrder);
  }

  /// Returns a new board with levers replaced by [initialLevers].
  CascadeBoard resetLevers(List<Lever> initialLevers) {
    return CascadeBoard(levers: initialLevers, binOrder: binOrder);
  }

  /// Serializes this board to JSON.
  Map<String, dynamic> toJson() => {
    'levers': levers.map((l) => l.toJson()).toList(),
    'binOrder': List<int>.from(binOrder),
  };

  @override
  List<Object?> get props => [levers, binOrder];
}
