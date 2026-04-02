import 'package:flutter/material.dart';
import 'package:very_good_games/games/guess_the_number/cubit/game_cubit.dart';
import 'package:very_good_games/games/guess_the_number/models/models.dart';
import 'package:very_good_games/games/guess_the_number/theme/game_colors.dart';
import 'package:very_good_games/games/guess_the_number/view/widgets/digit_picker.dart';

/// The staged question card that appears between the grid and tray.
///
/// Shows the operation, parameter slot(s), the currently highlighted
/// number with its status (possible/eliminated), and Play/Cancel buttons.
class QuestionCard extends StatelessWidget {
  /// Creates a [QuestionCard].
  const QuestionCard({
    required this.state,
    required this.onConfirm,
    required this.onCancel,
    this.onDigitSelected,
    super.key,
  });

  /// The current game state.
  final GameState state;

  /// Called when the player taps "Play".
  final VoidCallback onConfirm;

  /// Called when the player taps "Cancel" or swipes down.
  final VoidCallback onCancel;

  /// Called when the player picks a digit (0–9) for digit picker questions.
  final ValueChanged<int>? onDigitSelected;

  @override
  Widget build(BuildContext context) {
    final type = state.activeQuestionType;
    if (type == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final categoryColor = GameColors.forCategory(type.category);

    return Dismissible(
      key: ValueKey(type),
      direction: DismissDirection.down,
      onDismissed: (_) => onCancel(),
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: categoryColor, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Operation name and description.
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      type.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    type.description,
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Parameter slots and highlighted number.
              _buildParamArea(context, type),
              const SizedBox(height: 12),
              // Play and Cancel buttons.
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: state.canConfirm ? onConfirm : null,
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: const Text('Play'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParamArea(BuildContext context, QuestionType type) {
    if (type.paramCount == 0) {
      return const _InstructionText(text: 'Tap Play to ask this question');
    }

    // Digit picker questions (e.g., onesDigitIs).
    if (type.usesDigitPicker) {
      return Column(
        children: [
          DigitPicker(
            selectedDigit: state.firstParam,
            onDigitSelected: (d) => onDigitSelected?.call(d),
          ),
          if (state.firstParam == null) ...[
            const SizedBox(height: 8),
            const _InstructionText(text: 'Pick a digit'),
          ],
        ],
      );
    }

    // Single-param question — grid selection.
    final isActive =
        state.status == GameStatus.selectingParam ||
        state.status == GameStatus.readyToConfirm;
    return _ParamSlotRow(
      slots: [
        _ParamSlot(
          label: 'N',
          value: state.firstParam,
          isActive: isActive,
          highlightedCell: state.highlightedCell,
          cells: state.cells,
        ),
      ],
      instruction: state.firstParam == null
          ? 'Slide on the grid to pick a number'
          : null,
    );
  }

}

class _InstructionText extends StatelessWidget {
  const _InstructionText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: 0.6),
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _ParamSlotRow extends StatelessWidget {
  const _ParamSlotRow({required this.slots, this.instruction});

  final List<_ParamSlot> slots;
  final String? instruction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < slots.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'to',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              slots[i],
            ],
          ],
        ),
        if (instruction != null) ...[
          const SizedBox(height: 8),
          _InstructionText(text: instruction!),
        ],
      ],
    );
  }
}

/// A single parameter slot on the staged card.
///
/// Shows the locked value, or the currently highlighted number
/// with a color indicating whether it's still possible or eliminated.
class _ParamSlot extends StatelessWidget {
  const _ParamSlot({
    required this.label,
    required this.isActive,
    required this.cells,
    this.value,
    this.highlightedCell,
  });

  /// Label for this slot (e.g., 'N').
  final String label;

  /// The locked value, or null if not yet picked.
  final int? value;

  /// Whether this slot is currently accepting input.
  final bool isActive;

  /// Index of the currently highlighted cell on the grid.
  final int? highlightedCell;

  /// Current cell states, used to show if highlighted number
  /// is still possible or already eliminated.
  final List<CellState> cells;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Show the live highlighted number if this slot is active.
    final displayNumber = value ??
        (isActive && highlightedCell != null
            ? GameState.numberForIndex(highlightedCell!)
            : null);

    // Determine the status color for the displayed number.
    final statusColor = _statusColor(displayNumber);

    return Container(
        width: 80,
        height: 56,
        decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.outline.withValues(alpha: 0.3),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (displayNumber != null) ...[
            Text(
              '$displayNumber',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            if (value == null && isActive)
              _StatusIndicator(
                cellState: cells[highlightedCell!],
              ),
          ] else
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(
                  alpha: 0.4,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color? _statusColor(int? number) {
    if (number == null) return null;
    final index = number - 1;
    if (index < 0 || index >= cells.length) return null;
    return switch (cells[index]) {
      CellState.possible => const Color(0xFF2E7D32),
      CellState.eliminated => const Color(0xFF9E9E9E),
      CellState.wrongGuess => const Color(0xFFC62828),
      CellState.target => const Color(0xFFF9A825),
    };
  }
}

/// A small dot indicator showing whether the highlighted number
/// is still a possible answer or has been eliminated.
class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.cellState});

  final CellState cellState;

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (cellState) {
      CellState.possible => (const Color(0xFF4CAF50), 'possible'),
      CellState.eliminated => (const Color(0xFF9E9E9E), 'eliminated'),
      CellState.wrongGuess => (const Color(0xFFE53935), 'guessed'),
      CellState.target => (const Color(0xFFFFD600), 'target'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(fontSize: 9, color: color),
        ),
      ],
    );
  }
}
