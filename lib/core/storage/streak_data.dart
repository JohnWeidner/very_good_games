import 'package:equatable/equatable.dart';

/// Streak tracking data for a single game.
class StreakData extends Equatable {
  /// Creates a [StreakData] instance.
  const StreakData({
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.lastCompletedDate,
  });

  /// The player's current consecutive-day streak.
  final int currentStreak;

  /// The player's all-time best streak.
  final int bestStreak;

  /// The last UTC date the player completed this game.
  /// Only year/month/day are meaningful.
  final DateTime? lastCompletedDate;

  /// Returns updated [StreakData] after a completion on [today] (UTC).
  StreakData recordCompletion(DateTime today) {
    final todayUtc = DateTime.utc(today.year, today.month, today.day);

    // Already completed today — no change.
    if (lastCompletedDate != null) {
      final last = lastCompletedDate!;
      final lastUtc = DateTime.utc(last.year, last.month, last.day);
      if (lastUtc == todayUtc) return this;
    }

    final yesterday = todayUtc.subtract(const Duration(days: 1));
    final isConsecutive =
        lastCompletedDate != null &&
        DateTime.utc(
              lastCompletedDate!.year,
              lastCompletedDate!.month,
              lastCompletedDate!.day,
            ) ==
            yesterday;

    final newStreak = isConsecutive ? currentStreak + 1 : 1;
    final newBest = newStreak > bestStreak ? newStreak : bestStreak;

    return StreakData(
      currentStreak: newStreak,
      bestStreak: newBest,
      lastCompletedDate: todayUtc,
    );
  }

  @override
  List<Object?> get props => [currentStreak, bestStreak, lastCompletedDate];
}
