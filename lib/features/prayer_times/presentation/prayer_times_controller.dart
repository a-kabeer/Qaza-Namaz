import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone_country/timezone_country.dart';

import '../data/location/city_search_provider.dart';
import '../data/prayer_times_notification_service.dart';
import '../data/prayer_times_preferences.dart';
import '../domain/qaza_restriction_service.dart';
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
  calculationError,
  locationError,
}

class PrayerTimesState {
  const PrayerTimesState({
    this.status = PrayerTimesStatus.noLocation,
    this.location,
    this.settings = const PrayerSettings(),
    this.notificationSettings = const PrayerNotificationSettings(),
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
  final PrayerNotificationSettings notificationSettings;
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
    PrayerNotificationSettings? notificationSettings,
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
      notificationSettings: notificationSettings ?? this.notificationSettings,
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
  late final PrayerTimesPreferences _preferences;
  late final PrayerTimesNotificationService _notificationService;
  late final PrayerLocationService _locationService;
  late final CitySearchProvider _citySearchProvider;
  late final PrayerTimesClock _clock;
  late final Connectivity _connectivity;

  Timer? _citySearchDebounce;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool? _lastHasConnectivity;
  int _loadGeneration = 0;
  int _searchGeneration = 0;
  bool _isMounted = true;

  @override
  PrayerTimesState build() {
    _repository = ref.read(prayerTimesRepositoryProvider);
    _preferences = ref.read(prayerTimesPreferencesProvider);
    _notificationService = ref.read(prayerTimesNotificationServiceProvider);
    _locationService = ref.read(prayerLocationServiceProvider);
    _citySearchProvider = ref.read(prayerCitySearchProvider);
    _clock = ref.read(prayerTimesClockProvider);
    _connectivity = ref.read(prayerTimesConnectivityProvider);

    ref.onDispose(() {
      _isMounted = false;
      _citySearchDebounce?.cancel();
      _connectivitySubscription?.cancel();
    });

    _watchConnectivity();
    unawaited(_restore());
    return const PrayerTimesState();
  }

  void _watchConnectivity() {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      final hasConnectivity = results.any(
        (result) => result != ConnectivityResult.none,
      );
      final previous = _lastHasConnectivity;
      _lastHasConnectivity = hasConnectivity;

      if (previous == null || previous == hasConnectivity) return;
      if (_isMounted && state.location != null) {
        unawaited(_loadToday());
      }
    });

    unawaited(_primeConnectivityState());
  }

