import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:very_good_games/core/storage/streak_data.dart';

/// Repository for persisting game-related data (streaks, completion status).
///
/// Wraps [SharedPreferences] so consumers depend on an interface,
/// not the storage implementation directly.
class GameStorageRepository {
  /// Creates a [GameStorageRepository] backed by [SharedPreferences].
  GameStorageRepository({required SharedPreferences preferences})
    : _preferences = preferences;

  final SharedPreferences _preferences;

  static const _currentStreakSuffix = '_current_streak';
  static const _bestStreakSuffix = '_best_streak';
  static const _lastCompletedSuffix = '_last_completed';
  static const _sessionSuffix = '_session';

  /// Loads the [StreakData] for the game with [gameId].
  StreakData getStreak(String gameId) {
    final current = _preferences.getInt('$gameId$_currentStreakSuffix') ?? 0;
    final best = _preferences.getInt('$gameId$_bestStreakSuffix') ?? 0;
    final lastCompletedMs = _preferences.getInt('$gameId$_lastCompletedSuffix');

    return StreakData(
      currentStreak: current,
      bestStreak: best,
      lastCompletedDate: lastCompletedMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastCompletedMs, isUtc: true)
          : null,
    );
  }

  /// Persists the [StreakData] for the game with [gameId].
  Future<void> saveStreak(String gameId, StreakData data) async {
    await Future.wait([
      _preferences.setInt('$gameId$_currentStreakSuffix', data.currentStreak),
      _preferences.setInt('$gameId$_bestStreakSuffix', data.bestStreak),
      if (data.lastCompletedDate != null)
        _preferences.setInt(
          '$gameId$_lastCompletedSuffix',
          data.lastCompletedDate!.millisecondsSinceEpoch,
        ),
    ]);
  }

  /// Saves an in-progress game session as JSON.
  ///
  /// The [session] map should contain all fields needed to restore game
  /// state. Pass `null` to clear the saved session (e.g. after game ends).
  Future<void> saveSession(String gameId, Map<String, dynamic>? session) async {
    final key = '$gameId$_sessionSuffix';
    if (session == null) {
      await _preferences.remove(key);
    } else {
      await _preferences.setString(key, jsonEncode(session));
    }
  }

  /// Loads a previously saved game session, or `null` if none exists.
  Map<String, dynamic>? getSession(String gameId) {
    final raw = _preferences.getString('$gameId$_sessionSuffix');
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}
