import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/qaza_date.dart';
import '../../domain/services/qaza_service.dart';
import 'calculator_persistence.dart';
import 'calculator_validation.dart';
import 'calculator_tracker.dart';
import 'qaza_calculation.dart';

enum BalighInputMode { age, exactDate }

enum PrayerStartInputMode { age, exactDate }

/// Immutable workflow state for the three-step calculator.
///
/// Every derived value the UI needs (validation, effective dates, step gating)
/// is computed here so the widget layer only renders and dispatches.
class CalculatorState {
  const CalculatorState({
    this.step = 0,
    this.dob,
    this.balighMode = BalighInputMode.age,
    this.balighAge = 12,
    this.balighDate,
    this.prayerStartMode = PrayerStartInputMode.age,
    this.prayerStartAge = 18,
    this.prayerStartDate,
    this.includeWitr = false,
    this.calculation,
    this.restoring = true,
    this.addingToTracker = false,
    this.addProcessed = 0,
    this.addTotal = 0,
    this.addedCount,
    this.loadingPreflight = false,
    this.preflight,
    this.error,
  });

  final int step;
  final DateTime? dob;
  final BalighInputMode balighMode;
  final int balighAge;
  final DateTime? balighDate;
  final PrayerStartInputMode prayerStartMode;
  final int prayerStartAge;
  final DateTime? prayerStartDate;
  final bool includeWitr;
  final QazaCalculation? calculation;
  final bool restoring;
  final bool addingToTracker;

  /// Records written so far in the current insert.
  final int addProcessed;

  /// Records the current insert will write in total.
  final int addTotal;

  /// How many were added by the last successful insert, or null before one.
  final int? addedCount;

  final bool loadingPreflight;

  /// Fraction written, 0 until a total is known.
  ///
  /// Determinate on purpose: the total comes from the preflight analysis
  /// before any row is written, so the bar never has to guess.
  double get addProgress =>
      addTotal <= 0 ? 0 : (addProcessed / addTotal).clamp(0, 1).toDouble();

  bool get hasAddResult => addedCount != null;

  /// True once an estimate has been added and the calculator has nothing
  /// left to do with it: the result is gone, only the outcome remains.
  bool get addCompleted => hasAddResult && calculation == null;

  /// Shared preflight for `Add to Tracker`, or null before it has been run.
  final QazaAvailabilityAnalysis? preflight;
  final String? error;

  static DateTime get today => QazaDate.normalize(DateTime.now());

  int? get currentAge {
    final birth = dob;
    if (birth == null) return null;
    final now = today;
    var age = now.year - birth.year;
    if (now.isBefore(DateTime(now.year, birth.month, birth.day))) age--;
    return age;
  }

  DateTime? get estimatedBalighDate {
    final birth = dob;
    if (birth == null || balighMode != BalighInputMode.age) return null;
    return DateTime(birth.year + balighAge, birth.month, birth.day);
  }

  /// The earliest and latest an exact Baligh date may fall, from the central
  /// rules. Null until a date of birth is known.
  DateTime? get balighDateMin =>
      dob == null ? null : CalculatorBounds.balighDateMin(dob!);

  DateTime? get balighDateMax =>
      dob == null ? null : CalculatorBounds.balighDateMax(dob!);

  DateTime? get effectiveBalighDate => balighMode == BalighInputMode.exactDate
      ? balighDate
      : estimatedBalighDate;

  DateTime? get estimatedPrayerStartDate {
    final birth = dob;
    if (birth == null || prayerStartMode != PrayerStartInputMode.age) {
      return null;
    }
    return DateTime(birth.year + prayerStartAge, birth.month, birth.day);
  }

  DateTime? get effectivePrayerStartDate =>
      prayerStartMode == PrayerStartInputMode.exactDate
          ? prayerStartDate
          : estimatedPrayerStartDate;

  /// The age the effective Baligh boundary falls on, whichever way it was
  /// given. This is the floor for everything on Step 2.
  int? get effectiveBalighAge {
    final birth = dob;
    final baligh = effectiveBalighDate;
    if (birth == null || baligh == null) return null;
    return CalculatorBounds.completedYears(birth, baligh);
  }

