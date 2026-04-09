import 'dart:math' as math;

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

  /// Per-ball eased progress through positions.
  /// -1 means not started, >= 0 means animating or completed.
  List<double> _ballProgress = const [-1, -1, -1];

  @override
  void dispose() {
    _dropController?.dispose();
    super.dispose();
  }

  void _startDropAnimation(CascadeState state) {
    final result = state.dropResult;
    if (result == null) return;

    _ballProgress = [-1, -1, -1];

    // Each ball's total segment count.
    final segCounts = result.paths
        .map((p) => p.positions.length - 1)
        .toList();

    // Ball N+1 starts when ball N reaches the bin. We need to
    // find the *linear* time fraction at which _gravityEase
    // output reaches binBounceStart / totalSegments for each ball,
    // then convert that to a segment-count offset.
    final ballStartSegments = <double>[0]; // Ball 0 starts at 0.

    for (var i = 0; i < result.paths.length - 1; i++) {
      final segs = segCounts[i];
      final bounceStart = result.paths[i].binBounceStart ?? segs;
      final targetFraction = bounceStart / segs;

      // Binary search for the linear t where
      // _gravityEase(t) >= targetFraction.
      var lo = 0.0;
      var hi = 1.0;
      for (var iter = 0; iter < 50; iter++) {
        final mid = (lo + hi) / 2;
        final eased = _gravityEase(mid, result.paths[i], segs);
        if (eased < targetFraction) {
          lo = mid;
        } else {
          hi = mid;
        }
      }
      // Convert linear time fraction to segment units.
      final linearSegsToReachBin = hi * segs;
      ballStartSegments.add(
        ballStartSegments.last + linearSegsToReachBin,
      );
    }

    // Total timeline = last ball's start + its full segment count.
    final totalGlobalSegments =
        ballStartSegments.last + segCounts.last;

    _dropController?.dispose();
    _dropController = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: totalGlobalSegments.round() * 120,
      ),
    );

    _dropController!.addListener(() {
      if (!mounted) return;
      final globalProgress =
          _dropController!.value * totalGlobalSegments;

      final newProgress = <double>[];
      for (var i = 0; i < result.paths.length; i++) {
        final segs = segCounts[i];
        final start = ballStartSegments[i];
        final localLinear = globalProgress - start;

        if (localLinear < 0) {
          newProgress.add(-1);
        } else {
          final ballT = (localLinear / segs).clamp(0, 1);
          final eased = _gravityEase(
            ballT.toDouble(),
            result.paths[i],
            segs,
          );
          newProgress.add(eased * segs);
        }
      }

      setState(() => _ballProgress = newProgress);
    });

    _dropController!.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        context.read<CascadeCubit>().completeDrop();
      }
    });

    _dropController!.forward();
  }

  /// Maps linear time (0-1) to eased position (0-1) for a ball,
  /// simulating gravity with velocity halving at lever hits.
  double _gravityEase(double t, BallPath path, int totalSegments) {
    if (totalSegments == 0) return 0;

    final hitFractions = path.leverFlips
        .map((f) => f.step / totalSegments)
        .where((f) => f > 0 && f < 1)
        .toList()
      ..sort();

    final boundaries = [0.0, ...hitFractions, 1.0];

    var velocity = 0.0;
    const gravity = 2.0;
    final segmentLengths = <double>[];
    final entryVelocities = <double>[];

    for (var i = 0; i < boundaries.length - 1; i++) {
      final length = boundaries[i + 1] - boundaries[i];
      segmentLengths.add(length);
      entryVelocities.add(velocity);

      final dur = _solveQuadraticTime(velocity, gravity, length);
      velocity = velocity + gravity * dur;

      if (i < boundaries.length - 2) {
        velocity *= 0.125;
      }
    }

    velocity = 0.0;
    final timeBoundaries = [0.0];
    for (var i = 0; i < segmentLengths.length; i++) {
      final dur = _solveQuadraticTime(
        velocity,
        gravity,
        segmentLengths[i],
      );
      timeBoundaries.add(timeBoundaries.last + dur);
      velocity = velocity + gravity * dur;
      if (i < segmentLengths.length - 1) {
        velocity *= 0.125;
      }
    }

    final totalTime = timeBoundaries.last;
    if (totalTime == 0) return t;

    final physicsTime = t * totalTime;

    var segIndex = 0;
    for (var i = 0; i < timeBoundaries.length - 1; i++) {
      if (physicsTime < timeBoundaries[i + 1] ||
          i == timeBoundaries.length - 2) {
        segIndex = i;
        break;
      }
    }

    final segStart = timeBoundaries[segIndex];
    final dt = physicsTime - segStart;
    final v0 = entryVelocities[segIndex];
    final posInSegment = v0 * dt + 0.5 * gravity * dt * dt;
    final posStart = boundaries[segIndex];

    return (posStart + posInSegment).clamp(0, 1);
  }

  /// Solves v0*t + 0.5*g*t^2 = distance for t >= 0.
  static double _solveQuadraticTime(
    double v0,
    double g,
    double distance,
  ) {
    if (distance <= 0) return 0;
    if (g == 0) return v0 > 0 ? distance / v0 : double.infinity;
    final a = 0.5 * g;
    final discriminant = v0 * v0 + 4 * a * distance;
    if (discriminant < 0) return 0;
    return (-v0 + _sqrt(discriminant)) / (2 * a);
  }

  static double _sqrt(double x) =>
      x <= 0 ? 0 : math.sqrt(x);

  /// Whether ball [i] has reached the bin (started bouncing or
  /// finished). Used to determine when later balls count as
  /// "landed" for nudge calculations.
  bool _ballHasLanded(DropResult result, int i) {
    if (_ballProgress[i] < 0) return false;
    final bounceStart = result.paths[i].binBounceStart;
    if (bounceStart == null) return false;
    return _ballProgress[i] >= bounceStart;
  }

  /// Count of balls that have reached their bin during animation.
  int _landedCount(DropResult result) {
    var count = 0;
    for (var i = 0; i < result.paths.length; i++) {
      if (_ballHasLanded(result, i)) count++;
    }
    return count;
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
            final cellSize =
                constraints.maxWidth / CascadeBoard.columns;
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
                    _buildGrid(cellSize),
                    ..._buildDropSlots(state, cellSize),
                    ..._buildLevers(state, cellSize),
                    ..._buildBins(state, cellSize),
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
      painter: _SlotBackgroundPainter(cellSize: cellSize),
    );
  }

  /// Whether a slot ball should be visible. During configuring,
  /// always visible. During dropping, visible only until its ball
  /// starts animating. Hidden during won/failed.
  bool _shouldShowSlotBall(CascadeState state, BallId ball) {
    if (state.status == CascadeStatus.configuring) return true;
    if (state.status != CascadeStatus.dropping) return false;
    return _ballProgress[ball.index] < 0;
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

            final ballHasDropped = assignedBall != null &&
                !_shouldShowSlotBall(state, assignedBall);
            const slotBorder =
                BorderSide(color: CascadeColors.gridLine);

            return Container(
              width: cellSize,
              height: cellSize,
              decoration: isHighlighted
                  ? BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      border: Border.all(
                        color: Colors.blue.shade300,
                      ),
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
              child: _buildSlotChild(
                assignedBall: assignedBall,
                state: state,
                isConfiguring: isConfiguring,
                cellSize: cellSize,
              ),
            );
          },
        ),
      );
    });
  }

  Widget _buildSlotChild({
    required BallId? assignedBall,
    required CascadeState state,
    required bool isConfiguring,
    required double cellSize,
  }) {
    if (assignedBall == null ||
        !_shouldShowSlotBall(state, assignedBall)) {
      return Center(
        child: Icon(
          Icons.arrow_downward,
          color: CascadeColors.gridLine,
          size: cellSize * 0.4,
        ),
      );
    }

    if (!isConfiguring) {
      return Center(
        child: BallWidget(
          ballId: assignedBall,
          size: cellSize * _ballScale,
        ),
      );
    }

    return Draggable<BallId>(
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
    );
  }

  /// Computes lever directions based on animation progress.
  List<Lever> _animatedLevers(CascadeState state) {
    final result = state.dropResult;

    if (result == null ||
        state.status == CascadeStatus.configuring ||
        state.status == CascadeStatus.loading) {
      return state.board.levers.toList();
    }

    final levers = state.board.levers
        .map(
          (l) =>
              Lever(row: l.row, col: l.col, direction: l.direction),
        )
        .toList();

    final showAll = state.status == CascadeStatus.won ||
        state.status == CascadeStatus.failed;

    for (var i = 0; i < result.paths.length; i++) {
      final path = result.paths[i];
      final progress = _ballProgress[i];

      // Skip balls that haven't started.
      if (!showAll && progress < 0) continue;

      for (final flip in path.leverFlips) {
        if (showAll || flip.step <= progress.floor()) {
          levers[flip.leverIndex] =
              levers[flip.leverIndex].flip();
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
  Offset _interpolatedPosition(
    BallPath path,
    double progress,
    double cellSize,
  ) {
    final maxIndex = path.positions.length - 1;
    final clampedProgress =
        progress.clamp(0.0, maxIndex.toDouble());
    final fromIndex = clampedProgress.floor().clamp(0, maxIndex);
    final toIndex = (fromIndex + 1).clamp(0, maxIndex);
    final t = clampedProgress - fromIndex;

    final from = path.positions[fromIndex];
    final to = path.positions[toIndex];

    final ballSize = cellSize * _ballScale;
    final centering = (cellSize - ballSize) / 2;

    var x =
        (from.col + (to.col - from.col) * t) * cellSize + centering;

    final bottomAlign = cellSize - ballSize;
    final isAtBinRow = from.row == CascadeBoard.rows;
    final isEnteringBinRow =
        !isAtBinRow && to.row == CascadeBoard.rows;
    final double yOffset;
    if (isAtBinRow) {
      yOffset = bottomAlign;
    } else if (isEnteringBinRow) {
      yOffset = centering + (bottomAlign - centering) * t;
    } else {
      yOffset = centering;
    }
    var y =
        (from.row + (to.row - from.row) * t) * cellSize + yOffset;

    // Bin bounce.
    final bounceStart = path.binBounceStart;
    if (bounceStart != null && fromIndex >= bounceStart) {
      final bounceSegIndex = fromIndex - bounceStart;
      final bounceNumber = bounceSegIndex ~/ 2;
      final isUpSegment = bounceSegIndex.isEven;

      final baseHeight = cellSize * 0.85;
      final height = baseHeight * math.pow(0.25, bounceNumber);

      final combinedT =
          isUpSegment ? t * 0.5 : 0.5 + t * 0.5;
      final arc = -4 * combinedT * (combinedT - 1);
      y -= arc * height;
      return Offset(x, y);
    }

    // Wall bounce.
    final isOutwardBounce = path.wallBounces.contains(fromIndex);
    final isReturnBounce =
        path.wallBounces.contains(fromIndex - 1);

    if (isOutwardBounce || isReturnBounce) {
      final col = from.col;
      final wallIsLeft = col == 0;
      final edgeOffset = cellSize * 0.5;

      if (isOutwardBounce) {
        final displacement = t * edgeOffset;
        x += wallIsLeft ? -displacement : displacement;
      } else {
        final displacement = (1 - t) * edgeOffset;
        x += wallIsLeft ? -displacement : displacement;
      }

      final combinedT =
          isOutwardBounce ? t * 0.5 : 0.5 + t * 0.5;
      final arc = -4 * combinedT * (combinedT - 1);
      y -= arc * cellSize * 0.1;
    } else {
      final isHorizontal =
          from.row == to.row && from.col != to.col;

      // Check if we're in the downward segment right after a
      // horizontal deflection.
      final isPrevHorizontal = fromIndex > 0 &&
          path.positions[fromIndex - 1].row == from.row &&
          path.positions[fromIndex - 1].col != from.col &&
          !isHorizontal;

      if (isHorizontal || isPrevHorizontal) {
        // Spread horizontal movement and vertical arc across
        // both the deflection segment and the following drop
        // segment. combinedT goes 0→1 across both segments.
        final double combinedT;
        int deflectFromCol;
        int deflectToCol;

        if (isHorizontal) {
          combinedT = t * 0.5; // First half of the arc.
          deflectFromCol = from.col;
          deflectToCol = to.col;
        } else {
          combinedT = 0.5 + t * 0.5; // Second half.
          deflectFromCol = path.positions[fromIndex - 1].col;
          deflectToCol = from.col;
        }

        // Horizontal: ease-out across the full arc so velocity
        // reaches zero by the end.
        final easedH = Curves.easeOut.transform(combinedT);
        x = (deflectFromCol +
                    (deflectToCol - deflectFromCol) * easedH) *
                cellSize +
            centering;

        // Vertical arc: decelerate up, accelerate down.
        final double arcT;
        if (combinedT <= 0.5) {
          arcT = Curves.easeOut.transform(combinedT * 2) * 0.5;
        } else {
          arcT = 0.5 +
              Curves.easeIn.transform(
                    (combinedT - 0.5) * 2,
                  ) *
                  0.5;
        }
        final arc = -4 * arcT * (arcT - 1);
        y -= arc * cellSize * 0.1;
      }
    }

    return Offset(x, y);
  }

  /// Horizontal nudge for overlapping balls in the same bin.
  double _landedXNudge(
    DropResult result,
    int ballIndex,
    int landedCount,
  ) {
    final myBin = result.paths[ballIndex].finalBin;
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
    final landed = _landedCount(result);

    for (var i = 0; i < result.paths.length; i++) {
      final progress = _ballProgress[i];
      if (progress < 0) continue; // Not started yet.

      final path = result.paths[i];
      final pos =
          _interpolatedPosition(path, progress, cellSize);

      final nudge =
          _ballHasLanded(result, i)
              ? _landedXNudge(result, i, landed)
              : 0.0;

      widgets.add(
        Positioned(
          left: pos.dx + nudge,
          top: pos.dy,
          child: BallWidget(
            ballId: path.ballId,
            size: ballSize,
          ),
        ),
      );
    }

    return widgets;
  }

  /// Renders balls at their final bin positions after the drop.
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
      final nudge =
          _landedXNudge(result, i, result.paths.length);
      return Positioned(
        left: pos.col * cellSize + xOffset + nudge,
        top: pos.row * cellSize + yOffset,
        child: BallWidget(
          ballId: path.ballId,
          size: ballSize,
        ),
      );
    });
  }
}

class _SlotBackgroundPainter extends CustomPainter {
  _SlotBackgroundPainter({required this.cellSize});

  final double cellSize;

  @override
  void paint(Canvas canvas, Size size) {
    for (var col = 0; col < CascadeBoard.columns; col++) {
      final isSlot = CascadeBoard.dropSlotColumns.contains(col);
      final paint = Paint()
        ..color =
            isSlot ? CascadeColors.slotCenter : CascadeColors.slotEdge;
      canvas.drawRect(
        Rect.fromLTWH(col * cellSize, 0, cellSize, cellSize),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SlotBackgroundPainter oldDelegate) =>
      cellSize != oldDelegate.cellSize;
}
