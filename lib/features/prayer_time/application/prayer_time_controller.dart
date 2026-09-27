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
  PrayerTimeCache get _cache => ref.read(prayerTimeCacheProvider);
  PrayerLocationRepository get _locations =>
      ref.read(prayerLocationRepositoryProvider);
  PrayerTimeCalculator get _calculator =>
      ref.read(prayerTimeCalculatorProvider);

  @override
  Future<PrayerTimeSnapshot?> build() async {
    final cached = await _cache.load();
    if (cached != null) {
      Future<void>.microtask(() => _silentRefresh(cached));
    }
    return cached;
  }

  PrayerSettings _defaultSettings() {
    final profile = ref.read(userProfileProvider).valueOrNull;
    return PrayerSettings(
      asrMethod: profile?.madhab == Madhab.hanafi
          ? PrayerAsrMethod.hanafi
          : PrayerAsrMethod.standard,
    );
  }

  Future<PrayerTimeSnapshot> _calculate({
    required PrayerLocation location,
    required PrayerSettings settings,
  }) async {
    final zone = tz.getLocation(location.timezoneId);
    final localNow = tz.TZDateTime.now(zone);
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final tomorrow =
        DateTime(localNow.year, localNow.month, localNow.day + 1);

    return PrayerTimeSnapshot(
      location: location,
      settings: settings,
      today: _calculator.calculate(
        location: location,
        settings: settings,
        localDate: today,
      ),
      tomorrow: _calculator.calculate(
        location: location,
        settings: settings,
        localDate: tomorrow,
      ),
      updatedAt: DateTime.now().toUtc(),
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
      final latest = await _locations.getLastKnown();
      if (latest != null) {
        await _applyLocationIfNeeded(cached, latest);
      }
      final current = await _locations.getCurrent();
      await _applyLocationIfNeeded(
        state.valueOrNull ?? cached,
        current,
      );
    } catch (_) {
      // Keep the valid cached schedule when a silent refresh cannot complete.
    }
  }

  Future<void> _applyLocationIfNeeded(
    PrayerTimeSnapshot baseline,
    PrayerLocation location,
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
          settings: baseline.settings,
          today: baseline.today,
          tomorrow: baseline.tomorrow,
          updatedAt: baseline.updatedAt,
        ),
      );
      return;
    }

    await _persist(
      await _calculate(
        location: location,
        settings: baseline.settings,
      ),
    );
  }

  Future<bool> useCurrentLocation() async {
    ref.read(prayerTimeRefreshProvider.notifier).state = true;
    try {
      final location = await _locations.getCurrent();
      final settings = state.valueOrNull?.settings ?? _defaultSettings();
      await _persist(
        await _calculate(location: location, settings: settings),
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
      final settings = state.valueOrNull?.settings ?? _defaultSettings();
      await _persist(
        await _calculate(location: location, settings: settings),
      );
      return true;
    } catch (error, stack) {
      if (state.valueOrNull == null && ref.mounted) {
        state = AsyncError(error, stack);
      }
      return false;
    } finally {
      ref.read(prayerTimeRefreshProvider.notifier).state = false;
    }
  }

  Future<bool> updateSettings(PrayerSettings settings) async {
    final current = state.valueOrNull;
    if (current == null) return false;
    ref.read(prayerTimeRefreshProvider.notifier).state = true;
    try {
      await _persist(
        await _calculate(
          location: current.location,
          settings: settings,
        ),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      ref.read(prayerTimeRefreshProvider.notifier).state = false;
    }
  }

  Future<bool> refreshSchedule() async {
    final current = state.valueOrNull;
    if (current == null) return false;
    ref.read(prayerTimeRefreshProvider.notifier).state = true;
    try {
      await _persist(
        await _calculate(
          location: current.location,
          settings: current.settings,
        ),
      );
      return true;
    } finally {
      ref.read(prayerTimeRefreshProvider.notifier).state = false;
    }
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null || current.location.source != PrayerLocationSource.current) {
      return;
    }
    await _silentRefresh(current);
  }
}
