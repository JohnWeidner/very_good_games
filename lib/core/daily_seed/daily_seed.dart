/// Generates deterministic daily seeds from UTC dates.
///
/// All players get the same seed for the same calendar day (UTC).
class DailySeed {
  /// Returns the seed for today (UTC).
  static int today() => forDate(DateTime.now().toUtc());

  /// Returns a deterministic seed for a given [date].
  ///
  /// Uses only year, month, day — ignores time components.
  /// The seed is stable across Dart versions and isolates.
  static int forDate(DateTime date) {
    final utc = date.toUtc();
    return _djb2Hash('${utc.year}-${utc.month}-${utc.day}');
  }

  /// DJB2 hash — deterministic, stable across Dart runtimes.
  static int _djb2Hash(String input) {
    var hash = 5381;
    for (var i = 0; i < input.length; i++) {
      hash = ((hash << 5) + hash) + input.codeUnitAt(i);
      // Keep within 32-bit signed integer range.
      hash &= 0x7FFFFFFF;
    }
    return hash;
  }
}
