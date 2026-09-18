class QazaDate {
  const QazaDate._();

  /// Treats DateTime as a calendar date, not an instant in time.
  ///
  /// The year/month/day components are intentionally preserved regardless of
  /// whether the input is local or UTC so date selection cannot move across
  /// a timezone boundary.
  static DateTime normalize(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String key(DateTime value) {
    final date = normalize(value);
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime parseKey(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid Qaza date key: $value');
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      throw FormatException('Invalid Qaza calendar date: $value');
    }
    return date;
  }

  /// Recovers the canonical date from the deterministic Qaza record ID.
  ///
  /// This is also the migration-safe source for legacy Firestore records whose
  /// originalDate was stored as a timezone-sensitive Timestamp.
  static DateTime fromRecordId(String recordId) {
    final match = RegExp(r'(\d{4}-\d{2}-\d{2})$').firstMatch(recordId);
    if (match == null) {
      throw FormatException(
          'Qaza record ID does not contain a date: $recordId');
    }
    return parseKey(match.group(1)!);
  }
}
