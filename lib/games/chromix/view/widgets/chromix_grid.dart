import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:very_good_games/games/chromix/cubit/chromix_cubit.dart';
import 'package:very_good_games/games/chromix/models/models.dart'
    as models;
import 'package:very_good_games/games/chromix/view/widgets/chromix_cell_widget.dart';

/// A 4x4 grid of [ChromixCellWidget]s.
class ChromixGrid extends StatelessWidget {
  /// Creates a [ChromixGrid].
  const ChromixGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChromixCubit, ChromixState>(
      buildWhen: (prev, curr) => prev.grid != curr.grid,
      builder: (context, state) {
        return AspectRatio(
          aspectRatio: 1,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: models.ChromixGrid.size,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
            itemCount:
                models.ChromixGrid.size * models.ChromixGrid.size,
            itemBuilder: (context, index) {
              final row = index ~/ models.ChromixGrid.size;
              final col = index % models.ChromixGrid.size;
              return ChromixCellWidget(
                cell: state.grid.cellAt(row, col),
                onTap: () => context
                    .read<ChromixCubit>()
                    .placeColor(row, col),
              );
            },
          ),
        );
      },
    );
  }
}
