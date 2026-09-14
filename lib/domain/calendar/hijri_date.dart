/// An immutable date in the Hijri (Islamic) calendar.
///
/// This is a pure value object. Conversion to/from the Gregorian calendar is
/// performed by [IslamicCalendar] implementations; this class only carries the
/// year/month/day triple and simple ordering/navigation helpers. It never
/// embeds a conversion algorithm so the UI can stay algorithm-agnostic.
class HijriDate {
  const HijriDate({
    required this.year,
    required this.month,
    required this.day,
  })  : assert(year > 0, 'HijriDate year must be positive.'),
        assert(month >= 1 && month <= 12, 'HijriDate month must be 1..12.'),
        assert(day >= 1 && day <= 30, 'HijriDate day must be 1..30.');

  /// Hijri year (AH).
  final int year;

  /// Hijri month (1 = Muharram .. 12 = Dhu Al-Hijjah).
  final int month;

  /// Hijri day of the month.
  final int day;

  HijriDate copyWith({int? year, int? month, int? day}) {
    return HijriDate(
      year: year ?? this.year,
      month: month ?? this.month,
      day: day ?? this.day,
    );
  }

  /// The first day of the same Hijri month.
  HijriDate get firstOfMonth => HijriDate(year: year, month: month, day: 1);

  /// Zero-based month sequence index `(year * 12) + (month - 1)`, used for
  /// whole-month comparisons and navigation across Hijri years.
  int get monthIndex => (year * 12) + (month - 1);

  /// Returns a family of months: the first day of the Hijri month that is
  /// [months] months after (or before, when negative) this date.
  ///
  /// Hijri months are not uniformly 29/30 by civil arithmetic, but their month
  /// *index* advances by one per Umm al-Qura table entry, so stepping the
  /// (year, month) pair arithmetically is exactly equivalent to stepping the
  /// table and is how the supported conversion table is indexed.
  HijriDate addMonths(int months) {
    final total = (year * 12) + (month - 1) + months;
    final shifted = total % 12; // Dart `%` is Euclidean (always non-negative).
    final y = (total - shifted) ~/ 12;
    return HijriDate(year: y, month: shifted + 1, day: 1);
  }

  /// Orders this date against [other] (lower values are earlier).
  int compareTo(HijriDate other) {
    final left = (year * 480) + (month * 40) + day;
    final right = (other.year * 480) + (other.month * 40) + other.day;
    return left.compareTo(right);
  }

  @override
  bool operator ==(Object other) {
    return other is HijriDate &&
        other.year == year &&
        other.month == month &&
        other.day == day;
  }

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => 'HijriDate($day/$month/$year AH)';
}