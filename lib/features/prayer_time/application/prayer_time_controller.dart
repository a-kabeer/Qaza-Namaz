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
  Future<PrayerTimeSnapshot?> build() async {
    final profile = await ref.watch(userProfileProvider.future);
    final cached = await _cache.load();
    final madhab = profile?.madhab;

    if (cached == null || madhab == null) return cached;

    // Old snapshots have no calculationMadhab metadata and cannot be trusted
    // to represent the current Profile. Recalculate before exposing them.
    if (cached.calculationMadhab != madhab) {
      final normalized = await _calculate(
        location: cached.location,
        madhab: madhab,
      );
      await _cache.save(normalized);
      return normalized;
    }

    return cached;
  }

  Future<PrayerTimeSnapshot> _calculate({
    required PrayerLocation location,
    required Madhab madhab,
  }) async {
    final zone = tz.getLocation(location.timezoneId);
    final localNow = tz.TZDateTime.now(zone);
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final tomorrow =
        DateTime(localNow.year, localNow.month, localNow.day + 1);

    return PrayerTimeSnapshot(
      location: location,
      settings: const PrayerSettings(),
      today: _calculator.calculate(
        location: location,
        madhab: madhab,
        localDate: today,
      ),
      tomorrow: _calculator.calculate(
        location: location,
        madhab: madhab,
        localDate: tomorrow,
      ),
      updatedAt: DateTime.now().toUtc(),
      calculationMadhab: madhab,
    );
  }

  Future<void> _persist(PrayerTimeSnapshot snapshot) async {
    await _cache.save(snapshot);
    state = AsyncData(snapshot);
  }

  Future<void> _silentRefresh(PrayerTimeSnapshot cached) async {
    if (cached.location.source != PrayerLocationSource.current) return;
    final age = DateTime.now().toUtc().difference(cached.updatedAt);
    if (age >= Duration.zero && age < refreshInterval) return;
    try {
      final madhab = await _currentMadhab();
      final latest = await _locations.getLastKnown();
      if (latest != null) {
        await _applyLocationIfNeeded(cached, latest, madhab);
      }
      final current = await _locations.getCurrent();
      await _applyLocationIfNeeded(
        state.valueOrNull ?? cached,
        current,
        madhab,
      );
    } catch (_) {
      // Keep the valid cached schedule when a silent refresh cannot complete.
    }
  }

  Future<void> _applyLocationIfNeeded(
    PrayerTimeSnapshot baseline,
    PrayerLocation location,
    Madhab madhab,
  ) async {
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
          settings: const PrayerSettings(),
          today: baseline.today,
          tomorrow: baseline.tomorrow,
          updatedAt: baseline.updatedAt,
          calculationMadhab: madhab,
        ),
      );
      return;
    }

    await _persist(
      await _calculate(
        location: location,
        madhab: madhab,
      ),
    );
  }

  Future<bool> useCurrentLocation() async {
    ref.read(prayerTimeRefreshProvider.notifier).state = true;
    try {
      final location = await _locations.getCurrent();
      final madhab = await _currentMadhab();
      await _persist(
        await _calculate(location: location, madhab: madhab),
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
      final location = _locations.fromCity(option);
      final madhab = await _currentMadhab();
      await _persist(
        await _calculate(location: location, madhab: madhab),
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
    try {
      final madhab = await _currentMadhab();
      await _persist(
        await _calculate(
          location: current.location,
          madhab: madhab,
        ),
      );
      return true;
    } finally {
      ref.read(prayerTimeRefreshProvider.notifier).state = false;
    }
  }

  Future<Madhab> _currentMadhab() async {
    final profile = await ref.read(userProfileProvider.future);
    return profile?.madhab ?? Madhab.hanafi;
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null || current.location.source != PrayerLocationSource.current) {
      return;
    }
    await _silentRefresh(current);
  }
}
