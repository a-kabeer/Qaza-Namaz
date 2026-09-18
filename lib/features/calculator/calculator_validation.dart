/// Pure validation rules shared by calculator calculations and tests.
class CalculatorValidationResult {
  const CalculatorValidationResult.valid() : error = null;
  const CalculatorValidationResult.invalid(this.error);

  final String? error;
  bool get isValid => error == null;
}

CalculatorValidationResult validateCalculatorDates({
  required DateTime today,
  required DateTime dob,
  required DateTime balighDate,
  required DateTime prayerStartDate,
}) {
  final normalizedToday = _dateOnly(today);
  final normalizedDob = _dateOnly(dob);
  final normalizedBaligh = _dateOnly(balighDate);
  final normalizedPrayerStart = _dateOnly(prayerStartDate);

  if (normalizedDob.isAfter(normalizedToday)) {
    return const CalculatorValidationResult.invalid(
      'Date of birth cannot be in the future.',
    );
  }
  if (normalizedBaligh.isBefore(normalizedDob)) {
    return const CalculatorValidationResult.invalid(
      'Baligh date cannot be before your date of birth.',
    );
  }
  if (normalizedBaligh.isAfter(normalizedToday)) {
    return const CalculatorValidationResult.invalid(
      'Baligh date cannot be in the future.',
    );
  }
  if (normalizedPrayerStart.isBefore(normalizedBaligh)) {
    return const CalculatorValidationResult.invalid(
      'Prayer start cannot be before the Baligh date.',
    );
  }
  if (normalizedPrayerStart.isAfter(normalizedToday)) {
    return const CalculatorValidationResult.invalid(
      'Prayer start cannot be in the future.',
    );
  }
  if (normalizedPrayerStart.isBefore(normalizedDob)) {
    return const CalculatorValidationResult.invalid(
      'Prayer start cannot be before your date of birth.',
    );
  }
  return const CalculatorValidationResult.valid();
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
