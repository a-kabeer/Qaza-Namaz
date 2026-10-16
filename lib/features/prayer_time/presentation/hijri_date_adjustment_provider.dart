import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the app-wide Hijri display offset, without changing source dates.
final hijriDateAdjustmentProvider =
    AsyncNotifierProvider<HijriDateAdjustmentNotifier, int>(
  HijriDateAdjustmentNotifier.new,
);

class HijriDateAdjustmentNotifier extends AsyncNotifier<int> {
  static const storageKey = 'hijri_date_offset_days';
  static const supportedOffsets = <int>[-2, -1, 0, 1, 2];

  @override
  Future<int> build() async {
    final preferences = await SharedPreferences.getInstance();
    final storedOffset = preferences.getInt(storageKey) ?? 0;
    return supportedOffsets.contains(storedOffset) ? storedOffset : 0;
  }

  Future<void> setOffset(int offsetDays) async {
    if (!supportedOffsets.contains(offsetDays)) {
      throw ArgumentError.value(
        offsetDays,
        'offsetDays',
        'Hijri date offset must be between -2 and +2 days.',
      );
    }

    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setInt(storageKey, offsetDays);
    if (!saved) {
      throw StateError('The Hijri date adjustment could not be saved.');
    }

    state = AsyncData(offsetDays);
  }
}