  Future<void> _primeConnectivityState() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (!_isMounted) return;
      _lastHasConnectivity = results.any(
        (result) => result != ConnectivityResult.none,
      );
    } catch (_) {
      _lastHasConnectivity = false;
    }
  }

  Future<void> _restore() async {
    var location = await _repository.getSavedLocation();
    final settings = await _repository.getSavedSettings();
    PrayerNotificationSettings notificationSettings;
    try {
      notificationSettings = await _preferences.getNotificationSettings();
    } catch (_) {
      notificationSettings = const PrayerNotificationSettings();
    }

    if (!_isMounted) return;

    if (location == null) {
      state = state.copyWith(
        status: PrayerTimesStatus.noLocation,
        settings: settings,
        notificationSettings: notificationSettings,
      );
      return;
    }

    if (location.timezone == null || location.timezone!.isEmpty) {
      final timezone = TimezoneConvert.nearestTimezone(
        location.latitude,
        location.longitude,
        countryCode: location.countryCode,
      );
      if (timezone != null) {
        location = location.copyWith(timezone: timezone);
        await _repository.saveLocation(location);
      }
    }

    if (!_isMounted) return;
    state = state.copyWith(
      location: location,
      settings: settings,
      notificationSettings: notificationSettings,
      status: PrayerTimesStatus.loading,
      clearMessage: true,
      clearLocationErrorKind: true,
      clearTomorrow: true,
    );
    await _loadToday();
  }

  Future<void> openRelevantSettings() async {
    final kind = state.locationErrorKind;
    if (kind == PrayerLocationErrorKind.permissionPermanentlyDenied) {
      await _locationService.openAppSettings();
      return;
    }
    await _locationService.openLocationSettings();
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
      _syncScheduledNotifications();
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
    final timezone = result.timezone ??
        TimezoneConvert.nearestTimezone(
          result.latitude,
          result.longitude,
          countryCode: result.countryCode,
        );

    final location = PrayerLocation(
      latitude: result.latitude,
      longitude: result.longitude,
      country: result.country,
      city: result.name,
      region: result.region,
      countryCode: result.countryCode,
      timezone: timezone,
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
    _syncScheduledNotifications();
  }

  Future<void> useManualCoordinates(
    String latitudeText,
    String longitudeText,
  ) async {
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

    final timezone = TimezoneConvert.nearestTimezone(latitude, longitude);
    if (timezone == null) {
      throw const FormatException(
        'Unable to resolve a timezone for these coordinates.',
      );
    }

    final location = PrayerLocation(
      latitude: latitude,
      longitude: longitude,
      timezone: timezone,
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
    _syncScheduledNotifications();
  }

  void searchCities(String query, {String? countryCode}) {
    _citySearchDebounce?.cancel();
    final generation = ++_searchGeneration;
    final normalized = query.trim();

    final hasCountryFilter =
        countryCode != null && countryCode.trim().isNotEmpty;
    if (normalized.length < 2 && !hasCountryFilter) {
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
      const Duration(milliseconds: 180),
      () => unawaited(_searchCities(normalized, generation, countryCode)),
    );
  }

  Future<void> _searchCities(String query, int generation, String? countryCode) async {
    try {
      final results = await _citySearchProvider.searchInCountry(
        query,
        countryCode: countryCode,
      );
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
        citySearchError: 'Offline city search failed.',
      );
    }
  }



  void _syncScheduledNotifications() {
    final location = state.location;
    if (location == null || !state.notificationSettings.anyEnabled) return;
    unawaited(_notificationService.sync(
      location: location,
      settings: state.settings,
      notifications: state.notificationSettings,
    ));
  }

  Future<bool> setPrayerNotification(PrayerName prayer, bool enabled) async {
    if (enabled) {
      final granted = await _notificationService.requestPermission();
      if (!granted) return false;
    }
    final prayers = Set<PrayerName>.from(state.notificationSettings.enabledPrayers);
    if (enabled) {
      prayers.add(prayer);
    } else {
      prayers.remove(prayer);
    }
    await _saveNotificationSettings(state.notificationSettings.copyWith(
      enabledPrayers: Set.unmodifiable(prayers),
    ));
    return true;
  }

  Future<bool> setRestrictedNotification(RestrictionType type, bool enabled) async {
    if (enabled) {
      final granted = await _notificationService.requestPermission();
      if (!granted) return false;
    }
    final current = state.notificationSettings;
    final updated = switch (type) {
      RestrictionType.sunrise => current.copyWith(sunrise: enabled),
      RestrictionType.zawal => current.copyWith(zawal: enabled),
      RestrictionType.sunset => current.copyWith(sunset: enabled),
      RestrictionType.otherConfiguredRestriction => current,
    };
    await _saveNotificationSettings(updated);
    return true;
  }

  Future<void> setRestrictedLeadMinutes(int minutes) async {
    if (minutes != 0 && minutes != 5 && minutes != 10) return;
    await _saveNotificationSettings(state.notificationSettings.copyWith(
      restrictedLeadMinutes: minutes,
    ));
  }

  Future<void> _saveNotificationSettings(PrayerNotificationSettings settings) async {
    await _preferences.saveNotificationSettings(settings);
    if (!_isMounted) return;
    state = state.copyWith(notificationSettings: settings);
    final location = state.location;
    if (location == null) return;
    unawaited(_notificationService.sync(
      location: location,
      settings: state.settings,
      notifications: settings,
    ));
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
      status: state.hasData
          ? PrayerTimesStatus.refreshing
          : PrayerTimesStatus.loading,
      clearMessage: true,
      clearTomorrow: true,
    );
    await _loadToday();
    _syncScheduledNotifications();
  }

  Future<void> refresh() async {
    if (state.location == null) {
      await _restore();
      return;
    }
    await _loadToday();
  }

  Future<void> tick() async {
    final location = state.location;
    final today = state.today;
    if (location == null || today == null) return;

    final currentDate = _dateForLocation(location);
    if (_dateKey(currentDate) != _dateKey(today.date)) {
      unawaited(_loadToday());
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

    state = state.copyWith(
      status: state.hasData
          ? PrayerTimesStatus.refreshing
          : PrayerTimesStatus.loading,
      clearMessage: true,
      clearTomorrow: true,
    );

    try {
      final day = await _repository.getPrayerTimes(
        latitude: location.latitude,
        longitude: location.longitude,
        date: date,
        method: settings.calculationMethod,
        asrMethod: settings.asrMethod,
        timezone: location.timezone,
      );

      if (!_isMounted || generation != _loadGeneration) return;

      final updatedLocation = location.timezone == day.timezone
          ? location
          : location.copyWith(timezone: day.timezone);

      if (updatedLocation.timezone != location.timezone) {
        await _repository.saveLocation(updatedLocation);
      }

      state = state.copyWith(
        location: updatedLocation,
        today: day,
        status: PrayerTimesStatus.loaded,
        clearMessage: true,
      );

      await _loadTomorrowIfRequired(day);
    } catch (error) {
      if (!_isMounted || generation != _loadGeneration) return;
      state = state.copyWith(
        status: PrayerTimesStatus.calculationError,
        message: error.toString(),
      );
    }
  }

  Future<void> _loadTomorrowIfRequired(PrayerDay day) async {
    final schedule = PrayerSchedule.evaluate(
      today: day,
      nowOverride: _clock.now(),
    );
    if (schedule.next != null) return;
    await _loadTomorrow(day);
  }

  Future<void> _loadTomorrow(PrayerDay day) async {
    final location = state.location;
    if (location == null || location.timezone == null) return;

    final tomorrowDate =
        DateTime(day.date.year, day.date.month, day.date.day + 1);
    final settings = state.settings;

    try {
      final tomorrow = await _repository.getPrayerTimes(
        latitude: location.latitude,
        longitude: location.longitude,
        date: tomorrowDate,
        method: settings.calculationMethod,
        asrMethod: settings.asrMethod,
        timezone: location.timezone,
      );

      if (_isMounted) {
        state = state.copyWith(tomorrow: tomorrow);
      }
    } catch (_) {}
  }

  DateTime _dateForLocation(PrayerLocation location) {
    final timezone = location.timezone;
    if (timezone != null && timezone.isNotEmpty) {
      return PrayerSchedule.localDate(timezone, instant: _clock.now());
    }

    final now = _clock.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';
}
