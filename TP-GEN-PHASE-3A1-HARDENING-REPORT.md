# TP-GEN Phase 3A.1 — Workspace Isolation & Cloud Schema Hardening Report

## Executive Summary

Phase 3A transitioned Qaza Namaz's runtime to a unified PowerSync SQLite persistence engine with Drift ORM. **Phase 3A.1** provides the necessary architectural hardening, workspace security guarantees, authoritative schema reconciliation, and provider routing validation required prior to authorizing **Phase 3B (Cloud Synchronization Launch)**.

### Verification Status
- **Static Analysis (`flutter analyze`):** **0 issues** (clean).
- **Automated Test Suite (`flutter test`):** **840 / 840 tests passed (100%)**.
- **Phase 3A.1 Regression Suite:** **10 / 10 passed**.
- **Phase 3A Local Cutover Suite:** **16 / 16 passed**.
- **Phase 1 Foundation Suite:** **12 / 12 passed**.
- **Phase 2 DAO Integration Suite:** **15 / 15 passed**.
- **Network Boundaries:** **Cloud sync strictly disabled**; local encryption and account boundaries fully enforced.

---

## Objective 1: Remediation of Silent Workspace Fallback

### 1. Root Cause Analysis
In previous iterations, `activeWorkspaceDatabaseProvider` utilized a defensive `try / catch` structure around workspace resolution. When `databaseForActiveWorkspace()` failed or encountered an unvalidated Google workspace state, it caught the exception and silently returned `ref.watch(appDatabaseProvider)` (the shared Control/Guest database). This introduced severe data-bleed and security risks:
1. An uninitialized or failing Google workspace would silently write records into the Guest database.
2. Account switching under race conditions could route authenticated queries to the wrong SQLite database file.

