/// The six colors used in the Chromix puzzle.
///
/// Three primaries (red, yellow, blue) can be mixed pairwise
/// to produce three secondaries (orange, green, purple).
enum ChromixColor {
  /// Primary color.
  red,

  /// Primary color.
  yellow,

  /// Primary color.
  blue,

  /// Secondary color (red + yellow).
  orange,

  /// Secondary color (yellow + blue).
  green,

  /// Secondary color (red + blue).
  purple;

  /// Whether this is a primary color (red, yellow, or blue).
  bool get isPrimary => this == red || this == yellow || this == blue;

  /// Whether this is a secondary color (orange, green, or purple).
  bool get isSecondary => this == orange || this == green || this == purple;
}
