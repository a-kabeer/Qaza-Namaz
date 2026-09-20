# Global Prayer Times Module — V1 Tracking

Status: **Implementation complete — CI run #1487 pending**
Branch: `feature/global-prayer-times-v1`
Started: 2026-09-20
Scope: Global Prayer Times only. This tracker is intentionally separate from all existing project/tracking documents.

## Objective

Deliver a globally usable Prayer Times feature with foreground device location, searchable manual city selection, optional manual coordinates, coordinate-based AlAdhan calculation, calculation/Asr settings, local cache, offline fallback, current/next prayer and countdown, skeleton loading, light/dark theme, RTL, privacy-safe location handling, and automated tests.

## Architecture

```
Prayer Times UI
      ↓
Riverpod Controller
      ↓
PrayerTimesRepository
      ↓
PrayerProvider
      ↓
AlAdhanProvider
      ↓
Local Cache
```

Location services are kept behind module interfaces and are not coupled to Qaza services, Qaza repositories, Qaza records, the Qaza calendar engine, or the sync stack.

## Dedicated module files

- [x] Domain models and enums
- [x] Prayer provider abstraction
- [x] AlAdhan provider
- [x] Local SharedPreferences cache
- [x] Prayer repository
- [x] Device location service
- [x] Manual city search provider
- [x] Riverpod controller/state
- [x] Prayer Times screen
- [x] Location picker screen
- [x] Schedule/current-next calculation
- [x] Navigation entry
- [x] Localization-aware module strings
- [x] Automated tests

## Implementation checklist

### 1. Architecture + models
- [x] PrayerLocation
- [x] PrayerDay
- [x] PrayerTime
- [x] Hijri date model
- [x] PrayerSettings
- [x] CalculationMethod
- [x] AsrMethod
- [x] Cache key/request model
- [x] Current/next prayer result

### 2. Location
- [x] Foreground-only device location
- [x] Location service disabled state
- [x] Permission denied state
- [x] Permission permanently denied state
- [x] Approximate/reduced accuracy handling
- [x] Precise accuracy handling
- [x] Accuracy validation
- [x] Reverse geocoding
- [x] Graceful reverse-geocode failure
- [x] Manual city search
- [x] Manual coordinate input under Advanced
- [x] No background location permission/tracking

### 3. Prayer calculation
- [x] Provider abstraction
- [x] AlAdhan timing request
- [x] Coordinate validation
- [x] Calculation Method support
- [x] Standard Asr
- [x] Hanafi Asr
- [x] Timezone parsing
- [x] Hijri date parsing
- [x] Robust/invalid API response handling

### 4. Cache/offline
- [x] Persist selected PrayerLocation
- [x] Persist PrayerSettings
- [x] Cache PrayerDay by location/date/method/Asr
- [x] Immediate cache display
- [x] Background refresh
- [x] Offline-with-cache state
- [x] No-cache offline state
- [x] No Firebase/analytics storage of precise coordinates

### 5. UX
- [x] First-time Use My Location / Choose Manually
- [x] Today's prayer times
- [x] Current prayer
- [x] Next prayer
- [x] Countdown
- [x] Gregorian primary date
- [x] Hijri secondary date
- [x] Change Location
- [x] Calculation settings
- [x] Skeleton/shimmer loading
- [x] Refreshing state
- [x] Clear API/location errors
- [x] Dark/light theme
- [x] RTL
- [x] Small-screen layout

### 6. Testing
- [x] Models/serialization
- [x] AlAdhan parser
- [x] Repository cache/fetch behavior
- [x] Location state handling via fakes
- [x] City search parsing
- [x] Current/next prayer logic
- [ ] Offline fallback (CI verification pending)
- [x] Calculation method variants
- [x] Standard/Hanafi request parameters
- [ ] Timezone/DST coverage (CI verification pending)
- [ ] High-latitude response handling (CI verification pending)
- [ ] Widget/loading/error states (CI verification pending)
- [ ] RTL/theme smoke coverage (CI verification pending)

### 7. CI / release verification
- [ ] Flutter analyze (CI verification pending)
- [ ] Flutter tests (CI verification pending)
- [ ] Android debug build (CI verification pending)
- [ ] PR CI green (pending)
- [x] No unrelated existing tracking documents modified

## V1 explicit exclusions

- [ ] No automatic travel/location-change detection
- [ ] No background location tracking
- [ ] No prayer notifications
- [ ] No monthly calendar
- [ ] No multiple saved locations
- [ ] No travel mode
- [ ] No mosque timetable comparison
- [ ] No advanced astronomical adjustment controls
- [ ] No location history

## Privacy checklist

- Precise coordinates may be used in the prayer API request because coordinates are required for coordinate-based calculation.
- Precise coordinates must not be written to analytics events.
- Precise coordinates must not be uploaded to Firebase as a product feature.
- No background location access is requested.
- Manual location selection always remains available.

## External services

- **AlAdhan**: prayer-time calculation.
- **Open-Meteo / GeoNames data**: global city search.
- Native geocoding: device-coordinate reverse geocoding where available.

## Definition of done

The module is complete when the feature can be opened without touching Qaza business logic, obtain or manually select a location, calculate today's times for multiple global methods and Asr schools, survive offline/API failures through cache, render correctly in both supported locales/themes/RTL, and pass the dedicated test suite plus repository CI.

## Change log

### 2026-09-20
- Latest verification: PR #48 CI run #1487 is pending for current head `522b76d700f0786db6568b5813fe27230c7f1987`. Earlier superseded runs were automatically cancelled after fixes.
- The controller was checked for stale lifecycle/dead-code references; none remain.
- Implemented the V1 application layers and dedicated tests on the isolated branch.
- Added Prayer Times navigation without changing existing tracking documents.
- Added global AlAdhan calculation-method catalog and Standard/Hanafi school mapping.
- Added Open-Meteo/GeoNames city search with attribution text.
- Added foreground-only Android location permissions; no background location permission.

### 2026-09-20
- Created isolated branch `feature/global-prayer-times-v1`.
- CI requested through PR #48; latest workflow run is #1487 and remains pending in GitHub Actions.
- Created this dedicated tracker.
- Added foreground location and HTTP dependencies.
- Added Android fine/coarse foreground location permissions only.
