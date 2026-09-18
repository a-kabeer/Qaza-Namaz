# Qaza Namaz — Architecture

The canonical description of how the application is layered. Feature documents
(`DATABASE_ARCHITECTURE.md`, `NAVIGATION_FLOW.md`, `QAZA_BUSINESS_LOGIC.md`,
`GREGORIAN_HIJRI_CALENDAR.md`, `OFFLINE_FIRST_ARCHITECTURE.md`) expand on
individual areas; this file is the map.

## Dependency boundary

```text
Widgets (lib/features/**, lib/core/widgets/**)
  │  watch/read providers only
  ▼
Riverpod controllers (lib/app/providers.dart + feature controllers)
  ▼
QazaService (lib/domain/services/qaza_service.dart)
  │  composes QazaAvailabilityService (pure domain rules)
  ▼
QazaRepository (lib/domain/repositories/qaza_repository.dart)
  │  OfflineFirstQazaRepository ── remote ──▶ FirestoreQazaRepository
  ▼  (local)
QazaLocalStore ──▶ DriftQazaLocalStore
  ▼
QazaRecordsDao · SyncOutboxDao
  ▼
AppDatabase (Drift / SQLite)
```

No widget imports `data/local/**`, `data/repositories/**` or any Drift symbol.
Every dependency is constructed in `lib/app/providers.dart`; no feature builds a
repository, DAO or database of its own.

### Never

- Widget → DAO, or Widget → database.
- Widget → SharedPreferences for ledger data.
- A second duplicate-checking algorithm, calendar engine, calculation engine or
  Qaza storage model.
- Home or History reading the full ledger.

### Intentionally isolated

| Path | Why |
| --- | --- |
| `data/migration/**` | one-shot legacy import, runs below the service boundary |
| `features/auth/auth_gate.dart` | auth lifecycle only |
| `features/calculator/calculator_persistence.dart` | calculator *inputs*, not records |
| `features/notifications/notification_controller.dart` | reminder settings, not records |
| `features/knowledge_base/**` | self-contained content pipeline, no Qaza business logic |

## Controllers

Workflow and business state lives in Riverpod, not in widgets. `setState` is
reserved for ephemeral presentation state.

| Controller | Owns |
| --- | --- |
| `CalendarController` | date selection mode, canonicalization, range expansion |
| `AddQazaFlowController` | the three-step Add Qaza workflow |
| `CalculatorController` | calculator inputs, validation, result, persistence, preflight, tracker insert |
| `QazaTrackerController` | filters, bounded pages, selection, bulk completion |
| `HistoryLogsNotifier` | paginated logs |
| `NotificationSettingsNotifier` | reminder settings and scheduling |
| `ThemeModeNotifier` / `LocaleNotifier` | persisted appearance and language |

## Single sources of truth

| Concept | Source |
| --- | --- |
| Qaza identity | `userId + normalized Gregorian date + prayerType` |
| Calendar selection | Gregorian; Hijri is derived display only |
| Date normalization | `QazaDate` |
| Duplicate/conflict rules | `QazaAvailabilityService` |
| Business boundary | `QazaService` |
| Local persistence | Drift/SQLite |
| Authentication identity | Firebase UID |
| Prayer names shown to users | `PrayerTypeL10n.localizedLabel` |

## Scalability rules

Home uses database aggregates. The Qaza workspace and History use keyset
pagination with bounded page sizes. Completion uses a bounded oldest-pending
lookup. Availability is scoped to the requested dates and prayers. Bulk
completion is repository-driven. No production path materializes the full
ledger.

## Localization

Generated resources (`lib/l10n/*.arb` → `flutter gen-l10n`) with English and
Urdu; Arabic needs only an `app_ar.arb`. `localeProvider` persists the choice.
Text direction comes from Flutter's `Directionality` for the active locale, not
from per-widget handling.
