# TP-GEN Phase 2 Implementation Report: Schema Alignment & Actual Drift DAO Integration

> **Project:** Qaza Namaz (`com.qaza_namaz.com`)  
> **Status:** APPROVED & IMPLEMENTED (STRICT PHASE 2 ONLY)  
> **Architecture Decision:** Option A — PowerSync Unified Local Database with Drift ORM  
> **Date:** November 9, 2026  
> **Test Suite Health:** **814 / 814 Tests Passed (100%)**  
> **Static Analysis:** **0 Issues Found (Clean)**  

---

## 1. Executive Summary

Phase 2 of Option A has been successfully implemented and verified. In this phase:
1. The **PowerSync schema** (`lib/data/powersync/powersync_schema.dart`) was aligned with Drift's table schemas, including precise column types, nullability, indices, and the domain uniqueness requirement `(user_id, prayer_type, original_date)`.
2. The **Drift database engine** (`lib/data/local/database/app_database.dart`) was adapted via a dedicated constructor (`AppDatabase.forPowerSync`) to run over PowerSync's SQLite connection via `drift_sqlite_async`.
3. In this mode, Drift skips illegal view re-creations (`m.createAll()`), avoids attempting index or trigger creation on PowerSync SQLite views, and automatically initializes local-only schema tables (`local_accounts`, `meta_store`, `app_session_state`, `device_metadata`, `local_recovery_snapshots`, `workspace_sync_status`).
4. **DateTime serialization** was configured with `storeDateTimeAsText: true`, harmonizing Drift with PowerSync's ISO-8601 text representation across UTC, midnight, and leap years.
5. SQLite view execution constraints (such as `sqlite3_changes()` returning 0 on view `INSTEAD OF` triggers and `cannot UPSERT a view`) were solved inside `qaza_records_dao.dart` without mutating application-level semantics or domain calculations.
6. A comprehensive 15-scenario integration test suite (`test/data/powersync/powersync_phase2_dao_integration_test.dart`) was authored and passed 100%. The full project test suite (814 tests) passed with zero regressions.

> [!IMPORTANT]
> **Strict Phase 2 Boundary Enforced:** Production repository and Riverpod provider routings (`appDatabaseProvider`, `OfflineFirstQazaRepository`) remain untouched on their existing local Drift path. No live cloud synchronization streams or Supabase CRUD uploads have been activated.

---

## 2. Drift-to-PowerSync Schema Mapping & Classification

The Qaza Namaz schema contains 14 tables across domain ledgers, local device state, and workspace lifecycles. They are categorized as follows:

| # | Table Name | Synchronization Target | Classification | Reason & Handling |
|---|------------|------------------------|----------------|-------------------|
| 1 | `account_profiles` | Supabase Cloud | **PowerSync Synced** | Master user profile, calculation method, target, age. Synced across user devices. |
| 2 | `account_plan_revisions` | Supabase Cloud | **PowerSync Synced** | Plan history and calculation revisions for deterministic sync. |
| 3 | `qaza_additions` | Supabase Cloud | **PowerSync Synced** | Batch additions of missed prayers. |
| 4 | `qaza_records` | Supabase Cloud | **PowerSync Synced** | Core prayer ledger. PowerSync creates `ps_data__qaza_records` + `qaza_records` view. Unique constraint enforced on underlying table. |
| 5 | `daily_salah_logs` | Supabase Cloud | **PowerSync Synced** | Daily on-time salah check-ins. Unique on `(user_id, prayer_type, prayer_date)`. |
| 6 | `qaza_deletion_actions` | Supabase Cloud | **PowerSync Synced** | Tombstone records for multi-device deletion tracking. |
| 7 | `qaza_deletion_action_record_snapshots` | Supabase Cloud | **PowerSync Synced** | Historical snapshots of deleted Qaza rows for audit and restore. |
| 8 | `qaza_profile_plan_provenance` | Supabase Cloud | **PowerSync Synced** | Provenance records connecting plan revisions with user setup. |
| 9 | `user_preferences` | Supabase Cloud | **PowerSync Synced** | Multi-device persistent settings (targeting modes, reminder times). |
| 10 | `local_accounts` | Device Local | **Local-Only Drift** | Local device Google/Guest workspace records, auth tokens, and session state. Must never sync to cloud. |
| 11 | `meta_store` | Device Local | **Local-Only Drift** | Local key-value store (app version, migration flags, backup timestamps). Stays strictly local. |
| 12 | `app_session_state` | Device Local | **Local-Only Drift** | Current active workspace pointer and ephemeral session flags. |
| 13 | `device_metadata` | Device Local | **Local-Only Drift** | Device hardware IDs, OS versions, and push notification tokens. |
| 14 | `local_recovery_snapshots` | Device Local | **Local-Only Drift** | Local JSON rollbacks and diagnostic dumps. Kept local for privacy and safety. |

---

## 3. PowerSync Schema Alignment Details

In `lib/data/powersync/powersync_schema.dart`, the 9 cloud-synchronized tables are defined with exact data types, nullability, and query performance indices:

```dart
const Schema qazaPowerSyncSchema = Schema([
  Table('account_profiles', [
    Column.text('email'),
    Column.text('display_name'),
    Column.text('gender'),
    Column.text('calculation_method'),
    Column.text('madhab'),
    Column.integer('daily_target'),
    Column.text('birth_date'),
    Column.text('maturity_date'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ]),
  Table('account_plan_revisions', [
    Column.text('profile_id'),
    Column.integer('revision_number'),
    Column.text('summary_json'),
    Column.text('created_at'),
  ], indexes: [
    Index('idx_plan_rev_prof', [IndexedColumn('profile_id')]),
  ]),
  Table('qaza_additions', [
    Column.text('user_id'),
    Column.text('prayer_type'),
    Column.integer('count'),
    Column.text('notes'),
    Column.text('added_at'),
  ], indexes: [
    Index('idx_qaza_add_user', [IndexedColumn('user_id')]),
  ]),
  Table('qaza_records', [
    Column.text('user_id'),
    Column.text('prayer_type'),
    Column.text('original_date'),
    Column.text('status'),
    Column.text('completed_at'),
    Column.text('completion_id'),
    Column.integer('record_version'),
    Column.text('created_at'),
    Column.text('updated_at'),
  ], indexes: [
    Index('idx_qaza_rec_user_status', [
      IndexedColumn('user_id'),
      IndexedColumn('status'),
    ]),
    Index('idx_qaza_rec_lookup', [
      IndexedColumn('user_id'),
      IndexedColumn('prayer_type'),
      IndexedColumn('original_date'),
    ]),
    Index('idx_qaza_rec_completed_at', [
      IndexedColumn('user_id'),
      IndexedColumn('completed_at'),
    ]),
  ]),
  Table('daily_salah_logs', [
    Column.text('user_id'),
    Column.text('prayer_type'),
    Column.text('prayer_date'),
    Column.text('status'),
    Column.text('logged_at'),
    Column.text('qaza_record_id'),
  ], indexes: [
    Index('idx_daily_salah_lookup', [
      IndexedColumn('user_id'),
      IndexedColumn('prayer_date'),
      IndexedColumn('prayer_type'),
    ]),
  ]),
  Table('qaza_deletion_actions', [
    Column.text('user_id'),
    Column.text('reason'),
    Column.integer('affected_count'),
    Column.text('deleted_at'),
  ], indexes: [
    Index('idx_qaza_del_user', [IndexedColumn('user_id')]),
  ]),
  Table('qaza_deletion_action_record_snapshots', [
    Column.text('action_id'),
    Column.text('record_id'),
    Column.text('snapshot_json'),
    Column.text('created_at'),
  ], indexes: [
    Index('idx_del_snap_action', [IndexedColumn('action_id')]),
  ]),
  Table('qaza_profile_plan_provenance', [
    Column.text('profile_id'),
    Column.text('revision_id'),
    Column.text('source'),
    Column.text('created_at'),
  ]),
  Table('user_preferences', [
    Column.text('user_id'),
    Column.text('key'),
    Column.text('value'),
    Column.text('updated_at'),
  ], indexes: [
    Index('idx_user_pref_user_key', [
      IndexedColumn('user_id'),
      IndexedColumn('key'),
    ]),
  ]),
]);
```

---

## 4. Drift Migration Strategy & SQLite View Handling

### A. PowerSync-Aware Drift Initialization
PowerSync generates SQLite tables prefixed with `ps_data__` (holding raw JSON columns) and generates SQLite `VIEW`s with the table name (e.g., `qaza_records`) backed by `INSTEAD OF INSERT/UPDATE/DELETE` triggers.

In `AppDatabase.forPowerSync`:
1. `_isPowerSync = true`.
2. `migration.onCreate` intercepts initialization:
   - When `_isPowerSync` is active, Drift skips `m.createAll()`. Calling `m.createAll()` would fail because SQLite rejects `CREATE TABLE qaza_records` when a view of that name exists.
   - Skips creating indexes on views (`views may not be indexed`).
   - Ensures local tables (`local_accounts`, `meta_store`, `app_session_state`, `device_metadata`, `local_recovery_snapshots`, `workspace_sync_status`).
   - Ensures underlying JSON unique constraints via `_ensurePowerSyncUniqueConstraints()`.

### B. Enforcing Ledger Uniqueness on Views
SQLite cannot enforce `UNIQUE` constraints on views. To guarantee zero duplicates:
```sql
CREATE UNIQUE INDEX IF NOT EXISTS idx_ps_data_qaza_rec_logical_uniq
ON ps_data__qaza_records(
  cast(json_extract(data, '$.user_id') as text),
  cast(json_extract(data, '$.prayer_type') as text),
  cast(json_extract(data, '$.original_date') as text)
);
```
When Drift executes `INSERT INTO qaza_records ...`, PowerSync's `INSTEAD OF INSERT` trigger inserts into `ps_data__qaza_records`, which triggers this unique index. If duplicate data is inserted, SQLite throws a uniqueness violation error as expected.

