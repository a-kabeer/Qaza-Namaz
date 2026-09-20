import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/location/city_search_provider.dart';
import '../data/location/prayer_location_service.dart';
import '../domain/prayer_schedule.dart';
import '../domain/prayer_times_models.dart';
import '../domain/prayer_times_repository.dart';
import '../prayer_times_providers.dart';

enum PrayerTimesStatus {
  noLocation,
  locating,
  loading,
  loaded,
  refreshing,
  offlineWithCache,
  apiError,
  locationError,
}

class PrayerTimesState {
  const PrayerTimesState({
    this.status = PrayerTimesStatus.noLocation,
    this.location,
    this.settings = const PrayerSettings(),
    this.today,
    this.tomorrow,
    this.message,
    this.locationErrorKind,
    this.cityResults = const <CitySearchResult>[],
    this.citySearchLoading = false,
    this.citySearchError,
  });

  final PrayerTimesStatus status;
  final PrayerLocation? location;
  final PrayerSettings settings;
  final PrayerDay? today;
  final PrayerDay? tomorrow;
  final String? message;
  final PrayerLocationErrorKind? locationErrorKind;
  final List<CitySearchResult> cityResults;
  final bool citySearchLoading;
  final String? citySearchError;

  PrayerTimesState copyWith({
    PrayerTimesStatus? status,
    PrayerLocation? location,
    PrayerSettings? settings,
    PrayerDay? today,
    PrayerDay? tomorrow,
    bool clearTomorrow = false,
    String? message,
    bool clearMessage = false,
    PrayerLocationErrorKind? locationErrorKind,
    bool clearLocationErrorKind = false,
    List<CitySearchResult>? cityResults,
    bool? citySearchLoading,
    String? citySearchError,
    bool clearCitySearchError = false,
  }) {
    return PrayerTimesState(
      status: status ?? this.status,
      location: location ?? this.location,
      settings: settings ?? this.settings,
      today: today ?? this.today,
      tomorrow: clearTomorrow ? null : (tomorrow ?? this.tomorrow),
      message: clearMessage ? null : (message ?? this.message),
      locationErrorKind: clearLocationErrorKind
          ? null
          : (locationErrorKind ?? this.locationErrorKind),
      cityResults: cityResults ?? this.cityResults,
      citySearchLoading: citySearchLoading ?? this.citySearchLoading,
      citySearchError:
          clearCitySearchError ? null : (citySearchError ?? this.citySearchError),
    );
  }

  bool get hasData => location != null && today != null;
}

class PrayerTimesController extends Notifier<PrayerTimesState> {
  late final PrayerTimesRepository _repository;
  late final PrayerLocationService _locationService;
  late final CitySearchProvider _citySearchProvider;

  Timer? _citySearchDebounce;
  int _loadGeneration = 0;
  int _searchGeneration = 0;
  bool _isMounted = true;

  @override
  PrayerTimesState build() {
    _repository = ref.read(prayerTimesRepositoryProvider);
    _locationService = ref.read(prayerLocationServiceProvider);
    _citySearchProvider = ref.read(prayerCitySearchProvider);

    ref.onDispose(() {
      _isMounted = false;
      _citySearchDebounce?.cancel();
    });

    unawaited(_restore());
    return const PrayerTimesState();
  }

  Future<void> _restore() async {
    final location = await _repository.getSavedLocation();
    final settings = await _repository.getSavedSettings();

    if (!_isMounted) return;

    if (location == null) {
      state = state.copyWith(
        status: PrayerTimesStatus.noLocation,
        settings: settings,
      );
      return;
    }

    state = state.copyWith(
      location: location,
      settings: settings,
      status: PrayerTimesStatus.loading,
      clearMessage: true,
      clearLocationErrorKind: true,
    );
    await _loadToday();
  }