  /// Prayer can only have started between Baligh and today.
  DateTime? get prayerStartDateMin {
    final baligh = effectiveBalighDate;
    return baligh == null ? null : CalculatorBounds.prayerStartDateMin(baligh);
  }

  DateTime get prayerStartDateMax => CalculatorBounds.prayerStartDateMax(today);

  int? get prayerStartAgeMin => effectiveBalighAge;

  int? get prayerStartAgeMax => currentAge;

  /// True when there is at least one prayer-start age to choose from — a
  /// child younger than their own Baligh boundary has none.
  bool get hasPrayerStartAgeRange {
    final min = prayerStartAgeMin;
    final max = prayerStartAgeMax;
    return min != null && max != null && max >= min;
  }

  String? get dobError => validateDob(dob: dob, today: today);

  String? get balighError => balighMode == BalighInputMode.age
      ? validateBalighAge(balighAge)
      : validateBalighDate(dob: dob, balighDate: balighDate);

  String? get prayerStartError => validatePrayerStart(
        dob: dob,
        effectiveBalighDate: effectiveBalighDate,
        prayerStartDate: effectivePrayerStartDate,
        today: today,
      );

  bool get step1Valid =>
      dobError == null && balighError == null && effectiveBalighDate != null;

  bool get step2Valid =>
      step1Valid &&
      effectivePrayerStartDate != null &&
      prayerStartError == null;

  /// Which steps the indicator may open.
  ///
  /// A step is reachable once everything it depends on is valid; the step the
  /// user is on is always reachable, and nothing ahead of the work done so
  /// far ever is.
  bool canOpenStep(int index) {
    if (index == step) return true;
    return switch (index) {
      0 => true,
      1 => step1Valid,
      2 => step1Valid && step2Valid && calculation != null,
      _ => false,
    };
  }

  CalculatorState copyWith({
    int? step,
    DateTime? dob,
    BalighInputMode? balighMode,
    int? balighAge,
    DateTime? balighDate,
    PrayerStartInputMode? prayerStartMode,
    int? prayerStartAge,
    DateTime? prayerStartDate,
    bool? includeWitr,
    QazaCalculation? calculation,
    bool? restoring,
    bool? addingToTracker,
    int? addProcessed,
    int? addTotal,
    int? addedCount,
    bool clearAddResult = false,
    bool? loadingPreflight,
    QazaAvailabilityAnalysis? preflight,
    String? error,
    bool clearDob = false,
    bool clearBalighDate = false,
    bool clearPrayerStartDate = false,
    bool clearCalculation = false,
    bool clearPreflight = false,
    bool clearError = false,
  }) =>
      CalculatorState(
        step: step ?? this.step,
        dob: clearDob ? null : dob ?? this.dob,
        balighMode: balighMode ?? this.balighMode,
        balighAge: balighAge ?? this.balighAge,
        balighDate: clearBalighDate ? null : balighDate ?? this.balighDate,
        prayerStartMode: prayerStartMode ?? this.prayerStartMode,
        prayerStartAge: prayerStartAge ?? this.prayerStartAge,
        prayerStartDate: clearPrayerStartDate
            ? null
            : prayerStartDate ?? this.prayerStartDate,
        includeWitr: includeWitr ?? this.includeWitr,
        calculation: clearCalculation ? null : calculation ?? this.calculation,
        restoring: restoring ?? this.restoring,
        addingToTracker: addingToTracker ?? this.addingToTracker,
        addProcessed: addProcessed ?? this.addProcessed,
        addTotal: addTotal ?? this.addTotal,
        addedCount: clearAddResult ? null : addedCount ?? this.addedCount,
        loadingPreflight: loadingPreflight ?? this.loadingPreflight,
        preflight: clearPreflight ? null : preflight ?? this.preflight,
        error: clearError ? null : error ?? this.error,
      );
}

