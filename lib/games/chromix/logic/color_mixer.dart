import 'package:very_good_games/games/chromix/models/chromix_color.dart';

/// RYB subtractive mixing rules for Chromix.
///
/// Only two distinct primaries can be mixed to produce a secondary.
/// Returns `null` for invalid combinations (same color, secondary inputs).
class ColorMixer {
  /// Whether [primary] is a component of [secondary].
  ///
  /// For example, Red is a component of Orange (Red + Yellow) and
  /// Purple (Red + Blue).
  ///
  /// Returns `false` if [primary] is not actually primary or [secondary]
  /// is not actually secondary.
  static bool isComponentOf(ChromixColor primary, ChromixColor secondary) {
    if (!primary.isPrimary || !secondary.isSecondary) return false;
    return ChromixColor.values
        .where((c) => c.isPrimary)
        .any((other) => other != primary && mix(primary, other) == secondary);
  }

  /// Mixes two colors using RYB rules.
  ///
  /// - red + yellow → orange
  /// - red + blue → purple
  /// - yellow + blue → green
  ///
  /// Returns `null` if either color is secondary, or if both are the same.
  static ChromixColor? mix(ChromixColor a, ChromixColor b) {
    if (a == b) return null;
    if (a.isSecondary || b.isSecondary) return null;

    final pair = {a, b};
    if (pair.contains(ChromixColor.red) && pair.contains(ChromixColor.yellow)) {
      return ChromixColor.orange;
    }
    if (pair.contains(ChromixColor.red) && pair.contains(ChromixColor.blue)) {
      return ChromixColor.purple;
    }
    if (pair.contains(ChromixColor.yellow) &&
        pair.contains(ChromixColor.blue)) {
      return ChromixColor.green;
    }

    return null;
  }
}
