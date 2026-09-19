import '../../core/constants/prayer_types.dart';
import '../calendar/calendar_controller.dart';

/// The one place that decides what the Add Qaza flow may do next.
///
/// Pure rules over the selection: the controller asks before it changes step
/// or saves, the screen asks before it enables a control, and the save path
/// asks again with freshly read counts. Eligibility itself still belongs to
/// the Qaza service — these are the rules about the selection around it.
class AddQazaValidation {
  const AddQazaValidation._();

  /// A date may be chosen when it is inside the calendar's own bounds and is
  /// not in the future. Qaza is only ever owed for a day that has passed.
  static bool isDateInBounds(DateTime date, {required DateTime today}) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(calendarFirstDate) &&
        !day.isAfter(DateTime(today.year, today.month, today.day));
  }

  /// A selection is usable when it holds at least one date and every date in
  /// it is in bounds.
  static bool hasValidDates(List<DateTime> dates, {required DateTime today}) =>
      dates.isNotEmpty &&
      dates.every((date) => isDateInBounds(date, today: today));

  /// A range is valid when it has two ordered ends and every day between them
  /// — which is what gets stored — is in bounds.
  static bool isRangeValid(List<DateTime> ends, {required DateTime today}) {
    if (ends.length != 2) return false;
    final start = ends.first;
    final end = ends.last;
    if (end.isBefore(start)) return false;
    return isDateInBounds(start, today: today) &&
        isDateInBounds(end, today: today);
  }

  /// At least one prayer has to be chosen before anything can be reviewed.
  static bool hasPrayers(Set<PrayerType> prayers) => prayers.isNotEmpty;

  /// Whether [target] may be opened, given the work done so far.
  ///
  /// A step is reachable only when everything it depends on is valid, so the
  /// indicator can never be used to step over a rule.
  static bool canOpenStep(
    AddQazaStepRequirement target, {
    required List<DateTime> dates,
    required Set<PrayerType> prayers,
    required DateTime today,
  }) =>
      switch (target) {
        AddQazaStepRequirement.dates => true,
        AddQazaStepRequirement.prayers => hasValidDates(dates, today: today),
        AddQazaStepRequirement.review =>
          hasValidDates(dates, today: today) && hasPrayers(prayers),
      };

  /// The last gate before anything is written.
  ///
  /// [newCount] is the number of combinations a fresh analysis says do not
  /// exist yet; zero means there is nothing to save, whatever the preview
  /// said a moment ago. [datesValid] comes from [hasValidDates], so the
  /// caller can supply it from the selection or from a bare count.
  static bool canSave({
    required bool datesValid,
    required Set<PrayerType> prayers,
    required int newCount,
    required bool checking,
    required bool saving,
  }) =>
      datesValid && hasPrayers(prayers) && newCount > 0 && !checking && !saving;
}

/// What a step needs, named independently of the flow's own step enum so the
/// rules stay free of the workflow.
enum AddQazaStepRequirement { dates, prayers, review }
