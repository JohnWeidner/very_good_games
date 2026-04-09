import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:very_good_games/games/cascade/cubit/cubit.dart';
import 'package:very_good_games/games/cascade/models/models.dart';
import 'package:very_good_games/games/cascade/theme/theme.dart';
import 'package:very_good_games/games/cascade/view/widgets/ball_widget.dart';
import 'package:very_good_games/games/cascade/view/widgets/bin_widget.dart';
import 'package:very_good_games/games/cascade/view/widgets/lever_widget.dart';

/// Ball size relative to cell size everywhere (slots, drop, landed).
const _ballScale = 0.45;

/// The main board grid showing levers, drop slots, bins, and
/// animated balls during the drop phase.
class CascadeBoardWidget extends StatefulWidget {
  /// Creates a [CascadeBoardWidget].
  const CascadeBoardWidget({super.key});

  @override
  State<CascadeBoardWidget> createState() => _CascadeBoardWidgetState();
}

class _CascadeBoardWidgetState extends State<CascadeBoardWidget>
    with TickerProviderStateMixin {
  AnimationController? _dropController;

  /// Which ball is currently animating (0, 1, 2), or 3 when done.
  int _currentBallIndex = 0;

  /// Fractional progress within the current ball's path (0.0 to
  /// positions.length - 1). Used to interpolate smoothly between
  /// grid positions.
  double _currentProgress = 0;

  @override
  void dispose() {
    _dropController?.dispose();
    super.dispose();
  }

  void _startDropAnimation(CascadeState state) {
    final result = state.dropResult;
    if (result == null) return;

    _currentBallIndex = 0;
    _currentProgress = 0;

    // Total segments (gaps between positions) across all balls.
    final totalSegments = result.paths.fold<int>(
      0,
      (sum, p) => sum + p.positions.length - 1,
    );

    _dropController?.dispose();
    _dropController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalSegments * 500),
    );

    _dropController!.addListener(() {
      if (!mounted) return;
      final progress = _dropController!.value * totalSegments;
      var segmentsConsumed = 0;

      for (var i = 0; i < result.paths.length; i++) {
        final segments = result.paths[i].positions.length - 1;
        if (progress < segmentsConsumed + segments) {
          setState(() {
            _currentBallIndex = i;
            _currentProgress = progress - segmentsConsumed;
          });
          return;
        }
        segmentsConsumed += segments;
      }

      // Animation complete.
      setState(() {
        _currentBallIndex = result.paths.length;
        _currentProgress = 0;
      });
    });

    _dropController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        context.read<CascadeCubit>().completeDrop();
      }
    });

    _dropController!.forward();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CascadeCubit, CascadeState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status &&
          curr.status == CascadeStatus.dropping,
      listener: (context, state) => _startDropAnimation(state),
      builder: (context, state) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final cellSize = constraints.maxWidth / CascadeBoard.columns;
            // Board rows + 1 for bins.
            final totalHeight =
                cellSize * (CascadeBoard.rows + 1);

            return GestureDetector(
              onTap: state.status == CascadeStatus.dropping
                  ? () {
                      _dropController?.stop();
                      _dropController?.dispose();
                      _dropController = null;
                      context.read<CascadeCubit>().skipAnimation();
                    }
                  : null,
              child: Container(
                height: totalHeight,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: CascadeColors.gridLine,
                  ),
                ),
                child: Stack(
                  children: [
                    // Grid background.
                    _buildGrid(cellSize),
                    // Drop slots.
                    ..._buildDropSlots(state, cellSize),
                    // Levers.
                    ..._buildLevers(state, cellSize),
                    // Bins.
                    ..._buildBins(state, cellSize),
                    // Animated balls during drop, or landed balls
                    // after drop completes.
                    if (state.status == CascadeStatus.dropping)
                      ..._buildAnimatedBalls(state, cellSize),
                    if (state.status == CascadeStatus.won ||
                        state.status == CascadeStatus.failed)
                      ..._buildLandedBalls(state, cellSize),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGrid(double cellSize) {
    return CustomPaint(
      size: Size(
        cellSize * CascadeBoard.columns,
        cellSize * (CascadeBoard.rows + 1),
      ),
      painter: _GridPainter(cellSize: cellSize),
    );
  }

  /// Whether a slot ball should be visible. During configuring,
  /// always visible. During dropping, visible only until its ball
  /// starts animating. Hidden during won/failed (landed balls
  /// render instead).
  bool _shouldShowSlotBall(CascadeState state, BallId ball) {
    if (state.status == CascadeStatus.configuring) return true;
    if (state.status != CascadeStatus.dropping) return false;

    // Balls drop in BallId order. _currentBallIndex is the index
    // into the drop order (0 = ball1, 1 = ball2, 2 = ball3).
    // Show the slot ball if its drop hasn't started yet.
    return ball.index > _currentBallIndex;
  }

  List<Widget> _buildDropSlots(
    CascadeState state,
    double cellSize,
  ) {
    final isConfiguring =
        state.status == CascadeStatus.configuring;

    return List.generate(3, (slotIndex) {
      final col = CascadeBoard.dropSlotColumns[slotIndex];
      final assignedBall = state.slotAssignments[slotIndex];

      return Positioned(
        left: col * cellSize,
        top: 0,
        child: DragTarget<BallId>(
          onAcceptWithDetails: isConfiguring
              ? (details) => context
                    .read<CascadeCubit>()
                    .assignBall(details.data, slotIndex)
              : null,
          builder: (context, candidateData, rejectedData) {
            final isHighlighted = candidateData.isNotEmpty;

            // Show bottom border unless this slot's ball has
            // started dropping (opened the gate).
            final ballHasDropped = assignedBall != null &&
                !_shouldShowSlotBall(state, assignedBall);
            const slotBorder = BorderSide(color: CascadeColors.gridLine);

            return Container(
              width: cellSize,
              height: cellSize,
              decoration: isHighlighted
                  ? BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      border: Border.all(color: Colors.blue.shade300),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : BoxDecoration(
                      border: Border(
                        left: slotBorder,
                        right: slotBorder,
                        bottom: ballHasDropped
                            ? BorderSide.none
                            : slotBorder,
                      ),
                    ),
              child: assignedBall != null &&
                      _shouldShowSlotBall(state, assignedBall)
                  ? isConfiguring
                      ? Draggable<BallId>(
                          data: assignedBall,
                          feedback: Material(
                            color: Colors.transparent,
                            child: BallWidget(
                              ballId: assignedBall,
                              size: cellSize * _ballScale,
                            ),
                          ),
                          childWhenDragging: Center(
                            child: Icon(
                              Icons.arrow_downward,
                              color: CascadeColors.gridLine,
                              size: cellSize * 0.4,
                            ),
                          ),
                          child: Center(
                            child: BallWidget(
                              ballId: assignedBall,
                              size: cellSize * _ballScale,
                            ),
                          ),
                        )
                      : Center(
                          child: BallWidget(
                            ballId: assignedBall,
                            size: cellSize * _ballScale,
                          ),
                        )
                  : Center(
                      child: Icon(
                        Icons.arrow_downward,
                        color: CascadeColors.gridLine,
                        size: cellSize * 0.4,
                      ),
                    ),
            );
          },
        ),
      );
    });
  }

  /// Computes which lever directions to display based on animation
  /// progress or post-drop state. During the drop, levers flip as
  /// balls pass through them. After a drop (won/failed), all flips
  /// are applied so the player can see the final lever positions.
  List<Lever> _animatedLevers(CascadeState state) {
    final result = state.dropResult;

    // During configuring or loading, show levers as-is.
    if (result == null ||
        state.status == CascadeStatus.configuring ||
        state.status == CascadeStatus.loading) {
      return state.board.levers.toList();
    }

    // Start from the pre-drop lever state and replay flips.
    final levers = state.board.levers
        .map((l) => Lever(row: l.row, col: l.col, direction: l.direction))
        .toList();

    final showAll = state.status == CascadeStatus.won ||
        state.status == CascadeStatus.failed;

    for (var i = 0; i < result.paths.length; i++) {
      final path = result.paths[i];
      if (!showAll && i > _currentBallIndex) break;

      for (final flip in path.leverFlips) {
        // Apply flip if showing final state, or if the step has
        // been reached in the current ball's animation.
        if (showAll ||
            i < _currentBallIndex ||
            flip.step <= _currentProgress.floor()) {
          levers[flip.leverIndex] = levers[flip.leverIndex].flip();
        }
      }
    }

    return levers;
  }

  List<Widget> _buildLevers(
    CascadeState state,
    double cellSize,
  ) {
    final isConfiguring =
        state.status == CascadeStatus.configuring;
    final levers = _animatedLevers(state);

    return List.generate(levers.length, (index) {
      final lever = levers[index];
      return Positioned(
        left: lever.col * cellSize,
        top: lever.row * cellSize,
        child: LeverWidget(
          lever: lever,
          cellSize: cellSize,
          enabled: isConfiguring,
          onTap: () =>
              context.read<CascadeCubit>().flipLever(index),
        ),
      );
    });
  }

  List<Widget> _buildBins(
    CascadeState state,
    double cellSize,
  ) {
    return List.generate(3, (binIndex) {
      final col = CascadeBoard.binColumns[binIndex];
      final expectedBallIndex = state.board.binOrder[binIndex];
      final expectedBall = BallId.values[expectedBallIndex];

      // Bin border stays neutral — the balls and target labels
      // are enough to show correctness.

      return Positioned(
        left: col * cellSize,
        top: CascadeBoard.rows * cellSize,
        child: BinWidget(
          expectedBallId: expectedBall,
          cellSize: cellSize,
        ),
      );
    });
  }

  /// Interpolates a ball's pixel position between two path steps.
  ///
  /// For horizontal segments (lever deflection), adds a parabolic
  /// arc so the ball appears to bounce off the lever — rising
  /// slightly before gravity brings it back down.
  ///
  /// For wall-bounce segments, the ball moves toward the wall edge
  /// and bounces back with an arc.
  Offset _interpolatedPosition(
    BallPath path,
    double progress,
    double cellSize,
  ) {
    final maxIndex = path.positions.length - 1;
    final clampedProgress = progress.clamp(0.0, maxIndex.toDouble());
    final fromIndex = clampedProgress.floor().clamp(0, maxIndex);
    final toIndex = (fromIndex + 1).clamp(0, maxIndex);
    final t = clampedProgress - fromIndex;

    final from = path.positions[fromIndex];
    final to = path.positions[toIndex];

    final ballSize = cellSize * _ballScale;
    final centering = (cellSize - ballSize) / 2;

    var x = (from.col + (to.col - from.col) * t) * cellSize + centering;

    // For the final segment (entering the bin row), transition the
    // vertical offset from centered to bottom-aligned so the ball
    // settles at the bottom of the bin cell. Also bottom-align when
    // sitting at the bin row after completing the transition.
    final bottomAlign = cellSize - ballSize;
    final isAtBinRow = from.row == CascadeBoard.rows;
    final isEnteringBinRow = !isAtBinRow && to.row == CascadeBoard.rows;
    final double yOffset;
    if (isAtBinRow) {
      yOffset = bottomAlign;
    } else if (isEnteringBinRow) {
      yOffset = centering + (bottomAlign - centering) * t;
    } else {
      yOffset = centering;
    }
    var y = (from.row + (to.row - from.row) * t) * cellSize + yOffset;

    // Wall bounce: two segments where the ball moves toward the
    // wall edge and bounces back. The wall direction is determined
    // by which edge the ball's column is nearest.
    final isOutwardBounce = path.wallBounces.contains(fromIndex);
    final isReturnBounce = path.wallBounces.contains(fromIndex - 1);

    if (isOutwardBounce || isReturnBounce) {
      // Determine wall direction: left wall (col 0) or right wall.
      final col = from.col;
      final wallIsLeft = col == 0;

      // How far toward the wall edge the ball travels (half a cell).
      final edgeOffset = cellSize * 0.5;

      if (isOutwardBounce) {
        // Moving toward wall: 0 → edgeOffset.
        final displacement = t * edgeOffset;
        x += wallIsLeft ? -displacement : displacement;
      } else {
        // Returning from wall: edgeOffset → 0.
        final displacement = (1 - t) * edgeOffset;
        x += wallIsLeft ? -displacement : displacement;
      }

      // Arc upward across both segments. Treat outward as t=0→0.5
      // and return as t=0.5→1 of a single parabola.
      final combinedT = isOutwardBounce ? t * 0.5 : 0.5 + t * 0.5;
      final arc = -4 * combinedT * (combinedT - 1);
      y -= arc * cellSize * 0.2;
    } else {
      // Normal horizontal deflection arc.
      final isHorizontal = from.row == to.row && from.col != to.col;
      if (isHorizontal) {
        final arc = -4 * t * (t - 1);
        y -= arc * cellSize * 0.2;
      }
    }

    return Offset(x, y);
  }

  /// Returns a horizontal pixel nudge for a landed ball so that
  /// overlapping balls in the same bin are all partially visible.
  ///
  /// The last ball to land at a bin stays centered (in front).
  /// Earlier balls shift: the first displaced ball moves right,
  /// the second displaced ball moves left.
  double _landedXNudge(
    DropResult result,
    int ballIndex,
    int landedCount,
  ) {
    final myBin = result.paths[ballIndex].finalBin;
    // Count how many later landed balls share this bin.
    var laterCount = 0;
    for (var i = ballIndex + 1; i < landedCount; i++) {
      if (result.paths[i].finalBin == myBin) laterCount++;
    }
    return switch (laterCount) {
      1 => 10,
      2 => -10,
      _ => 0,
    };
  }

  List<Widget> _buildAnimatedBalls(
    CascadeState state,
    double cellSize,
  ) {
    final result = state.dropResult;
    if (result == null) return [];

    final ballSize = cellSize * _ballScale;
    final widgets = <Widget>[];

    for (var i = 0; i < result.paths.length; i++) {
      final path = result.paths[i];

      if (i > _currentBallIndex) break;

      // Completed balls sit at their final position.
      // The current ball interpolates smoothly.
      final progress = i < _currentBallIndex
          ? (path.positions.length - 1).toDouble()
          : _currentProgress;

      final pos = _interpolatedPosition(path, progress, cellSize);
      // Nudge completed balls that share a bin with a later landed ball.
      final nudge = i < _currentBallIndex
          ? _landedXNudge(result, i, _currentBallIndex)
          : 0.0;
      widgets.add(
        Positioned(
          left: pos.dx + nudge,
          top: pos.dy,
          child: BallWidget(ballId: path.ballId, size: ballSize),
        ),
      );
    }

    return widgets;
  }

  /// Renders balls at their final bin positions after the drop.
  /// Bottom-aligned so the ball rests at the bottom of the bin cell.
  List<Widget> _buildLandedBalls(
    CascadeState state,
    double cellSize,
  ) {
    final result = state.dropResult;
    if (result == null) return [];

    final ballSize = cellSize * _ballScale;
    final xOffset = (cellSize - ballSize) / 2;
    final yOffset = cellSize - ballSize;

    return List.generate(result.paths.length, (i) {
      final path = result.paths[i];
      final pos = path.positions.last;
      final nudge = _landedXNudge(result, i, result.paths.length);
      return Positioned(
        left: pos.col * cellSize + xOffset + nudge,
        top: pos.row * cellSize + yOffset,
        child: BallWidget(ballId: path.ballId, size: ballSize),
      );
    });
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.cellSize});

  final double cellSize;

  static const _edgeColor = Color(0xFFD0D0D0);
  static const _slotColor = Color(0xFFEEEEEE);

  @override
  void paint(Canvas canvas, Size size) {
    // Top row: dark gray for edge columns, light gray for slots.
    for (var col = 0; col < CascadeBoard.columns; col++) {
      final isSlot = CascadeBoard.dropSlotColumns.contains(col);
      final paint = Paint()..color = isSlot ? _slotColor : _edgeColor;
      canvas.drawRect(
        Rect.fromLTWH(col * cellSize, 0, cellSize, cellSize),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      cellSize != oldDelegate.cellSize;
}
