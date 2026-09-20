# Global Prayer Times Module — V1 Tracking

Status: **In progress**
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

- [ ] Domain models and enums
- [ ] Prayer provider abstraction
- [ ] AlAdhan provider
- [ ] Local SharedPreferences cache
- [ ] Prayer repository
- [ ] Device location service
- [ ] Manual city search provider
- [ ] Riverpod controller/state
- [ ] Prayer Times screen
- [ ] Location picker screen
- [ ] Schedule/current-next calculation
- [ ] Navigation entry
- [ ] Localization-aware module strings
- [ ] Automated tests

## Implementation checklist

### 1. Architecture + models
- [ ] PrayerLocation
- [ ] PrayerDay
- [ ] PrayerTime
- [ ] Hijri date model
- [ ] PrayerSettings
- [ ] CalculationMethod
- [ ] AsrMethod
- [ ] Cache key/request model
- [ ] Current/next prayer result

### 2. Location
- [ ] Foreground-only device location
- [ ] Location service disabled state
- [ ] Permission denied state
- [ ] Permission permanently denied state
- [ ] Approximate/reduced accuracy handling
- [ ] Precise accuracy handling
- [ ] Accuracy validation
- [ ] Reverse geocoding
- [ ] Graceful reverse-geocode failure
- [ ] Manual city search
- [ ] Manual coordinate input under Advanced
- [ ] No background location permission/tracking

### 3. Prayer calculation
- [ ] Provider abstraction
- [ ] AlAdhan timing request
- [ ] Coordinate validation
- [ ] Calculation Method support
- [ ] Standard Asr
- [ ] Hanafi Asr
- [ ] Timezone parsing
- [ ] Hijri date parsing
- [ ] Robust/invalid API response handling

### 4. Cache/offline
- [ ] Persist selected PrayerLocation
- [ ] Persist PrayerSettings
- [ ] Cache PrayerDay by location/date/method/Asr
- [ ] Immediate cache display
- [ ] Background refresh
- [ ] Offline-with-cache state
- [ ] No-cache offline state
- [ ] No Firebase/analytics storage of precise coordinates

### 5. UX
- [ ] First-time Use My Location / Choose Manually
- [ ] Today's prayer times
- [ ] Current prayer
- [ ] Next prayer
- [ ] Countdown
- [ ] Gregorian primary date
- [ ] Hijri secondary date
- [ ] Change Location
- [ ] Calculation settings
- [ ] Skeleton/shimmer loading
- [ ] Refreshing state
- [ ] Clear API/location errors
- [ ] Dark/light theme
- [ ] RTL
- [ ] Small-screen layout

### 6. Testing
- [ ] Models/serialization
- [ ] AlAdhan parser
- [ ] Repository cache/fetch behavior
- [ ] Location state handling via fakes
- [ ] City search parsing
- [ ] Current/next prayer logic
- [ ] Offline fallback
- [ ] Calculation method variants
- [ ] Standard/Hanafi request parameters
- [ ] Timezone/DST coverage
- [ ] High-latitude response handling
- [ ] Widget/loading/error states
- [ ] RTL/theme smoke coverage

### 7. CI / release verification
- [ ] Flutter analyze
- [ ] Flutter tests
- [ ] Android debug build
- [ ] PR CI green
- [ ] No unrelated existing tracking documents modified

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
- Created isolated branch `feature/global-prayer-times-v1`.
- Created this dedicated tracker.
- Added foreground location and HTTP dependencies.
- Added Android fine/coarse foreground location permissions only.
