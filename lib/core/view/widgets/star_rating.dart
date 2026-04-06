import 'package:flutter/material.dart';

/// A row of 3 star icons showing a 1–3 star rating.
class StarRating extends StatelessWidget {
  /// Creates a [StarRating].
  const StarRating({required this.stars, super.key});

  /// The number of filled stars (1–3).
  final int stars;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            i < stars ? Icons.star : Icons.star_border,
            color: i < stars
                ? Colors.amber
                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
            size: 36,
          ),
      ],
    );
  }
}
