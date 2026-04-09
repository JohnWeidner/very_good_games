import 'package:flutter/material.dart';
import 'package:very_good_games/games/cascade/models/models.dart';
import 'package:very_good_games/games/cascade/theme/theme.dart';
import 'package:very_good_games/games/cascade/view/widgets/ball_widget.dart';

/// A transparent target bin at the bottom of the board.
///
/// Shows the expected ball number. Transparent so that a landed
/// ball is visible underneath (like a glass jar). No top border
/// so the ball appears to drop in from above.
class BinWidget extends StatelessWidget {
  /// Creates a [BinWidget].
  const BinWidget({
    required this.expectedBallId,
    required this.cellSize,
    super.key,
  });

  /// The ball that should land in this bin.
  final BallId expectedBallId;

  /// Size of the grid cell.
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    const side = BorderSide(
      color: CascadeColors.binNeutral,
      width: 1.5,
    );

    return SizedBox(
      width: cellSize,
      height: cellSize,
      child: Container(
        margin: const EdgeInsets.only(left: 2, right: 2, bottom: 2),
        decoration: const BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
          border: Border(
            left: side,
            right: side,
            bottom: side,
          ),
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              expectedBallId.label,
              style: TextStyle(
                color: ballColor(expectedBallId),
                fontWeight: FontWeight.bold,
                fontSize: cellSize * 0.35,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