### C. SQLite Invariants on Views Resolved in DAOs
1. **No UPSERT on Views:** SQLite throws `cannot UPSERT a view, SQL logic error (code 1)`. In `qaza_records_dao.dart`, `upsertRecords` was updated to check-and-update or insert rows without relying on `insertOnConflictUpdate`.
2. **`sqlite3_changes()` on Views:** SQLite reports `0` affected rows for top-level `UPDATE`/`DELETE` against views with triggers because modifications occur inside the trigger context. In `qaza_records_dao.dart`:
   - `completeByIds` and `markCompletedAsPendingBatch` evaluate completions safely without failing due to 0 reported changes.
   - `deleteAllForUser`, `deleteByIds`, `deleteById`, and `deletePendingById` count rows prior to execution when running under `isPowerSync`, returning exact deleted counts.
3. **Trigger Variable Defaults:** Views do not evaluate table column defaults. When `recordVersion` is omitted from an insert companion, `_ensureRecordVersion` automatically sets `Value(1)` so `record_version` is never stored as null.

---

## 5. DateTime Serialization Investigation & Resolution

- **Drift Default:** By default, Drift stores `DateTime` as Unix timestamps in seconds or milliseconds (`storeDateTimeAsText: false`).
- **PowerSync Requirement:** PowerSync stores dates as ISO-8601 strings (e.g., `2026-09-09T00:00:00.000Z`) for PostgreSQL compatibility.
- **Resolution:** In `AppDatabase`:
  ```dart
  @override
  DriftDatabaseOptions get options => _isPowerSync
      ? const DriftDatabaseOptions(storeDateTimeAsText: true)
      : const DriftDatabaseOptions(storeDateTimeAsText: false);
  ```
- **Test Verification:**
  - Round-trip tested with UTC dates, midnight dates, leap years (`2028-02-29`), milliseconds, and null timestamps.
  - Queries filtering by date ranges (`where((r) => r.originalDate.isBiggerOrEqualValue(...))`) execute accurately with ISO-8601 string comparisons.

---

## 6. Comprehensive Test Verification

### Phase 2 Integration Test Suite: 15 / 15 Passed (100%)
File: `test/data/powersync/powersync_phase2_dao_integration_test.dart`

```
00:00 +0: 1. Actual application schema initialization on PowerSync [PASSED]
00:02 +1: 2. Correct PowerSync-managed table mapping (views over ps_data__) [PASSED]
00:04 +2: 3. Correct Drift local-only table creation [PASSED]
00:06 +3: 4. No duplicate table or index creation [PASSED]
00:09 +4: 5. No attempts to ALTER PowerSync-managed views [PASSED]
00:10 +5: 6. Actual generated DAO reads [PASSED]
00:12 +6: 7. Actual generated DAO writes (insert, complete, update, delete) [PASSED]
00:14 +7: 8. Existing Qaza uniqueness rules (user_id, prayer_type, original_date) [PASSED]
00:16 +8: 9. Atomic batch inserts with insertOrIgnore [PASSED]
00:19 +9: 10. Rollback on failure in transaction [PASSED]
00:21 +10: 11. DateTime round-trip compatibility (UTC, midnight, leap-year, nulls) [PASSED]
00:23 +11: 12. Reactive query updates [PASSED]
00:25 +12: 13. Keyset pagination (Pending and Completed) [PASSED]
00:27 +13: 14. Closing and reopening the database safely [PASSED]
00:31 +14: 15. Separate workspace schema initialization (Guest vs Google) [PASSED]
```

### Full Repository Regression Verification
- **`powersync_phase1_integration_test.dart`:** 12 / 12 passed.
- **`powersync_phase2_dao_integration_test.dart`:** 15 / 15 passed.
- **`test/data/local/` and `test/domain/`:** 128 / 128 passed.
- **Full Test Suite (`flutter test`):** **814 / 814 passed (100%)**.
- **Static Analysis (`flutter analyze`):** **0 issues found**.

---

## 7. Modified & Created Files Summary

1. `lib/data/powersync/powersync_schema.dart` (Updated schema tables and query indexes).
2. `lib/data/local/database/app_database.dart` (Added `AppDatabase.forPowerSync`, view safeguards, local table initializers, unique constraints).
3. `lib/data/local/database/qaza_records_dao.dart` (PowerSync view-safe delete and upsert methods, default `recordVersion`).
4. `test/data/powersync/powersync_phase2_dao_integration_test.dart` (Comprehensive 15-scenario verification test suite).

---

## 8. Remaining Technical Risks & Phase 3 Prerequisites

1. **Active Providers Still on Legacy Local Path:**
   - In accordance with Phase 2 instructions, `appDatabaseProvider` still points to standard encrypted Drift SQLite.
   - In Phase 3, repository and provider routing must transition to PowerSync Drift connection without breaking legacy onboarding or guest adoption flows.
2. **Phase 3 Scope:**
   - Supabase Auth connector integration (`PowerSyncBackendConnector`).
   - Supabase CRUD upload handlers (`uploadData(PowerSyncTransaction)`).
   - Sync stream lifecycle management (start/stop sync based on workspace and auth state).
   - Guest-to-Google workspace adoption data transfer without silent overwrites.

---
*End of Phase 2 Implementation Report.*
