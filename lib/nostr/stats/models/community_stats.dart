import 'package:equatable/equatable.dart';

/// Aggregate community stats for a daily game.
class CommunityStats extends Equatable {
  /// Creates [CommunityStats].
  const CommunityStats({required this.playerCount, required this.avgStars});

  /// Number of unique players who shared results.
  final int playerCount;

  /// Average star rating across all players.
  final double avgStars;

  @override
  List<Object> get props => [playerCount, avgStars];
}