  Future<void> useMyLocation() async {
    state = state.copyWith(
      status: PrayerTimesStatus.locating,
      clearMessage: true,
      clearLocationErrorKind: true,
    );

    try {
      final location = await _locationService.getCurrentLocation();
      await _repository.saveLocation(location);
      if (!_isMounted) return;

      state = state.copyWith(
        location: location,
        status: PrayerTimesStatus.loading,
        clearMessage: true,
        clearLocationErrorKind: true,
        clearTomorrow: true,
      );
      await _loadToday();
    } on PrayerLocationException catch (error) {
      if (!_isMounted) return;
      state = state.copyWith(
        status: PrayerTimesStatus.locationError,
        message: error.message,
        locationErrorKind: error.kind,
      );
    } catch (_) {
      if (!_isMounted) return;
      state = state.copyWith(
        status: PrayerTimesStatus.locationError,
        clearMessage: true,
        locationErrorKind: PrayerLocationErrorKind.positionUnavailable,
      );
    }
  }

  Future<void> selectCity(CitySearchResult result) async {
    final location = PrayerLocation(
      latitude: result.latitude,
      longitude: result.longitude,
      country: result.country,
      city: result.name,
      region: result.region,
      countryCode: result.countryCode,
      timezone: result.timezone,
      source: LocationSource.manualCity,
    );

    await _repository.saveLocation(location);
    if (!_isMounted) return;

    state = state.copyWith(
      location: location,
      status: PrayerTimesStatus.loading,
      clearMessage: true,
      clearLocationErrorKind: true,
      clearTomorrow: true,
      cityResults: const <CitySearchResult>[],
    );
    await _loadToday();
  }

  Future<void> useManualCoordinates(String latitudeText, String longitudeText) async {
    final latitude = double.tryParse(latitudeText.trim());
    final longitude = double.tryParse(longitudeText.trim());

    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      throw const FormatException('Invalid coordinates.');
    }

    final location = PrayerLocation(
      latitude: latitude,
      longitude: longitude,
      source: LocationSource.manualCoordinates,
    );

    await _repository.saveLocation(location);
    if (!_isMounted) return;

