import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:very_good_games/games/chromix/cubit/chromix_cubit.dart';
import 'package:very_good_games/games/chromix/models/models.dart';
import 'package:very_good_games/games/chromix/theme/theme.dart';

/// A horizontal row of 3 primary color buttons for color selection.
class ColorPalette extends StatelessWidget {
  /// Creates a [ColorPalette].
  const ColorPalette({super.key});

  static const _primaries = [
    ChromixColor.red,
    ChromixColor.yellow,
    ChromixColor.blue,
  ];

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ChromixCubit, ChromixState, ChromixColor>(
      selector: (state) => state.selectedColor,
      builder: (context, selectedColor) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final color in _primaries) ...[
              _ColorButton(
                color: color,
                isSelected: color == selectedColor,
                onTap: () =>
                    context.read<ChromixCubit>().selectColor(color),
              ),
              if (color != _primaries.last) const SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }
}

class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final ChromixColor color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fillColor = switch (color) {
      ChromixColor.red => ChromixColors.red,
      ChromixColor.yellow => ChromixColors.yellow,
      ChromixColor.blue => ChromixColors.blue,
      _ => ChromixColors.empty,
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: fillColor,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: ChromixColors.selectedRing,
                  width: 3,
                )
              : null,
        ),
        child: Center(
          child: Text(
            color.name[0].toUpperCase(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
