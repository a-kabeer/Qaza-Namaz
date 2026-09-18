import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/qaza_date.dart';
import '../../domain/services/qaza_service.dart';
import 'calculator_persistence.dart';
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
    this.keptAsEstimate = false,
    this.restoring = true,
    this.addingToTracker = false,
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
  final bool keptAsEstimate;
  final bool restoring;
  final bool addingToTracker;
  final bool loadingPreflight;

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

  /// True when at least one boundary came from an exact date rather than an age.
  bool get usesExactDates =>
      balighMode == BalighInputMode.exactDate ||
      prayerStartMode == PrayerStartInputMode.exactDate;

  String? get dobError {
    final birth = dob;
    if (birth == null) return 'Select your date of birth.';
    if (birth.isAfter(today)) return 'Date of birth cannot be in the future.';
    return null;
  }

  String? get balighError {
    final date = balighDate;
    final birth = dob;
    if (balighMode == BalighInputMode.age || birth == null || date == null) {
      return null;
    }
    if (date.isBefore(birth)) {
      return 'Baligh date cannot be before your date of birth.';
    }
    if (date.isAfter(today)) return 'Baligh date cannot be in the future.';
    return null;
  }

  String? get prayerStartError {
    final birth = dob;
    final baligh = effectiveBalighDate;
    final start = effectivePrayerStartDate;
    if (birth == null || baligh == null || start == null) return null;
    if (start.isBefore(baligh)) {
      return 'Prayer start cannot be before the Baligh date.';
    }
    if (start.isAfter(today)) return 'Prayer start cannot be in the future.';
    if (start.isBefore(birth)) {
      return 'Prayer start cannot be before your date of birth.';
    }
    return null;
  }

  bool get step1Valid =>
      dobError == null && balighError == null && effectiveBalighDate != null;

  bool get step2Valid =>
      step1Valid &&
      effectivePrayerStartDate != null &&
      prayerStartError == null;

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
    bool? keptAsEstimate,
    bool? restoring,
    bool? addingToTracker,
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
        keptAsEstimate: keptAsEstimate ?? this.keptAsEstimate,
        restoring: restoring ?? this.restoring,
        addingToTracker: addingToTracker ?? this.addingToTracker,
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

  @override
  CalculatorState build() {
    _userId = ref.watch(activeUserIdProvider);
    Future.microtask(restore);
    return const CalculatorState();
  }

  Future<void> restore() async {
    try {
      final snapshot = await _persistence.load(userId: _userId);
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

      state = CalculatorState(
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
        keptAsEstimate: snapshot.keptAsEstimate && calculation != null,
        restoring: false,
      );
    } catch (_) {
      state = state.copyWith(restoring: false);
    }
  }

  void _persist() {
    if (state.restoring) return;
    final snapshot = CalculatorSnapshot(
      step: state.step,
      dob: state.dob,
      balighMode: state.balighMode.name,
      balighAge: state.balighAge,
      balighDate: state.balighDate,
      prayerStartMode: state.prayerStartMode.name,
      prayerStartAge: state.prayerStartAge,
      prayerStartDate: state.prayerStartDate,
      includeWitr: state.includeWitr,
      hasCalculation: state.calculation != null,
      keptAsEstimate: state.keptAsEstimate,
    );
    final userId = _userId;
    _saveQueue =
        _saveQueue.then((_) => _persistence.save(snapshot, userId: userId));
  }

  /// Any input change invalidates a previous result and its preflight.
  void _applyInput(CalculatorState next) {
    state = next.copyWith(
      clearCalculation: true,
      clearPreflight: true,
      keptAsEstimate: false,
    );
    _persist();
  }

  void setDob(DateTime date) =>
      _applyInput(state.copyWith(dob: QazaDate.normalize(date)));

  void setBalighMode(BalighInputMode mode) => _applyInput(
        mode == BalighInputMode.age
            ? state.copyWith(balighMode: mode, clearBalighDate: true)
            : state.copyWith(balighMode: mode),
      );

  void setBalighAge(int age) => _applyInput(state.copyWith(balighAge: age));

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
      keptAsEstimate: false,
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
      state = state.copyWith(step: 1);
      _persist();
      return;
    }
    if (state.step == 1 && state.step2Valid) calculate();
  }

  void back() {
    if (state.step == 0) return;
    state = state.copyWith(step: state.step - 1);
    _persist();
  }

  void editStep(int target) {
    if (target < 0 || target > 1) return;
    state = state.copyWith(
      step: target,
      clearCalculation: true,
      clearPreflight: true,
      keptAsEstimate: false,
    );
    _persist();
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
        keptAsEstimate: false,
        clearPreflight: true,
        step: 2,
      );
      _persist();
    } on ArgumentError {
      // Validation already blocks this; leave the previous state untouched.
    }
  }

  void keepAsEstimate() {
    state = state.copyWith(keptAsEstimate: true);
    _persist();
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
      state = state.copyWith(preflight: analysis, loadingPreflight: false);
      return analysis;
    } catch (error) {
      state = state.copyWith(
        loadingPreflight: false,
        error: 'Could not check your existing records: $error',
      );
      return null;
    }
  }

  /// Creates the new records. Repeat taps are rejected while in flight, and the
  /// service re-analyses at save time, so the operation is idempotent.
  Future<bool> addToTracker() async {
    final calculation = state.calculation;
    if (calculation == null || state.addingToTracker) return false;
    state = state.copyWith(addingToTracker: true, clearError: true);
    try {
      await ref.read(qazaServiceProvider).recordQazaForDates(
            userId: ref.read(requiredUserIdProvider),
            dates: trackerDates(calculation),
            prayerTypes:
                trackerPrayerTypes(includeWitr: calculation.includeWitr),
          );
      state = state.copyWith(
        addingToTracker: false,
        keptAsEstimate: false,
        clearPreflight: true,
      );
      _persist();
      return true;
    } catch (error) {
      state = state.copyWith(
        addingToTracker: false,
        error: 'Could not add the estimate: $error',
      );
      return false;
    }
  }
}

final calculatorControllerProvider =
    NotifierProvider<CalculatorController, CalculatorState>(
  CalculatorController.new,
);