/// Owns the calculator workflow: inputs, validation, the calculation itself,
/// per-user persistence, the shared preflight and the tracker insert.
///
/// Rebuilt whenever the signed-in account changes, which is what keeps
/// calculator state isolated per user.
class CalculatorController extends Notifier<CalculatorState> {
  static const CalculatorPersistence _persistence = CalculatorPersistence();

  String? _userId;
  Future<void> _saveQueue = Future<void>.value();
  bool _disposed = false;

  @override
  CalculatorState build() {
    _userId = ref.watch(activeUserIdProvider);
    // Work started for one account must not land on the next one.
    ref.onDispose(() => _disposed = true);
    Future.microtask(restore);
    return const CalculatorState();
  }

  Future<void> restore() async {
    try {
      final snapshot = await _persistence.load(userId: _userId);
      if (_disposed) return;
      if (snapshot == null) {
        state = state.copyWith(restoring: false);
        return;
      }

      final dob =
          snapshot.dob == null ? null : QazaDate.normalize(snapshot.dob!);
      final balighMode = snapshot.balighMode == BalighInputMode.exactDate.name
          ? BalighInputMode.exactDate
          : BalighInputMode.age;
      final prayerMode =
          snapshot.prayerStartMode == PrayerStartInputMode.exactDate.name
              ? PrayerStartInputMode.exactDate
              : PrayerStartInputMode.age;
      final balighDate = snapshot.balighDate == null
          ? null
          : QazaDate.normalize(snapshot.balighDate!);
      final prayerStartDate = snapshot.prayerStartDate == null
          ? null
          : QazaDate.normalize(snapshot.prayerStartDate!);

      final effectiveBaligh = balighMode == BalighInputMode.exactDate
          ? balighDate
          : dob == null
              ? null
              : DateTime(dob.year + snapshot.balighAge, dob.month, dob.day);
      final effectiveStart = prayerMode == PrayerStartInputMode.exactDate
          ? prayerStartDate
          : dob == null
              ? null
              : DateTime(
                  dob.year + snapshot.prayerStartAge, dob.month, dob.day);

      QazaCalculation? calculation;
      if (snapshot.hasCalculation &&
          effectiveBaligh != null &&
          effectiveStart != null) {
        try {
          calculation = calculateQaza(
            startDate: effectiveBaligh,
            endDate: effectiveStart,
            includeWitr: snapshot.includeWitr,
          );
        } on ArgumentError {
          calculation = null;
        }
      }

      state = _normalized(CalculatorState(
        step: calculation != null
            ? snapshot.step.clamp(0, 2)
            : snapshot.step.clamp(0, 1),
        dob: dob,
        balighMode: balighMode,
        balighAge: snapshot.balighAge,
        balighDate: balighDate,
        prayerStartMode: prayerMode,
        prayerStartAge: snapshot.prayerStartAge,
        prayerStartDate: prayerStartDate,
        includeWitr: snapshot.includeWitr,
        calculation: calculation,
        restoring: false,
      ));
    } catch (_) {
      state = state.copyWith(restoring: false);
    }
  }

  void _persist() {
    if (state.restoring) return;
    // An added estimate is finished business. Its inputs are worth keeping;
    // its Step 3 is not, so the snapshot records the start of the flow.
    final snapshot = CalculatorSnapshot(
      step: state.addCompleted ? 0 : state.step,
      dob: state.dob,
      balighMode: state.balighMode.name,
      balighAge: state.balighAge,
      balighDate: state.balighDate,
      prayerStartMode: state.prayerStartMode.name,
      prayerStartAge: state.prayerStartAge,
      prayerStartDate: state.prayerStartDate,
      includeWitr: state.includeWitr,
      hasCalculation: state.calculation != null,
    );
    final userId = _userId;
    _saveQueue =
        _saveQueue.then((_) => _persistence.save(snapshot, userId: userId));
  }

