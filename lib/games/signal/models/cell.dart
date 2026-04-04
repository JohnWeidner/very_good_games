/// A cell in the Signal grid puzzle.
sealed class Cell {
  const Cell();

  /// An empty cell that can receive tower signals.
  static const empty = EmptyCell();

  /// A wall that blocks tower signals.
  static const wall = WallCell();

  /// A tower with a target signal count.
  static Tower tower(int targetCount) => Tower(targetCount);
}

/// An empty cell that can receive tower signals.
final class EmptyCell extends Cell {
  const EmptyCell();

  @override
  bool operator ==(Object other) => other is EmptyCell;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'Cell.empty';
}

/// A wall that blocks tower signals.
final class WallCell extends Cell {
  const WallCell();

  @override
  bool operator ==(Object other) => other is WallCell;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'Cell.wall';
}

/// A tower with a [targetCount] of cells it should signal.
final class Tower extends Cell {
  /// Creates a [Tower] with the given [targetCount].
  const Tower(this.targetCount);

  /// The number of cells this tower should reach via signal.
  final int targetCount;

  @override
  bool operator ==(Object other) =>
      other is Tower && other.targetCount == targetCount;

  @override
  int get hashCode => Object.hash(runtimeType, targetCount);

  @override
  String toString() => 'Cell.tower($targetCount)';
}
