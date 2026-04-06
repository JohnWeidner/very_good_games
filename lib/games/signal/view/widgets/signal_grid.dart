import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:very_good_games/games/signal/cubit/signal_cubit.dart';
import 'package:very_good_games/games/signal/models/models.dart';
import 'package:very_good_games/games/signal/view/widgets/signal_cell.dart';

/// The interactive grid widget for the Signal puzzle.
///
/// Renders cells with signal path visualization and handles tap gestures.
class SignalGrid extends StatelessWidget {
  /// Creates a [SignalGrid].
  const SignalGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SignalCubit, SignalState>(
      builder: (context, state) {
        final grid = state.grid;
        final signaledCells = state.signaledCells;

        return AspectRatio(
          aspectRatio: 1,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: grid.size,
            ),
            itemCount: grid.size * grid.size,
            itemBuilder: (context, index) {
              final row = index ~/ grid.size;
              final col = index % grid.size;
              final cell = grid.cellAt(row, col);
              final isSignaled = signaledCells.contains((row, col));

              int? signalCount;
              if (cell is Tower) {
                signalCount = state.towerSignals[(row, col)];
              }

              return GestureDetector(
                onTap: () => context.read<SignalCubit>().toggleCell(row, col),
                child: SignalCell(
                  cell: cell,
                  signalCount: signalCount,
                  isSignaled: isSignaled,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