### 2. Architectural Hardening Implemented
1. **Explicit Fail-Closed Guard in `DatabaseManager`:**
   In [database_manager.dart](file:///d:/My%20Folder/My%20Work/Flutter/Flutter%20Project/Qaza%20App/lib/data/local/database/database_manager.dart#L270-L285):
   ```dart
   AppDatabase databaseForActiveWorkspace(String? localAccountId) {
     final id = localAccountId?.trim();
     if (id == null || id.isEmpty || !id.startsWith('google_')) {
       return controlDatabase;
     }
     final database = _workspaceDatabases[id];
     if (database == null) {
       throw StateError(
         'The active Google workspace ($id) has not been opened and validated. '
         'Access is blocked to prevent fallback or cross-workspace data leakage.',
       );
     }
     return database;
   }
   ```
2. **Elimination of Fallback in `activeWorkspaceDatabaseProvider`:**
   In [providers.dart](file:///d:/My%20Folder/My%20Work/Flutter/Flutter%20Project/Qaza%20App/lib/app/providers.dart#L298-L308):
   Unsafe `try / catch` fallback blocks were removed. If an authenticated Google workspace has not been validated or throws during initialization, the provider raises a hard `StateError` rather than leaking queries to Guest storage.
3. **Connection Lifecycle & Teardown (`closeWorkspaceDatabase`):**
   Added `closeWorkspaceDatabase(String localAccountId)` to [database_manager.dart](file:///d:/My%20Folder/My%20Work/Flutter/Flutter%20Project/Qaza%20App/lib/data/local/database/database_manager.dart#L287-L295), which safely disposes both the Drift `AppDatabase` handle and the underlying PowerSync connection via `QazaPowerSyncDatabaseManager.closeDatabase(workspaceId, documentsDirectoryProvider)`.
4. **Legitimate Guest Initialization Preserved:**
   Legitimate Guest workspaces (`id == null`, `id.isEmpty`, or non-Google IDs) cleanly resolve to `controlDatabase` without throwing.

### 3. Dedicated Regression Suite (10 Scenarios)
Created [powersync_phase3a1_workspace_isolation_hardening_test.dart](file:///d:/My%20Folder/My%20Work/Flutter/Flutter%20Project/Qaza%20App/test/data/powersync/powersync_phase3a1_workspace_isolation_hardening_test.dart):
1. **Guest → Google A:** Verified separate physical files, distinct encryption keys, and correct provider routing.
2. **Google A → Google B:** Verified zero data bleed and zero preference bleed (sticky selections isolated to target database).
3. **Google B → Guest:** Verified clean transition back to Guest returning `controlDatabase`.
4. **Google A Initialization Failure:** Throws explicit `StateError`; zero fallback to Guest.
5. **Google B Initialization Failure:** Throws explicit `StateError`; zero fallback to Google A or Guest.
6. **Missing Encryption Key:** Fails closed with `StateError`; zero fallback.
7. **Wrong Encryption Key:** Fails closed with SQLite cipher error; zero fallback.
8. **Corrupted Database File:** Account-specific failure; uncorrupted workspaces and Guest remain operational.
9. **Concurrent Account Switching:** Deterministic resolution under concurrent load; clean disposal without handle leaks.
10. **Legacy Migration Retry Safety:** Re-running migration preserves newer destination data without overwrite.

---

## Objective 2: Authoritative Cloud Schema & Table Inventory

### Reconciliation of Documentation Discrepancy
The discrepancy between the Phase 2 report (9 tables) and the Phase 3A text summary (7 tables) was an omission in narrative text. The production migration [20261030000000_qaza_supabase_core_schema.sql](file:///d:/My%20Folder/My%20Work/Flutter/Flutter%20Project/Qaza%20App/supabase/migrations/20261030000000_qaza_supabase_core_schema.sql), the sync configuration [powersync.yaml](file:///d:/My%20Folder/My%20Work/Flutter/Flutter%20Project/Qaza%20App/powersync/powersync.yaml), and the Dart schema [powersync_schema.dart](file:///d:/My%20Folder/My%20Work/Flutter/Flutter%20Project/Qaza%20App/lib/data/powersync/powersync_schema.dart) have always defined and required **9 cloud tables**. Both `qaza_profile_plan_provenance` and `user_preferences` are active, validated, and essential.

### Complete Inventory Matrix (14 Total SQLite Tables)

| # | Table Name | Scope | Schema Owner | PowerSync Model | PostgreSQL Supabase Table | RLS Required | Purpose |
|---|------------|-------|--------------|-----------------|---------------------------|--------------|---------|
| 1 | `account_profiles` | Cloud / Synced | PowerSync | Table (`ps_data__`) + View | `public.account_profiles` | Yes (`user_id = auth.uid()`) | User onboarding date, calculation method, madhab, gender, DOB. |
| 2 | `account_plan_revisions` | Cloud / Synced | PowerSync | Table (`ps_data__`) + View | `public.account_plan_revisions` | Yes (`user_id = auth.uid()`) | Historical adjustments to Qaza calculation plan. |
| 3 | `qaza_additions` | Cloud / Synced | PowerSync | Table (`ps_data__`) + View | `public.qaza_additions` | Yes (`user_id = auth.uid()`) | Batch Qaza additions (e.g. adding 1 year of missed prayers). |
| 4 | `qaza_records` | Cloud / Synced | PowerSync | Table (`ps_data__`) + View | `public.qaza_records` | Yes (`user_id = auth.uid()`) | Core Qaza ledger entries (prayer type, date, status, completion). |
| 5 | `daily_salah_logs` | Cloud / Synced | PowerSync | Table (`ps_data__`) + View | `public.daily_salah_logs` | Yes (`user_id = auth.uid()`) | Daily 5-time prayer performance check-offs and statuses. |
| 6 | `qaza_deletion_actions` | Cloud / Synced | PowerSync | Table (`ps_data__`) + View | `public.qaza_deletion_actions` | Yes (`user_id = auth.uid()`) | Audit log for Qaza record deletions / batch reductions. |
| 7 | `qaza_deletion_action_record_snapshots` | Cloud / Synced | PowerSync | Table (`ps_data__`) + View | `public.qaza_deletion_action_record_snapshots` | Yes (`user_id = auth.uid()`) | Pre-deletion record snapshots to enable reliable Undo operations. |
| 8 | `qaza_profile_plan_provenance` | Cloud / Synced | PowerSync | Table (`ps_data__`) + View | `public.qaza_profile_plan_provenance` | Yes (`user_id = auth.uid()`) | Links generated Qaza records to the plan revision that produced them. |
| 9 | `user_preferences` | Cloud / Synced | PowerSync | Table (`ps_data__`) + View | `public.user_preferences` | Yes (`user_id = auth.uid()`) | Cross-device user settings (Witr enabled, calculation preferences). |
| 10 | `local_accounts` | Local-Only | Drift SQLite | Direct SQLite Table | *None* | No | Device-level registry of local Guest & Google workspace identities. |
| 11 | `workspace_sync_metadata` | Local-Only | Drift SQLite | Direct SQLite Table | *None* | No | Local sync timestamps, checkpoint tokens, and cloud sync status. |
| 12 | `workspace_operation_journal` | Local-Only | Drift SQLite | Direct SQLite Table | *None* | No | Crash-safe operation journal for local transactions and adoption. |
| 13 | `local_workspace_deletion_holds`| Local-Only | Drift SQLite | Direct SQLite Table | *None* | No | 7-day retention grace period for soft-deleted local workspaces. |
| 14 | `meta_store` | Local-Only | Drift SQLite | Direct SQLite Table | *None* | No | Workspace key-value store (`workspace_file_owner`, local UI prefs). |

**Mathematical Verification:** 9 Cloud-Synchronized Tables + 4 Local-Only Administration Tables + 1 Local Key-Value Store = **14 Total Physical Tables**.

---

## Objective 3: Legacy Migration Idempotency & Retry Safety

### 1. `INSERT OR IGNORE` Guarantees
Audited [legacy_drift_to_powersync_migrator.dart](file:///d:/My%20Folder/My%20Work/Flutter/Flutter%20Project/Qaza%20App/lib/data/powersync/legacy_drift_to_powersync_migrator.dart):
- Converted all `INSERT OR REPLACE` statements to `INSERT OR IGNORE` across `account_profiles`, `daily_salah_logs`, and `meta_store`.
- If an interrupted migration is retried, or if a user modifies records in the destination PowerSync database prior to a secondary sync/retry pass, the migrator **never overwrites newer destination state**.

### 2. Batch Companion Grouping by `userId`
Drift's DAO enforces that batch insertions into `QazaRecords` share the same `userId` companion parameter. The migrator now partitions and groups legacy records by `userId` prior to calling `batchInsert()`, eliminating batch cross-user assertion errors during migration.

### 3. Provenance Migration
Added migration logic for `qaza_profile_plan_provenance` so historical plan revision mappings from legacy databases are preserved in PowerSync.

---

## Objective 4: Provider-Consumer Matrix Audit

A full scan of `lib/` was conducted to audit every call to `appDatabaseProvider`, `activeWorkspaceDatabaseProvider`, `DatabaseManager`, and `databaseForActiveWorkspace`.

```
                             [DatabaseManager]
                                     │
           ┌─────────────────────────┴────────────────────────┐
           ▼                                                  ▼
   [appDatabaseProvider]                       [activeWorkspaceDatabaseProvider]
   (Device / Account-Agnostic)                 (Active Workspace / User-Scoped)
           │                                                  │
           ├─► AccountLocalStore (Registry)                   ├─► DriftQazaLocalStore
           ├─► StartupGate (Account Choice)                   ├─► DriftQazaAdditionRepository
           ├─► PrayerTimeCache (Astronomical)                 ├─► DailySalahTrackingService
           ├─► Guest Google Prompt Tracker                    ├─► HomePrayerSelectionNotifier
           └─► Knowledge Base Locale Cache                    └─► QazaService & Analytics UI
```

### Provider Matrix

| Provider / Consumer | Injected Database Source | Data Scope | Verification |
|---------------------|--------------------------|------------|--------------|
| `activeWorkspaceDatabaseProvider` | `DatabaseManager.databaseForActiveWorkspace(userId)` | Current Active Workspace (Guest or Google) | **Hardened.** Throws `StateError` if Google workspace unvalidated. Zero Guest fallback. |
| `qazaLocalStoreProvider` | `activeWorkspaceDatabaseProvider` | User Qaza ledger | Verified routes to dedicated Google file or Guest. |
| `qazaRepositoryProvider` | `qazaLocalStoreProvider` | User Qaza repository | Verified reactive re-binding on user switch (`ref.listen`). |
| `qazaAdditionRepositoryProvider` | `activeWorkspaceDatabaseProvider` | User Qaza additions | Verified user-scoped. |
| `dailySalahTrackingServiceProvider`| `activeWorkspaceDatabaseProvider` | User daily prayer tracker | Verified user-scoped. |
| `HomePrayerSelectionNotifier` | `activeWorkspaceDatabaseProvider` | Sticky prayer selection | Verified persisted into active workspace `meta_store`. No cross-account bleed. |
| `accountLocalStoreProvider` | `appDatabaseProvider` (Control DB) | Device account registry | Legitimate device-level scope. |
| `accountChoiceCompleteProvider` | `appDatabaseProvider` (Control DB) | First-run onboarding state | Legitimate device-level scope. |
| `PrayerTimeCache` | `appDatabaseProvider` (Control DB) | Astronomical prayer times | Legitimate device-level calculation cache. |
| `guestConnectPromptRequestProvider`| `appDatabaseProvider` (Control DB) | Google sign-in prompt flag | Legitimate device-level prompt state. |

---

## Objective 5: Verification & Test Suite Summary

### Test Execution Results
- **Full Flutter Test Suite:** `flutter test`
  - **Passed:** **840 tests** (0 failures).
- **Static Analysis:** `flutter analyze`
  - **Result:** **No issues found!** (0 errors, 0 warnings, 0 lints).
- **Targeted Integration Tests:**
  - `powersync_phase3a1_workspace_isolation_hardening_test.dart`: 10/10 passed.
  - `powersync_phase3a_runtime_cutover_test.dart`: 16/16 passed.
  - `powersync_phase1_integration_test.dart`: 12/12 passed.
  - `powersync_phase2_dao_integration_test.dart`: 15/15 passed.
  - `guest_workspace_management_screen_test.dart`: 8/8 passed.
  - `home_prayer_targeting_test.dart`: 15/15 passed.

---

## Pre-Phase 3B Readiness Checklist

- [x] Unsafe catch-all Guest fallback removed from `activeWorkspaceDatabaseProvider`.
- [x] Explicit `StateError` thrown for unvalidated or failing Google workspaces.
- [x] Account switching does not leak records or UI selection preferences across workspaces.
- [x] Workspace database closing releases Drift handles and PowerSync connections cleanly.
- [x] Authoritative 9-table cloud schema inventory reconciled with PostgreSQL and PowerSync definitions.
- [x] Legacy migration verified idempotent and protected with `INSERT OR IGNORE`.
- [x] Complete Provider-Consumer Matrix audited and verified.
- [x] 840 automated tests passing with 0 static analysis issues.
- [x] Network boundaries preserved: PowerSync `connect()` and `uploadData()` remain disabled.

**Recommendation:** The local persistence architecture is completely hardened, verified, and ready for **Phase 3B (Cloud Synchronization Launch)** upon explicit user authorization.
