import 'package:flutter/material.dart';

/// A row of 0–9 buttons for picking a single digit.
class DigitPicker extends StatelessWidget {
  /// Creates a [DigitPicker].
  const DigitPicker({
    required this.onDigitSelected,
    this.selectedDigit,
    super.key,
  });

  /// Called when the player taps a digit.
  final ValueChanged<int> onDigitSelected;

  /// The currently selected digit, if any.
  final int? selectedDigit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: List.generate(10, (digit) {
        final isSelected = digit == selectedDigit;
        return SizedBox(
          width: 40,
          height: 40,
          child: Material(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => onDigitSelected(digit),
              child: Center(
                child: Text(
                  '$digit',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
