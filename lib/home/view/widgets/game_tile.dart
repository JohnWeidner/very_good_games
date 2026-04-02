import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:very_good_games/core/core.dart';
import 'package:very_good_games/home/cubit/home_cubit.dart';

/// A card displaying a single game's info, daily status, and streak.
class GameTile extends StatelessWidget {
  /// Creates a [GameTile].
  const GameTile({required this.entry, super.key});

  /// The game entry to display.
  final HomeGameEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompleted = entry.dailyStatus == DailyGameStatus.completed;

    return Card(
      child: ListTile(
        leading: Icon(
          entry.definition.icon,
          size: 36,
          color: isCompleted
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(entry.definition.name),
        subtitle: Text(entry.definition.description),
        trailing: _StatusBadge(
          isCompleted: isCompleted,
          streak: entry.streak.currentStreak,
        ),
        onTap: () => context.go(entry.definition.routePath),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isCompleted, required this.streak});

  final bool isCompleted;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isCompleted ? Icons.check_circle : Icons.circle_outlined,
          color: isCompleted
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
        ),
        if (streak > 0)
          Text(
            '$streak day${streak == 1 ? '' : 's'}',
            style: theme.textTheme.labelSmall,
          ),
      ],
    );
  }
}
