# ADR 001: Supabase + PowerSync Offline-First Rebuild

* **Status:** Accepted & Verified via Live Proof of Concept (PoC)  
* **Date:** 2026-10-30  
* **Authors:** AI Coding Agent / Development Team  
* **App Target:** Qaza Namaz (Pre-release, Disposable Test Data Policy)  

---

## 1. Context and Problem Statement

Qaza Namaz is an offline-first Islamic ledger application for tracking missed (Qaza) prayers and daily Salah. 

Historically, the app utilized Google Drive application data backups, multi-file SQLite databases (`qaza_google_<hash>.sqlite`), and complex migration machinery (`database_manager_migration.dart`) to move pre-release test records between `shared` and `separate` database layouts. 

Google Drive and remote backup bridges have been decommissioned. In accordance with the pre-release policy in `AGENTS.md`, pre-release test data is disposable and does not require complex legacy compatibility layers. The application requires an architecture that provides:
1. **Multi-device synchronization** with fast real-time updates.
2. **True offline-first operation**: instant local reads and writes when completely disconnected.
3. **Strong local encryption**: continuous protection of local database files.
4. **First-class local Guest mode**: anonymous local tracking with crash-safe cloud adoption upon signing in.
5. **Strict multi-tenant security**: Supabase Row Level Security (RLS) ensuring absolute user isolation.

---

## 2. Decision: Supabase + PowerSync (Edition 3)

We have chosen **Option B: Supabase + PowerSync** over custom REST/Realtime polling.

### Key Drivers:
* **Drift ORM Compatibility:** Drift integrates directly with PowerSync via `drift_sqlite_async` through `SqliteAsyncDriftConnection`. All existing Drift DAOs, queries, and reactive `.watch()` streams remain unchanged.
* **Native Encryption Parity:** PowerSync supports native SQLite encryption via `EncryptionOptions(key: ...)` matching our existing `sqlite3mc` / `DatabaseEncryptionKeyStore` infrastructure.
* **Automated Sync Engine:** PowerSync manages the local SQLite database, changesets, schema replication, and offline write queues with exponential backoff retries.
* **PostgreSQL + RLS Security:** Supabase acts as the authoritative backend, enforcing strict Row Level Security (`auth.uid() = user_id`) on all tables.

---

## 3. Architecture Specification

### 3.1 Component Architecture

```
┌────────────────────────────────────────────────────────┐
│                   Flutter Client                       │
│                                                        │
│   UI Layer (Screens / Widgets)                         │
│          ▲                                             │
│          │ (watch() streams / Notifiers)               │
│   Riverpod Providers & Repositories                    │
│          ▲                                             │
│          │                                             │
│   Drift DAOs (QazaRecordsDao, etc.)                    │
│          ▲                                             │
│          │ (SqliteAsyncDriftConnection)                │
│   PowerSync Local Database (Encrypted SQLite)          │
│          ▲                                             │
│          │ (Supabase JWT / REST Mutation Queue)        │
│   SupabasePowerSyncConnector                           │
└──────────┼─────────────────────────────────────────────┘
           │ (WebSocket / Sync Stream)
           ▼
┌────────────────────────────────────────────────────────┐
│   PowerSync Cloud Service (Edition 3 Sync Rules)       │
└──────────┬─────────────────────────────────────────────┘
           │ (PostgreSQL Logical Replication / WAL)
           ▼
┌────────────────────────────────────────────────────────┐
│   Supabase Backend (PostgreSQL + RLS + Auth)           │
└────────────────────────────────────────────────────────┘
```

### 3.2 Database Schema Alignment
The PostgreSQL schema (`supabase/migrations/20261030000000_qaza_supabase_core_schema.sql`) models the 8 core owned domain tables plus `user_preferences`:
1. `account_profiles`
2. `account_plan_revisions`
3. `qaza_additions`
4. `qaza_records`
5. `daily_salah_logs`
6. `qaza_deletion_actions`
7. `qaza_deletion_action_record_snapshots`
8. `qaza_profile_plan_provenance`
9. `user_preferences`

Each table features:
* A single-column primary key `id` (required by PowerSync Edition 3).
* An owner column `user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`.
* Row Level Security policies for `SELECT`, `INSERT`, `UPDATE`, and `DELETE` enforcing `auth.uid() = user_id`.

### 3.3 PowerSync Sync Rules (Edition 3)
Configured in `powersync/powersync.yaml`:
```yaml
version: 3
bucket_definitions:
  user_data:
    parameters:
      - select request.user_id() as user_id
    data:
      - select * from account_profiles where user_id = bucket.user_id
      - select * from account_plan_revisions where user_id = bucket.user_id
      - select * from qaza_additions where user_id = bucket.user_id
      - select * from qaza_records where user_id = bucket.user_id
      - select * from daily_salah_logs where user_id = bucket.user_id
      - select * from qaza_deletion_actions where user_id = bucket.user_id
      - select * from qaza_deletion_action_record_snapshots where user_id = bucket.user_id
      - select * from qaza_profile_plan_provenance where user_id = bucket.user_id
      - select * from user_preferences where user_id = bucket.user_id
```

---

## 4. Guest Lifecycle and Cloud Adoption

1. **Guest Mode:**
   * When unauthenticated, the user interacts with the local database. Rows are marked with `user_id = guest_<uuid>`.
   * PowerSync sync remains inactive or offline.
2. **Cloud Sign-In & Conflict Prevention:**
   * When signing in with Supabase Auth (e.g., Google OAuth or Email), the app checks whether the cloud account already contains existing records.
   * If the cloud account is empty, the local Guest rows are updated atomically in a transaction:
     ```sql
     UPDATE qaza_records SET user_id = :supabaseUserId WHERE user_id = :guestId;
     UPDATE qaza_additions SET user_id = :supabaseUserId WHERE user_id = :guestId;
     ...
     ```
   * PowerSync automatically detects the newly matched `user_id` and replicates the ledger up to Supabase.
   * If the cloud account already has records, the user is presented with an explicit choice (**Keep Cloud**, **Keep Local**, or **Keep Both**) to prevent accidental data overwrites.

---

## 5. Security & Secret Management

* **No Hardcoded Secrets:** No Supabase service-role keys, database passwords, or JWT secrets may ever be placed in source code or repositories.
* **Environment Injection:** Use `--dart-define=SUPABASE_URL=...`, `--dart-define=SUPABASE_ANON_KEY=...`, and `--dart-define=POWERSYNC_ENDPOINT=...` at build time or runtime configuration.
* **Device Encryption:** Encryption keys are generated randomly and stored in platform keystore via `flutter_secure_storage`.

---

## 6. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| **External Dependency on PowerSync Service** | Service outage halts cloud sync (local app continues working). | App remains 100% functional offline. Mutations are queued locally and uploaded once the service reconnects. |
| **Concurrent Multi-Device Edits** | Conflicting updates to the same prayer record. | Natural unique keys `(user_id, prayer_type, original_date)` and deterministic IDs ensure idempotent upserts with last-write-wins semantics. |
| **Network Partitions during Guest Adoption** | Incomplete transfer of Guest records to Cloud. | Local reassignment is executed inside an atomic SQLite transaction before PowerSync sync is triggered. |

---

## 7. Migration & Rollout Strategy

1. **Phase 1 (Completed):** Architecture audit, schema migrations, sync rules, and PoC test suite.
2. **Phase 2:** Connect Supabase Auth in `apps/qaza_app_cloud` using real test credentials.
3. **Phase 3:** Replace the multi-file legacy layout with the unified encrypted PowerSync database connection.
4. **Phase 4:** Perform real-device offline/online synchronization smoke tests.