  /// Brings every dependent input back inside the central boundaries.
  ///
  /// Ages are corrected to the nearest allowed value and out-of-range dates
  /// are dropped, so changing a date of birth or a Baligh boundary can never
  /// leave a stale selection behind it.
  CalculatorState _normalized(CalculatorState input) {
    var next = input.copyWith(
      balighAge: CalculatorBounds.clampBalighAge(input.balighAge),
    );

    final balighMin = next.balighDateMin;
    final balighMax = next.balighDateMax;
    final baligh = next.balighDate;
    if (baligh != null && balighMin != null && balighMax != null) {
      if (baligh.isBefore(balighMin) || baligh.isAfter(balighMax)) {
        next = next.copyWith(clearBalighDate: true);
      }
    }

    if (next.hasPrayerStartAgeRange) {
      next = next.copyWith(
        prayerStartAge: next.prayerStartAge
            .clamp(next.prayerStartAgeMin!, next.prayerStartAgeMax!)
            .toInt(),
      );
    }

    final start = next.prayerStartDate;
    final startMin = next.prayerStartDateMin;
    if (start != null &&
        ((startMin != null && start.isBefore(startMin)) ||
            start.isAfter(next.prayerStartDateMax))) {
      next = next.copyWith(clearPrayerStartDate: true);
    }

    return next;
  }

  /// Any input change invalidates a previous result and its preflight, and is
  /// re-checked against every rule that depends on it.
  void _applyInput(CalculatorState next) {
    state = _normalized(next.copyWith(
      clearCalculation: true,
      clearPreflight: true,
    ));
    _persist();
  }

  void setDob(DateTime date) =>
      _applyInput(state.copyWith(dob: QazaDate.normalize(date)));

  void setBalighMode(BalighInputMode mode) => _applyInput(
        mode == BalighInputMode.age
            ? state.copyWith(balighMode: mode, clearBalighDate: true)
            : state.copyWith(balighMode: mode),
      );

  void setBalighAge(int age) => _applyInput(
      state.copyWith(balighAge: CalculatorBounds.clampBalighAge(age)));

  void setBalighDate(DateTime date) =>
      _applyInput(state.copyWith(balighDate: QazaDate.normalize(date)));

  void setPrayerStartMode(PrayerStartInputMode mode) => _applyInput(
        mode == PrayerStartInputMode.age
            ? state.copyWith(prayerStartMode: mode, clearPrayerStartDate: true)
            : state.copyWith(prayerStartMode: mode),
      );

  void setPrayerStartAge(int age) =>
      _applyInput(state.copyWith(prayerStartAge: age));

  void setPrayerStartDate(DateTime date) =>
      _applyInput(state.copyWith(prayerStartDate: QazaDate.normalize(date)));

  /// Witr is configured on Step 2, before the result exists. When a result is
  /// already on screen it is recalculated in place rather than invalidated.
  void setIncludeWitr(bool value) {
    final existing = state.calculation;
    state = state.copyWith(
      includeWitr: value,
      clearPreflight: true,
      calculation: existing == null
          ? null
          : calculateQaza(
              startDate: existing.startDate,
              endDate: existing.endDate,
              includeWitr: value,
            ),
    );
    _persist();
  }

  void next() {
    if (state.step == 0) {
      if (!state.step1Valid) return;
      goToStep(1);
      return;
    }
    if (state.step == 1 && state.step2Valid) calculate();
  }

  void back() {
    if (state.step == 0) return;
    goToStep(state.step - 1);
  }

  /// The one way steps change hands: the indicator, the Back button and the
  /// Result step's edit actions all come through here, so a step can only
  /// ever be opened when its own rules allow it.
  ///
  /// Navigating away from a result does not discard it — only editing an
  /// input does — so a step already reached stays reachable.
  void goToStep(int target) {
    if (target == state.step || !state.canOpenStep(target)) return;
    state = state.addCompleted
        ? state.copyWith(
            step: target,
            addProcessed: 0,
            addTotal: 0,
            clearAddResult: true,
          )
        : state.copyWith(step: target);
    _persist();
    if (target == 2) _ensurePreflight();
  }

