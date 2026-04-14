import 'package:equatable/equatable.dart';

/// Aggregate community stats for a daily game.
class CommunityStats extends Equatable {
  /// Creates [CommunityStats].
  const CommunityStats({
    required this.playerCount,
    required this.avgScore,
    this.avgTime,
  });

  /// Number of unique players who shared results.
  final int playerCount;

  /// Average star rating across all players.
  final double avgScore;

  /// Average completion time in seconds, or null if no time data.
  final double? avgTime;

  @override
  List<Object?> get props => [playerCount, avgScore, avgTime];
}
