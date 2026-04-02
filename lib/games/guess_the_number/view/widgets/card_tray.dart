import 'package:flutter/material.dart';
import 'package:very_good_games/games/guess_the_number/models/models.dart';
import 'package:very_good_games/games/guess_the_number/theme/game_colors.dart';

/// A horizontally scrollable tray of question type cards along
/// the bottom of the screen.
///
/// Used cards appear face-down (grayed out). Tapping an available
/// card stages it for parameter selection.
class CardTray extends StatelessWidget {
  /// Creates a [CardTray].
  const CardTray({required this.usedTypes, required this.onSelect, super.key});

  /// The set of question types already used this game.
  final Set<QuestionType> usedTypes;

  /// Called when the player taps an available card.
  final ValueChanged<QuestionType> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: QuestionType.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final type = QuestionType.values[index];
          final isUsed = usedTypes.contains(type);
          return _TrayCard(
            type: type,
            isUsed: isUsed,
            onTap: isUsed ? null : () => onSelect(type),
          );
        },
      ),
    );
  }
}

class _TrayCard extends StatelessWidget {
  const _TrayCard({required this.type, required this.isUsed, this.onTap});

  final QuestionType type;
  final bool isUsed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryColor = GameColors.forCategory(type.category);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: isUsed ? 0.35 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: SizedBox(
          width: 88,
          child: Card(
            elevation: isUsed ? 0 : 2,
            margin: EdgeInsets.zero,
            color: isUsed ? theme.colorScheme.surfaceContainerHighest : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isUsed
                    ? theme.colorScheme.outline.withValues(alpha: 0.2)
                    : categoryColor.withValues(alpha: 0.6),
              ),
            ),
            clipBehavior: Clip.hardEdge,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    type.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isUsed
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                          : categoryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Flexible(
                    child: Text(
                      type.description,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: isUsed ? 0.3 : 0.6,
                        ),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
