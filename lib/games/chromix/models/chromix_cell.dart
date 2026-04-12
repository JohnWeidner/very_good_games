import 'package:flutter/foundation.dart';
import 'package:very_good_games/games/chromix/models/chromix_color.dart';

/// A cell in the Chromix grid puzzle.
sealed class ChromixCell {
  const ChromixCell();

  /// An empty cell that can receive a primary color.
  static const empty = EmptyCell();

  /// A black blocker cell.
  static const blocker = BlockerCell();

  /// A cell holding a color.
  static ColorCell color(ChromixColor color, {bool isPreFilled = false}) =>
      ColorCell(color, isPreFilled: isPreFilled);

  /// Deserializes a [ChromixCell] from JSON.
  static ChromixCell fromJson(Map<String, dynamic> json) {
    return switch (json['type'] as String) {
      'empty' => const EmptyCell(),
      'blocker' => const BlockerCell(),
      'color' => ColorCell(
        ChromixColor.values.byName(json['color'] as String),
        isPreFilled: json['isPreFilled'] as bool? ?? false,
      ),
      _ => throw ArgumentError('Unknown cell type: ${json['type']}'),
    };
  }

  /// Serializes this cell to JSON.
  Map<String, dynamic> toJson();
}

/// An empty cell that can receive a primary color.
@immutable
final class EmptyCell extends ChromixCell {
  const EmptyCell();

  @override
  Map<String, dynamic> toJson() => {'type': 'empty'};

  @override
  bool operator ==(Object other) => other is EmptyCell;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'ChromixCell.empty';
}

/// A cell holding a [ChromixColor].
///
/// Locked if the color is secondary — secondaries can only be replaced
/// by a component primary via component-overpower.
/// Pre-filled primaries can be layered with another primary to produce
/// a secondary.
@immutable
final class ColorCell extends ChromixCell {
  /// Creates a [ColorCell] with the given [color].
  const ColorCell(this.color, {this.isPreFilled = false});

  /// The color held by this cell.
  final ChromixColor color;

  /// Whether this cell was pre-filled in the puzzle.
  final bool isPreFilled;

  /// Whether this cell is locked (secondary colors cannot be changed).
  bool get isLocked => color.isSecondary;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'color',
    'color': color.name,
    'isPreFilled': isPreFilled,
  };

  @override
  bool operator ==(Object other) =>
      other is ColorCell &&
      other.color == color &&
      other.isPreFilled == isPreFilled;

  @override
  int get hashCode => Object.hash(runtimeType, color, isPreFilled);

  @override
  String toString() => 'ChromixCell.color($color, isPreFilled: $isPreFilled)';
}

/// A black blocker cell that cannot be modified.
@immutable
final class BlockerCell extends ChromixCell {
  const BlockerCell();

  @override
  Map<String, dynamic> toJson() => {'type': 'blocker'};

  @override
  bool operator ==(Object other) => other is BlockerCell;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'ChromixCell.blocker';
}
