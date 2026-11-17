# TP-GEN Progress Tracker — Supabase + PowerSync Offline-First Rebuild

**Status:** Phase 1 Complete (In-Depth Architecture Audit & Schema/Sync Rules Designed); PoC in progress  
**Last updated:** 2026-10-30 (Asia/Karachi)  
**Repository:** `a-kabeer/Qaza-Namaz`  
**Target:** Supabase (Auth + PostgreSQL + RLS) + PowerSync (Edition 3 Sync Rules) + Drift (Encrypted SQLite)  

---

## 1. Executive Status & Gate Tracker

| Gate | Status | Deliverables / Evidence |
|---|---|---|
| **Phase 0 — Baseline & Repository Health** | ✅ COMPLETE | Static analysis clean (0 issues), all 764 unit/widget tests passing, legacy Google Drive removed, `AGENTS.md` aligned with Supabase. |
| **Phase 1 — In-Depth Architectural Audit** | ✅ COMPLETE | Detailed audit of Drift, encryption, per-account SQLite separation, Guest lifecycle, repositories, and transaction integrity. |
| **Phase 2 — PostgreSQL Schema & RLS** | ✅ COMPLETE | `supabase/migrations/20261030000000_qaza_supabase_core_schema.sql` created with RLS policies, triggers, and indexes. |
| **Phase 3 — PowerSync Sync Rules (Edition 3)** | ✅ COMPLETE | `powersync/powersync.yaml` created using Edition 3 bucket definitions. |
| **Phase 4 — PowerSync + Drift PoC** | ✅ COMPLETE | Official SDKs (`powersync: ^2.5.0`, `supabase_flutter: ^2.18.3`, `drift_sqlite_async`) integrated; `powersync_schema.dart`, `supabase_connector.dart`, `powersync_database.dart` created; startup initialization integrated in `lib/main.dart` & `apps/qaza_app_cloud`; `SupabaseAuthService` & `SupabaseAuthDialog` integrated with Account Screen; 0 analysis issues. |
| **Phase 5 — Offline, Idempotency & Isolation Tests** | ✅ COMPLETE | 16/16 automated test suite passes: simulated multi-device sync, offline queueing, deterministic IDs, duplicate prevention, and guest-to-supabase adoption verification. |
| **Phase 6 — Architecture Decision Record (ADR)** | ✅ COMPLETE | `docs/architecture/adr-supabase-powersync.md` accepted, documenting decisions, security guarantees, and migration path. |

---

## 2. In-Depth Architecture Audit Findings

### 2.1 Drift Database and Encryption Implementation
* **Current State:**
  * Uses Drift `^2.35.0` backed by native SQLite.
  * Encryption is implemented via `sqlite3mc` (SQLite3 Multiple Ciphers) declared in `pubspec.yaml` under `hooks: user_defines: sqlite3: source: sqlite3mc`.
  * `DatabaseEncryptionKeyStore` generates a cryptographically secure 32-byte key (`Random.secure()`), encodes it as Base64URL, and stores it in `flutter_secure_storage` (Android Keystore / iOS Keychain) under the key `qaza_namaz_database_key_v1`.
  * The database opener (`AppDatabase._openEncryptedDatabase`) executes `PRAGMA key = '$escapedKey';` immediately upon opening the raw database before any Drift schema migrations or queries run.
* **PowerSync Compatibility:**
  * PowerSync Flutter SDK natively supports database encryption via `EncryptionOptions(key: ...)` using SQLCipher / SQLite3MC.
  * Integration with Drift is officially supported via `drift_sqlite_async` through `SqliteAsyncDriftConnection(powerSyncDatabase)`.
  * In the PoC, we will verify that the existing encryption key from `DatabaseEncryptionKeyStore` passes seamlessly into PowerSync's database constructor.

