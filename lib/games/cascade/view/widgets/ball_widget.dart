import 'package:flutter/material.dart';
import 'package:very_good_games/games/cascade/models/models.dart';
import 'package:very_good_games/games/cascade/theme/theme.dart';

/// Returns the color for a [BallId].
Color ballColor(BallId id) => switch (id) {
  BallId.ball1 => CascadeColors.ball1,
  BallId.ball2 => CascadeColors.ball2,
  BallId.ball3 => CascadeColors.ball3,
};

/// A circular ball widget displaying its number.
class BallWidget extends StatelessWidget {
  /// Creates a [BallWidget].
  const BallWidget({required this.ballId, this.size = 40, super.key});

  /// Which ball to display.
  final BallId ballId;

  /// Diameter of the ball.
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ballColor(ballId),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: ballColor(ballId).withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          ballId.label,
          style: TextStyle(
            color: ballId == BallId.ball3 ? Colors.black87 : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: size * 0.45,
          ),
        ),
      ),
    );
  }
}
