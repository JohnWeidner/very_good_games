/// Formats a UTC date as `YYYY-MM-DD` for use as storage/event keys.
String utcDateKey([DateTime? date]) {
  final d = (date ?? DateTime.now()).toUtc();
  return '${d.year}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
