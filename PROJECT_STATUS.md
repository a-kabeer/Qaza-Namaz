# Qaza-Namaz — Current Project Status

## Phase 0

**Status: complete for repository/CI evidence.**

The baseline SHA, toolchain versions, package/application identity, repository audit, cleanup/archive work, known CI constraints, and offline architecture policy are recorded in this project.

## Phase 1 — Pure Offline Production Core

**Status: implementation complete; closure gate active in PR #263.**

The implementation now uses:
- Drift/SQLite as the business-data authority.
- SharedPreferences only for presentation settings.
- Local JSON backup/export/import.
- Prevalidated atomic restore.
- Monotonic local database revisions.
- Local database onboarding routing.
- Offline location/prayer-time capabilities.

Cloud/authentication runtime dependencies are prohibited by the offline architecture checker.

## Remaining release certification outside code

Manual device acceptance remains necessary for:
- full navigation journey
- GPS/location permission behavior
- prayer-time/location-service behavior
- restore UX on a real device
- accessibility matrix
- large-data performance
- signed production artifact installation

These are release certification tasks, not prerequisites for the offline architecture itself.
