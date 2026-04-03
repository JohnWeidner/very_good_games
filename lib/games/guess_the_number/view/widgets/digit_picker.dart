import 'package:flutter/material.dart';

/// A row of buttons for picking a numeric value.
///
/// Defaults to digits 0–9. Pass [values] to override with custom options
/// (e.g., prime divisors).
class DigitPicker extends StatelessWidget {
  /// Creates a [DigitPicker].
  const DigitPicker({
    required this.onDigitSelected,
    this.selectedDigit,
    this.values,
    super.key,
  });

  /// Called when the player taps a value.
  final ValueChanged<int> onDigitSelected;

  /// The currently selected value, if any.
  final int? selectedDigit;

  /// The values to display. Defaults to 0–9 if `null`.
  final List<int>? values;

  static const _defaultValues = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pickValues = values ?? _defaultValues;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (final value in pickValues)
          _PickerButton(
            value: value,
            isSelected: value == selectedDigit,
            theme: theme,
            onTap: () => onDigitSelected(value),
          ),
      ],
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.value,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  final int value;
  final bool isSelected;
  final ThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
          onTap: onTap,
          child: Center(
            child: Text(
              '$value',
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
  }
}
