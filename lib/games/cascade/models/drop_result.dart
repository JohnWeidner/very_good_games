import 'package:equatable/equatable.dart';
import 'package:very_good_games/games/cascade/models/ball.dart';

/// A single position on the board grid.
typedef BoardPosition = ({int row, int col});

/// A lever flip that occurs during a ball's path.
typedef LeverFlip = ({int leverIndex, int step});

/// The path a ball takes through the board during a drop.
class BallPath extends Equatable {
  /// Creates a [BallPath].
  const BallPath({
    required this.ballId,
    required this.positions,
    required this.finalBin,
    this.leverFlips = const [],
    this.wallBounces = const {},
  });

  /// Which ball this path is for.
  final BallId ballId;

  /// Each position the ball passes through, in order.
  ///
  /// Includes intermediate positions for lever deflections and
  /// wall bounces to produce smooth animation.
  final List<BoardPosition> positions;

  /// Which bin column the ball landed in (1, 2, or 3).
  final int finalBin;

  /// Lever flips that occur during this ball's traversal.
  ///
  /// Each entry records which lever index flipped and at which
  /// step in [positions] the flip happened.
  final List<LeverFlip> leverFlips;

  /// Position indices where a wall bounce begins.
  ///
  /// A wall bounce consists of two segments: the ball moves toward
  /// the wall edge, then bounces back. The index marks the start
  /// of the outward segment.
  final Set<int> wallBounces;

  @override
  List<Object?> get props => [
    ballId,
    positions,
    finalBin,
    leverFlips,
    wallBounces,
  ];
}

/// The result of simulating all three ball drops.
class DropResult extends Equatable {
  /// Creates a [DropResult].
  const DropResult({required this.paths, required this.isWin});

  /// One path per ball, in drop order (slot 0, slot 1, slot 2).
  final List<BallPath> paths;

  /// Whether all three balls landed in their correct target bins.
  final bool isWin;

  @override
  List<Object?> get props => [paths, isWin];
}