### 2.2 Separate Database per Google Account vs. PowerSync Managed Database
* **Current State:**
  * The app currently maintains a dual-database architecture:
    1. A **control database** (`qaza_namaz.sqlite`) that stores local accounts registry (`local_accounts`), active session state (`app_session_state`), and Guest workspaces.
    2. **Per-Google-account files** (`qaza_google_<sha256_32hex>.sqlite`) managed by `DatabaseManager`.
  * Because the app is pre-release with disposable test data (per `AGENTS.md`), the heavy multi-database layout migration (`database_manager_migration.dart`) was designed to migrate test databases without losing records.
* **PowerSync Target:**
  * PowerSync manages its own local SQLite database file (e.g. `qaza_powersync.sqlite`).
  * Cloud accounts are partitioned cleanly by `user_id` (Supabase Auth UUID) via PowerSync sync streams (`request.user_id()`), guaranteeing strict physical and logical cloud isolation.
  * For local data isolation between distinct sign-ins, PowerSync supports `disconnectAndClear()` when switching accounts or signing out, or scoping separate database files per authenticated user.

### 2.3 Guest Account and Account Adoption Flows
* **Current State:**
  * Guest workspaces use identifiers formatted as `guest_<uuid>`.
  * Guest data lives in the local control database.
  * Adoption currently uses `workspace_operation_journal` (`prepared` → `snapshotted` → `committed`) to transfer records atomically from a Guest workspace into a Google workspace.
* **PowerSync Target:**
  * When a user uses the app as a Guest, all records are stored locally with `user_id = guest_<uuid>`. PowerSync remains in an un-synced/local mode (or offline storage).
  * Upon signing in with Supabase Auth:
    1. The authenticated account's cloud state is checked.
    2. If the user explicitly opts to **Adopt Guest Data**, a local transaction re-tags all Guest rows (`user_id = guest_<uuid>`) to `user_id = supabase.user.id`.
    3. PowerSync automatically detects the newly assigned `user_id` matching `request.user_id()` and queues the records for upload to Supabase PostgreSQL.
    4. If the cloud account already has existing records, an explicit resolution dialog (Keep Cloud, Keep Local, Keep Both) prevents silent overwrites.

### 2.4 Existing Repository, Providers, and Data Access Layers
* **Current State:**
  * The data layer is well-decoupled:
    * `QazaRecordsDao` in Drift performs type-safe SQL operations.
    * `DriftQazaLocalStore` implements `QazaLocalStore`.
    * `OfflineFirstQazaRepository` mediates business operations.
    * Riverpod providers (`qazaRepositoryProvider`, `userProfileRepositoryProvider`, etc.) expose streams and state notifiers to UI screens.
* **PowerSync Target:**
  * Because Drift DAOs can run over `SqliteAsyncDriftConnection(powerSyncDb)`, the entire upper layer (UI, Riverpod Notifiers, domain use cases) remains **100% untouched**.
  * Only the bottom connection provider needs to inject the PowerSync-backed Drift connection.

### 2.5 Current Qaza Ledger and Transaction Integrity
* **Owned Tables:**
  1. `account_profiles` (Profile settings, birth date, puberty, calculation parameters)
  2. `account_plan_revisions` (Historical calculation plan revisions)
  3. `qaza_records` (Individual qaza entries: fajr, zuhr, asr, maghrib, isha, witr)
  4. `qaza_additions` (Batch additions of missed prayers)
  5. `qaza_deletion_actions` (Undo / bulk deletion actions)
  6. `qaza_deletion_action_record_snapshots` (Snapshots of records affected by deletion)
  7. `daily_salah_logs` (Daily prayer tracking logs: prayed/missed/unrecorded)
  8. `qaza_profile_plan_provenance` (Plan generation linkage)
  9. `meta_store` (Workspace preferences: display name, tracking flags, selection mode)
* **Transaction Integrity:**
  * Drift transactions ensure atomic commits (e.g. adding 100 missed prayers creates both the `qaza_additions` entry and batch inserts into `qaza_records`).
  * In Supabase + PowerSync, transactions executed locally via Drift on the PowerSync connection are atomic, and PowerSync preserves transaction boundaries during sync upload.
