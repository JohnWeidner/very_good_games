import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

/// Manages the win celebration sequence: a pause to admire the solved
/// puzzle, then confetti, then a callback to show results.
///
/// Usage: call [trigger] when the game is won. The widget displays
/// confetti over its child. Call [reset] when starting a new game.
class WinCelebration extends StatefulWidget {
  /// Creates a [WinCelebration].
  const WinCelebration({
    required this.child,
    super.key,
  });

  /// The content to display (the game board / stack).
  final Widget child;

  /// Triggers the celebration sequence from an ancestor.
  static WinCelebrationState? of(BuildContext context) =>
      context.findAncestorStateOfType<WinCelebrationState>();

  @override
  State<WinCelebration> createState() => WinCelebrationState();
}

/// State for [WinCelebration], exposed so pages can call
/// [trigger] and [reset].
class WinCelebrationState extends State<WinCelebration> {
  bool _showConfetti = false;
  late final ConfettiController _confettiController;
  Timer? _confettiTimer;
  Timer? _resultsTimer;
  VoidCallback? _onShowResults;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _confettiTimer?.cancel();
    _resultsTimer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  /// Starts the celebration: 200ms pause → confetti → 1.2s → [onShowResults].
  void trigger({required VoidCallback onShowResults}) {
    _onShowResults = onShowResults;

    _confettiTimer = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      setState(() => _showConfetti = true);
      _confettiController.play();

      _resultsTimer = Timer(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        _onShowResults?.call();
      });
    });
  }

  /// Resets the celebration state (e.g. when starting a new puzzle).
  void reset() {
    _confettiTimer?.cancel();
    _resultsTimer?.cancel();
    _confettiController.stop();
    _onShowResults = null;
    setState(() => _showConfetti = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showConfetti)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 30,
              maxBlastForce: 20,
              minBlastForce: 5,
            ),
          ),
      ],
    );
  }
}
