import 'package:flutter/material.dart';
import 'package:very_good_games/games/cascade/models/models.dart';
import 'package:very_good_games/games/cascade/theme/theme.dart';

/// Resting rotation for a left-pointing lever (in turns).
const _leftTurns = -0.125;

/// Resting rotation for a right-pointing lever (in turns).
const _rightTurns = 0.125;

/// Extra rotation on impact before springing to the new position.
const _impactOvershoot = 0.06;

/// A single toggle lever with an impact animation.
///
/// When the direction changes (a ball hits it), the lever first
/// rotates slightly further in the impact direction (the ball
/// pushes the lower side down), then springs to its new resting
/// position.
class LeverWidget extends StatefulWidget {
  /// Creates a [LeverWidget].
  const LeverWidget({
    required this.lever,
    required this.onTap,
    required this.cellSize,
    this.enabled = true,
    super.key,
  });

  /// The lever to display.
  final Lever lever;

  /// Called when the lever is tapped.
  final VoidCallback onTap;

  /// Size of the grid cell.
  final double cellSize;

  /// Whether tapping is enabled.
  final bool enabled;

  @override
  State<LeverWidget> createState() => _LeverWidgetState();
}

class _LeverWidgetState extends State<LeverWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _rotation = AlwaysStoppedAnimation(_restingTurns);
  }

  double get _restingTurns =>
      widget.lever.direction == LeverDirection.left ? _leftTurns : _rightTurns;

  @override
  void didUpdateWidget(LeverWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.lever.direction != widget.lever.direction) {
      _triggerImpactAnimation(oldWidget.lever.direction);
    }
  }

  void _triggerImpactAnimation(LeverDirection oldDirection) {
    final oldTurns = oldDirection == LeverDirection.left
        ? _leftTurns
        : _rightTurns;
    final newTurns = _restingTurns;

    // Impact direction: the ball hits the lower side, pushing it
    // further down. If left side was lower (pointing left), the
    // ball pushes counterclockwise (more negative). If right side
    // was lower (pointing right), the ball pushes clockwise (more
    // positive).
    final impactTurns = oldDirection == LeverDirection.left
        ? oldTurns - _impactOvershoot
        : oldTurns + _impactOvershoot;

    _controller.reset();
    _rotation = TweenSequence<double>([
      // Phase 1: impact push (quick, 20% of duration).
      TweenSequenceItem(
        tween: Tween(
          begin: oldTurns,
          end: impactTurns,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 20,
      ),
      // Phase 2: spring to new resting position (80% of duration).
      TweenSequenceItem(
        tween: Tween(
          begin: impactTurns,
          end: newTurns,
        ).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 80,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTap : null,
      child: SizedBox(
        width: widget.cellSize,
        height: widget.cellSize,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return RotationTransition(
                turns: _controller.isAnimating
                    ? _rotation
                    : AlwaysStoppedAnimation(_restingTurns),
                child: child,
              );
            },
            child: SizedBox(
              width: widget.cellSize * 0.43,
              height: widget.cellSize * 0.1,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  // Lever bar.
                  Container(
                    decoration: BoxDecoration(
                      color: CascadeColors.lever,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Pivot circle at center.
                  Container(
                    width: widget.cellSize * 0.18,
                    height: widget.cellSize * 0.18,
                    decoration: BoxDecoration(
                      color: CascadeColors.leverActive,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