    state = state.copyWith(
      location: location,
      status: PrayerTimesStatus.loading,
      clearMessage: true,
      clearLocationErrorKind: true,
      clearTomorrow: true,
    );
    await _loadToday();
  }

  void searchCities(String query) {
    _citySearchDebounce?.cancel();
    final generation = ++_searchGeneration;
    final normalized = query.trim();

    if (normalized.length < 2) {
      state = state.copyWith(
        cityResults: const <CitySearchResult>[],
        citySearchLoading: false,
        clearCitySearchError: true,
      );
      return;
    }

    state = state.copyWith(
      citySearchLoading: true,
      clearCitySearchError: true,
    );

    _citySearchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_searchCities(normalized, generation)),
    );
  }

  Future<void> _searchCities(String query, int generation) async {
    try {
      final results = await _citySearchProvider.search(query);
      if (!_isMounted || generation != _searchGeneration) return;
      state = state.copyWith(
        cityResults: results,
        citySearchLoading: false,
        clearCitySearchError: true,
      );
    } catch (_) {
      if (!_isMounted || generation != _searchGeneration) return;
      state = state.copyWith(
        cityResults: const <CitySearchResult>[],
        citySearchLoading: false,
        citySearchError: 'City search failed.',
      );
    }
  }

  Future<void> setCalculationMethod(CalculationMethod method) async {
    await saveSettings(state.settings.copyWith(calculationMethod: method));
  }

  Future<void> setAsrMethod(AsrMethod method) async {
    await saveSettings(state.settings.copyWith(asrMethod: method));
  }

  Future<void> saveSettings(PrayerSettings settings) async {
    await _repository.saveSettings(settings);
    if (!_isMounted) return;

    state = state.copyWith(
      settings: settings,
      clearMessage: true,
      clearTomorrow: true,
    );
    await _loadToday();
  }

  Future<void> openRelevantSettings() async {
    if (state.locationErrorKind == PrayerLocationErrorKind.serviceDisabled) {
      await _locationService.openLocationSettings();
    } else {
      await _locationService.openAppSettings();
    }
  }

  Future<void> refresh() async {
    if (state.location == null) return;
    await _loadToday();
  }

  Future<void> tick() async {
    final location = state.location;
    final today = state.today;
    if (location == null || today == null) return;

    final currentDate = _dateForLocation(location);
    if (_dateKey(currentDate) != _dateKey(today.date)) {
      unawaited(_loadToday());
      return;
    }

    if (state.tomorrow == null) {
      final schedule = PrayerSchedule.evaluate(today: today);
      if (schedule.next == null) {
        unawaited(_loadTomorrow(today));
      }
    }
  }

  Future<void> _loadToday() async {
    final location = state.location;
    if (location == null) {
      state = state.copyWith(status: PrayerTimesStatus.noLocation);
      return;
    }

    final generation = ++_loadGeneration;
    final date = _dateForLocation(location);
    final settings = state.settings;
    final request = PrayerTimesRequest(
      latitude: location.latitude,
      longitude: location.longitude,
      date: date,
      method: settings.calculationMethod,
      asrMethod: settings.asrMethod,
    );

    PrayerDay? cached;
    try {
      cached = await _repository.getCachedPrayerTimes(request);
    } catch (_) {
      cached = null;
    }

    if (!_isMounted || generation != _loadGeneration) return;

    if (cached != null) {
      state = state.copyWith(
        status: PrayerTimesStatus.refreshing,
        today: cached,
        clearMessage: true,
      );
    } else {
      state = state.copyWith(
        status: PrayerTimesStatus.loading,
        clearMessage: true,
      );
    }

    try {
      final day = await _repository.getPrayerTimes(
        latitude: location.latitude,
        longitude: location.longitude,
        date: date,
        method: settings.calculationMethod,
        asrMethod: settings.asrMethod,
      );

      final updatedLocation = location.copyWith(timezone: day.timezone);
      await _repository.saveLocation(updatedLocation);

      if (!_isMounted || generation != _loadGeneration) return;

      state = state.copyWith(
        location: updatedLocation,
        today: day,
        status: PrayerTimesStatus.loaded,
        clearMessage: true,
      );

      await _loadTomorrowIfRequired(day);
    } catch (error) {
      if (!_isMounted || generation != _loadGeneration) return;

      if (cached != null) {
        state = state.copyWith(
          today: cached,
          status: PrayerTimesStatus.offlineWithCache,
          clearMessage: true,
        );
      } else {
        state = state.copyWith(
          status: PrayerTimesStatus.apiError,
          clearMessage: true,
        );
      }
    }
  }

  Future<void> _loadTomorrowIfRequired(PrayerDay day) async {
    final schedule = PrayerSchedule.evaluate(today: day);
    if (schedule.next != null) return;
    await _loadTomorrow(day);
  }

  Future<void> _loadTomorrow(PrayerDay day) async {
    final location = state.location;
    if (location == null) return;

    final tomorrowDate =
        DateTime(day.date.year, day.date.month, day.date.day + 1);
    final settings = state.settings;
    final request = PrayerTimesRequest(
      latitude: location.latitude,
      longitude: location.longitude,
      date: tomorrowDate,
      method: settings.calculationMethod,
      asrMethod: settings.asrMethod,
    );

    try {
      final cached = await _repository.getCachedPrayerTimes(request);
      final tomorrow = cached ??
          await _repository.getPrayerTimes(
            latitude: location.latitude,
            longitude: location.longitude,
            date: tomorrowDate,
            method: settings.calculationMethod,
            asrMethod: settings.asrMethod,
          );

      if (_isMounted) {
        state = state.copyWith(tomorrow: tomorrow);
      }
    } catch (_) {
      // Tomorrow is an enhancement for the post-Isha countdown; today's
      // schedule remains fully usable when it cannot be fetched.
    }
  }

  DateTime _dateForLocation(PrayerLocation location) {
    final timezone = location.timezone;
    if (timezone != null && timezone.isNotEmpty) {
      return PrayerSchedule.now(timezone);
    }

    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

}
