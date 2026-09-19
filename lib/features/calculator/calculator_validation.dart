/// The one place the calculator's boundaries and validation rules live.
///
/// Pure functions over plain dates and ages: the controller derives its state
/// from them, the widgets derive their picker and dropdown bounds from them,
/// and the tests exercise them directly. Nothing here knows about widgets,
/// storage or the Qaza calculation itself.
library;

class CalculatorValidationResult {
  const CalculatorValidationResult.valid() : error = null;
  const CalculatorValidationResult.invalid(this.error);

  final String? error;
  bool get isValid => error == null;
}

/// The fixed boundaries every calculator input is judged against.
class CalculatorBounds {
  const CalculatorBounds._();

  /// Baligh may be claimed from the ninth year of age to the eighteenth.
  static const int minBalighAge = 9;
  static const int maxBalighAge = 18;

  /// The first day a Baligh date may fall on: 01/01 of the year the person
  /// turns [minBalighAge].
  ///
  /// Deliberately a whole-year boundary rather than the exact birthday, so a
  /// date anywhere in that calendar year can be chosen.
  static DateTime balighDateMin(DateTime dob) =>
      DateTime(dob.year + minBalighAge, 1, 1);

  /// The last day a Baligh date may fall on: 31/12 of the year the person
  /// turns [maxBalighAge].
  ///
  /// Not bounded by today on purpose — a young user's Baligh year may still
  /// be ahead of them, and the range describes the rule, not the calendar.
  static DateTime balighDateMax(DateTime dob) =>
      DateTime(dob.year + maxBalighAge, 12, 31);

  static int clampBalighAge(int age) =>
      age.clamp(minBalighAge, maxBalighAge).toInt();

  /// Whole years completed between [from] and [to]; negative if [to] is
  /// earlier than [from].
  static int completedYears(DateTime from, DateTime to) {
    var years = to.year - from.year;
    final anniversary = DateTime(to.year, from.month, from.day);
    if (to.isBefore(anniversary)) years--;
    return years;
  }

  static int currentAge(DateTime dob, DateTime today) =>
      completedYears(dob, today);

  /// The earliest regular prayer can have started: the Baligh boundary.
  static DateTime prayerStartDateMin(DateTime effectiveBalighDate) =>
      effectiveBalighDate;

  /// The latest regular prayer can have started: today. Never the future.
  static DateTime prayerStartDateMax(DateTime today) => today;

  /// The lowest prayer-start age offered: the age the Baligh boundary falls
  /// on, so the selection can never sit before Baligh.
  static int prayerStartAgeMin(DateTime dob, DateTime effectiveBalighDate) =>
      completedYears(dob, effectiveBalighDate);

  /// The highest prayer-start age offered: the person's age today.
  static int prayerStartAgeMax(DateTime dob, DateTime today) =>
      currentAge(dob, today);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';

/// Step 1 — the date of birth on its own.
String? validateDob({required DateTime? dob, required DateTime today}) {
  if (dob == null) return 'Select your date of birth.';
  if (_dateOnly(dob).isAfter(_dateOnly(today))) {
    return 'Date of birth cannot be in the future.';
  }
  return null;
}

/// Step 1 — an exact Baligh date against its date of birth.
String? validateBalighDate({
  required DateTime? dob,
  required DateTime? balighDate,
}) {
  if (dob == null || balighDate == null) return null;
  final birth = _dateOnly(dob);
  final date = _dateOnly(balighDate);
  if (date.isBefore(birth)) {
    return 'Baligh date cannot be before your date of birth.';
  }
  final min = CalculatorBounds.balighDateMin(birth);
  final max = CalculatorBounds.balighDateMax(birth);
  if (date.isBefore(min) || date.isAfter(max)) {
    return 'Baligh date must be between ${_formatDate(min)} and '
        '${_formatDate(max)}.';
  }
  return null;
}

/// Step 1 — a Baligh age against the allowed range.
String? validateBalighAge(int age) {
  if (age < CalculatorBounds.minBalighAge ||
      age > CalculatorBounds.maxBalighAge) {
    return 'Baligh age must be between ${CalculatorBounds.minBalighAge} and '
        '${CalculatorBounds.maxBalighAge} years.';
  }
  return null;
}

/// Step 2 — when regular prayer started, against Baligh, birth and today.
String? validatePrayerStart({
  required DateTime? dob,
  required DateTime? effectiveBalighDate,
  required DateTime? prayerStartDate,
  required DateTime today,
}) {
  if (dob == null || effectiveBalighDate == null || prayerStartDate == null) {
    return null;
  }
  final birth = _dateOnly(dob);
  final baligh = _dateOnly(effectiveBalighDate);
  final start = _dateOnly(prayerStartDate);
  if (start.isBefore(baligh)) {
    return 'Prayer start cannot be before the Baligh date.';
  }
  if (start.isAfter(_dateOnly(today))) {
    return 'Prayer start cannot be in the future.';
  }
  if (start.isBefore(birth)) {
    return 'Prayer start cannot be before your date of birth.';
  }
  return null;
}

/// The whole set of date rules in one pass, in the order a user meets them.
CalculatorValidationResult validateCalculatorDates({
  required DateTime today,
  required DateTime dob,
  required DateTime balighDate,
  required DateTime prayerStartDate,
}) {
  final error = validateDob(dob: dob, today: today) ??
      validateBalighDate(dob: dob, balighDate: balighDate) ??
      validatePrayerStart(
        dob: dob,
        effectiveBalighDate: balighDate,
        prayerStartDate: prayerStartDate,
        today: today,
      );
  return error == null
      ? const CalculatorValidationResult.valid()
      : CalculatorValidationResult.invalid(error);
}
