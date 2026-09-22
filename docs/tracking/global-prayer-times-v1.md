# Global Prayer Times — Offline Implementation

Status: **Implemented on feature branch; CI validation pending**
Branch: `feature/offline-prayer-times`
Started: 2026-09-22

## Objective

Provide globally usable Prayer Times without a prayer-time network API. The existing Prayer Times UI, Riverpod controller flow, location picker, calculation settings, current/next prayer behavior, countdown, Gregorian/Hijri display, theme and localization are preserved.

## Architecture

```
Prayer Times UI
      ↓
Riverpod Controller
      ↓
PrayerTimesRepository
      ├── PrayerTimeCalculator
      │       ↓
      │   adhan_dart
      │
      └── PrayerTimesPreferences
              ↓
       Local location/settings

Qaza Tracker
      ↓
Offline Qaza Restriction Service
      ↓
Sunrise / Solar Noon / Sunset
      ↓
Existing bulk completion UI
```

## Offline stack

- `adhan_dart`: local astronomical prayer-time calculation.
- `geodb_flutter`: embedded city search and nearest-city lookup.
- `timezone_country`: local coordinate-to-IANA-timezone resolution.
- Existing `timezone`: DST-aware local-date/countdown handling.
- Existing `hijri`: local Hijri display.
- Existing `geolocator`: foreground device-location acquisition only.

## Removed network dependencies

The Prayer Times feature no longer uses:

- AlAdhan HTTP requests.
- Open-Meteo city-search HTTP requests.
- Network reverse geocoding.
- Daily API-result cache/fallback.

No prayer-time API fallback remains.

## Preserved behavior

- Foreground device location with permission/service error handling.
- Manual city selection.
- Manual coordinates.
- Calculation-method selection.
- Standard/Hanafi Asr selection.
- Current/next prayer and countdown.
- Gregorian primary date and local Hijri secondary date.
- Existing Prayer Times screen and navigation.
- English/Urdu behavior.
- Existing Qaza tracker selection and undo workflow.

## Restriction engine

The offline layer exposes:

`RestrictionType`:

- Sunrise
- Zawal
- Sunset
- OtherConfiguredRestriction

The current policy uses configurable sunrise, solar-noon and sunset windows. The restriction result includes active state, type, start/end, remaining duration and next allowed time.

Bulk Qaza completion is checked before any write. The existing Complete Selected action is disabled while a configured restriction is active.

## Location and timezone

City data carries coordinates and timezone locally. Device coordinates are enriched using the embedded city database and local timezone lookup. Manual coordinates resolve an IANA timezone locally before calculation.

The timezone used for the selected location remains the source for local-date, prayer and countdown behavior.

## Testing

Dedicated coverage includes:

- local Karachi prayer calculation;
- Standard vs Hanafi Asr;
- local timezone resolution;
- solar restriction evaluation;
- model serialization;
- controller state flow;
- offline city search;
- widget smoke coverage.

Repository CI additionally validates Flutter analysis, Linux/Windows tests, Firestore rules and Android builds.

## Definition of done

The migration is complete when CI is green, the feature contains no AlAdhan/Open-Meteo prayer references, and real-device airplane-mode testing confirms Prayer Times and restricted-Qaza behavior without network access.