  /// Starts the preflight the Result step needs to name its own action.
  ///
  /// Only for a signed-in or guest account — with no account there is nothing
  /// to check against, and the step still works without the count.
  void _ensurePreflight() {
    if (_userId == null ||
        state.calculation == null ||
        state.preflight != null ||
        state.loadingPreflight) {
      return;
    }
    unawaited(loadPreflight());
  }

  void calculate() {
    final start = state.effectiveBalighDate;
    final end = state.effectivePrayerStartDate;
    if (start == null || end == null || end.isBefore(start)) return;
    try {
      state = state.copyWith(
        calculation: calculateQaza(
          startDate: start,
          endDate: end,
          includeWitr: state.includeWitr,
        ),
        clearPreflight: true,
        step: 2,
      );
      _persist();
      _ensurePreflight();
    } on ArgumentError {
      // Validation already blocks this; leave the previous state untouched.
    }
  }

  /// Runs the shared preflight engine so the user sees what will actually be
  /// created before any record is written.
  Future<QazaAvailabilityAnalysis?> loadPreflight() async {
    final calculation = state.calculation;
    if (calculation == null) return null;
    state = state.copyWith(loadingPreflight: true, clearError: true);
    try {
      final analysis = await ref.read(qazaServiceProvider).analyzeAvailability(
            userId: ref.read(requiredUserIdProvider),
            dates: trackerDates(calculation),
            prayerTypes: trackerPrayerTypes(
              includeWitr: calculation.includeWitr,
            ),
          );
      if (_disposed) return null;
      state = state.copyWith(preflight: analysis, loadingPreflight: false);
      return analysis;
    } catch (error) {
      if (_disposed) return null;
      state = state.copyWith(
        loadingPreflight: false,
        error: 'Could not check your existing records: $error',
      );
      return null;
    }
  }

  /// Creates the new records, reporting progress as it goes.
  ///
  /// Repeat taps are rejected while in flight, and the service re-analyses at
  /// save time, so the operation stays idempotent. A twenty year estimate is
  /// written in batches so the screen can show real movement rather than
  /// sitting still until the whole thing lands.
  Future<bool> addToTracker() async {
    final calculation = state.calculation;
    if (calculation == null || state.addingToTracker) return false;
    state = state.copyWith(
      addingToTracker: true,
      addProcessed: 0,
      addTotal: 0,
      clearAddResult: true,
      clearError: true,
    );
    try {
      final added = await ref.read(qazaServiceProvider).recordQazaForDates(
            userId: ref.read(requiredUserIdProvider),
            dates: trackerDates(calculation),
            prayerTypes:
                trackerPrayerTypes(includeWitr: calculation.includeWitr),
            onProgress: (processed, total) {
              if (_disposed) return;
              state = state.copyWith(addProcessed: processed, addTotal: total);
            },
          );
      if (_disposed) return false;
      // The estimate has been consumed. Clearing it here is what turns
      // Step 3 into a success state rather than a form inviting a second add.
      state = state.copyWith(
        addingToTracker: false,
        addedCount: added,
        clearCalculation: true,
        clearPreflight: true,
      );
      // Home reads the aggregate, which has just changed underneath it.
      ref.invalidate(progressSummaryProvider);
      _persist();
      return true;
    } catch (error) {
      if (_disposed) return false;
      state = state.copyWith(
        addingToTracker: false,
        error: 'Could not add the estimate: $error',
      );
      return false;
    }
  }

  /// Leaves the success state and starts over from Step 1.
  ///
  /// Behind both `Calculate Again` and `Done`: the finished calculation, its
  /// preflight and its result are cleared, while the answers the user gave
  /// about themselves are kept so a fresh calculation is a step away.
  void startNewCalculation() {
    state = state.copyWith(
      step: 0,
      addProcessed: 0,
      addTotal: 0,
      clearCalculation: true,
      clearPreflight: true,
      clearAddResult: true,
      clearError: true,
    );
    _persist();
  }
}

final calculatorControllerProvider =
    NotifierProvider<CalculatorController, CalculatorState>(
  CalculatorController.new,
);
