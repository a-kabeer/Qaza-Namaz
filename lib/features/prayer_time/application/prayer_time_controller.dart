import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../app/providers.dart';
import '../../../domain/entities/user_profile.dart';
import '../data/prayer_location_repository.dart';
import '../data/prayer_time_cache.dart';
import '../domain/prayer_location.dart';
import '../domain/prayer_settings.dart';
import '../domain/prayer_time.dart';
import '../domain/prayer_time_calculator.dart';
import 'prayer_time_providers.dart';

class PrayerTimeController extends AsyncNotifier<PrayerTimeSnapshot?> {
  static const refreshInterval = Duration(hours: 4);
  bool _dateRefreshInFlight = false;
  PrayerTimeCache get _cache => ref.read(prayerTimeCacheProvider);
  PrayerLocationRepository get _locations =>
      ref.read(prayerLocationRepositoryProvider);
  PrayerTimeCalculator get _calculator =>
      ref.read(prayerTimeCalculatorProvider);

  @override
  Future<PrayerTimeSnapshot?> build() async {\n    final profile = await ref.watch(userProfileProvider.future);\n    final cached = await _cache.load();\n    final madhab = profile?.madhab;\n\n    if (cached == null || madhab == null) return cached;\n\n    // Old snapshots have no calculationMadhab metadata and cannot be trusted\n    // to represent the current Profile. Recalculate before exposing them.\n    if (cached.calculationMadhab != madhab) {\n      final normalized = await _calculate(\n        location: cached.location,\n        madhab: madhab,\n      );\n      await _cache.save(normalized);\n      return normalized;\n    }\n\n    return cached;\n  }

  Future<PrayerTimeSnapshot> _calculate({\n    required PrayerLocation location,\n    required Madhab madhab,\n  }) async {
    final zone = tz.getLocation(location.timezoneId);
    final localNow = tz.TZDateTime.now(zone);
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final tomorrow =
        DateTime(localNow.year, localNow.month, localNow.day + 1);

    return PrayerTimeSnapshot(
      location: location,
      settings: const PrayerSettings(),\n      today: _calculator.calculate(\n        location: location,\n        madhab: madhab,\n        localDate: today,\n      ),\n      tomorrow: _calculator.calculate(\n        location: location,\n        madhab: madhab,\n        localDate: tomorrow,\n      ),\n      updatedAt: DateTime.now().toUtc(),\n      calculationMadhab: madhab,\n    );
  }

  Future<void> _persist(PrayerTimeSnapshot snapshot) async {
    await _cache.save(snapshot);
    state = AsyncData(snapshot);
  }

  Future<void> _silentRefresh(PrayerTimeSnapshot cached) async {\n    if (cached.location.source != PrayerLocationSource.current) return;\n    final age = DateTime.now().toUtc().difference(cached.updatedAt);
    if (age >= Duration.zero && age < refreshInterval) return;
    try {\n      final madhab = await _currentMadhab();\n      final latest = await _locations.getLastKnown();
      if (latest != null) {
        await _applyLocationIfNeeded(cached, latest, madhab);
      }
      final current = await _locations.getCurrent();
      await _applyLocationIfNeeded(
        state.valueOrNull ?? cached,\n        current,\n        madhab,\n      );
    } catch (_) {
      // Keep the valid cached schedule when a silent refresh cannot complete.
    }
  }

  Future<void> _applyLocationIfNeeded(\n    PrayerTimeSnapshot baseline,\n    PrayerLocation location,\n    Madhab madhab,\n  ) async {
    final movedKm = baseline.location.distanceKmTo(
      location.latitude,
      location.longitude,
    );
    final timezoneChanged =
        baseline.location.timezoneId != location.timezoneId;

    if (movedKm < 5 && !timezoneChanged) {
      final updatedLocation = PrayerLocation(
        latitude: location.latitude,
        longitude: location.longitude,
        city: location.city,
        region: location.region,
        country: location.country,
        countryCode: location.countryCode,
        timezoneId: baseline.location.timezoneId,
        source: PrayerLocationSource.current,
      );
      await _persist(
        PrayerTimeSnapshot(
          location: updatedLocation,
          settings: const PrayerSettings(),\n          today: baseline.today,\n          tomorrow: baseline.tomorrow,\n          updatedAt: baseline.updatedAt,\n          calculationMadhab: madhab,\n        ),
      );
      return;
    }

    await _persist(
      await _calculate(\n        location: location,\n        madhab: madhab,\n      ),
    );
  }

  Future<bool> useCurrentLocation() async {
    ref.read(prayerTimeRefreshProvider.notifier).state = true;
    try {
      final location = await _locations.getCurrent();\n      final madhab = await _currentMadhab();\n      await _persist(\n        await _calculate(location: location, madhab: madhab),
      );
      return true;
    } catch (error, stack) {
      if (state.valueOrNull == null) {
        state = AsyncError(error, stack);
      }
      return false;
    } finally {
      ref.read(prayerTimeRefreshProvider.notifier).state = false;
    }
  }

  Future<bool> selectCity(CityOption option) async {
    ref.read(prayerTimeRefreshProvider.notifier).state = true;
    try {
      final location = _locations.fromCity(option);\n      final madhab = await _currentMadhab();\n      await _persist(\n        await _calculate(location: location, madhab: madhab),
      );
      return true;
    } catch (error, stack) {
      if (state.valueOrNull == null) {
        state = AsyncError(error, stack);
      }
      return false;
    } finally {
      ref.read(prayerTimeRefreshProvider.notifier).state = false;
    }
  }

  Future<void> refreshForDateIfNeeded(DateTime localDate) async {
    final current = state.valueOrNull;
    if (current == null || current.today.date == localDate) return;
    if (_dateRefreshInFlight) return;

    _dateRefreshInFlight = true;
    try {
      await refreshSchedule();
    } finally {
      _dateRefreshInFlight = false;
    }
  }

  Future<bool> refreshSchedule() async {
    final current = state.valueOrNull;
    if (current == null) return false;
    ref.read(prayerTimeRefreshProvider.notifier).state = true;
    try {\n      final madhab = await _currentMadhab();\n      await _persist(\n        await _calculate(\n          location: current.location,\n          madhab: madhab,\n        ),\n      );
      return true;
    } finally {
      ref.read(prayerTimeRefreshProvider.notifier).state = false;
    }
  }

  Future<Madhab> _currentMadhab() async {\n    final profile = await ref.read(userProfileProvider.future);\n    return profile?.madhab ?? Madhab.hanafi;\n  }\n\n  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null || current.location.source != PrayerLocationSource.current) {
      return;
    }
    await _silentRefresh(current);
  }
}
