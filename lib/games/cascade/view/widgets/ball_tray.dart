import 'package:flutter/material.dart';
import 'package:very_good_games/games/cascade/models/models.dart';
import 'package:very_good_games/games/cascade/view/widgets/ball_widget.dart';

/// The tray of balls above the drop slots.
///
/// Balls that are not yet assigned to a slot appear here as draggable.
class BallTray extends StatelessWidget {
  /// Creates a [BallTray].
  const BallTray({
    required this.slotAssignments,
    required this.onBallAssigned,
    required this.enabled,
    super.key,
  });

  /// Current slot assignments (null = unassigned).
  final List<BallId?> slotAssignments;

  /// Called when a ball is assigned to a slot via drag.
  final void Function(BallId ball, int slotIndex) onBallAssigned;

  /// Whether interaction is enabled.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // Balls not assigned to any slot.
    final unassigned = BallId.values.where(
      (b) => !slotAssignments.contains(b),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final ball in unassigned) ...[
            if (enabled)
              Draggable<BallId>(
                data: ball,
                feedback: Material(
                  color: Colors.transparent,
                  child: BallWidget(ballId: ball),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: BallWidget(ballId: ball),
                ),
                child: BallWidget(ballId: ball),
              )
            else
              BallWidget(ballId: ball),
            const SizedBox(width: 16),
          ],
        ],
      ),
    );
  }
}
