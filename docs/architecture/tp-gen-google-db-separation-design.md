# TP-GEN — Separate Google Database: Routing Design (Reconciled)

**Status:** Phase 0 design record, completed retrospectively in Recovery Plan
Stage 3 (2026-10-22) against the implementation on
`tp-gen/separate-google-db` @ `ef5f646c`.
**Authority chain:** design plan *TP-GEN — Separate Encrypted Local Database
per Google Account, v2.2* (decisions S1–S7, protocols §4–§7, test matrix §8)
wins over this document; the implementation task plan (Phases 0–5) orders the
work; this document records the routing design the task plan's Phase 0
(T0.2–T0.7) required. Where implementation and design disagree, the
discrepancy — not this document — is the record of truth:
see `tp-gen-separate-google-db-discrepancy-register.md` in this directory.
**Relationship to the spike:** this document incorporates and, where noted,
supersedes `tp-gen-google-db-separation-spike.md` (draft PR #348, preserved
verbatim in this directory). The spike's go/no-go gate ("no production split
until the routing design is explicit") is the gate this document closes on
paper; the spike's repository evidence (items 1–10) was re-verified against
the branch in Stage 3 and is not repeated here.

## 1. Shape

One Drift database class with a role, plus a subclass — not two independent
Drift classes:

- `AppDatabase` (`lib/data/local/database/app_database.dart`) carries
  `AppDatabaseRole { controlGuest, googleWorkspace }`. The control instance
  and every Guest workspace live in `qaza_namaz.sqlite`.
- `GoogleWorkspaceDatabase extends AppDatabase` (app_database.dart:1543)
  is constructed with an explicit file name and workspace ID and runs the
  workspace-role schema setup. Both roles share the generated code
  (`app_database.g.dart`, `qaza_records_dao.g.dart`) and the table
  definitions; schema setup branches by role inside the `_ensure*`
  functions (the registry/session/device/journal/holds ensures are
  control-only; the owner-guard ensure is workspace-only; see the register's
  inventory for the per-function split).

This satisfies S1's "distinct control and Google database classes" with
"shared table definitions where practical". The variance from task-plan
T0.3's wording (two classes, stated generated-code home) is recorded in the
register (item R-17) with the conformance evidence.

## 2. Registry and resolution (S4)

- The registry is `local_accounts` in the control database, extended in
  place (S4 allowed extension or a companion table; extension was chosen):
  `db_file_name TEXT` (nullable), `db_layout TEXT NOT NULL DEFAULT 'shared'`,
  `db_migration_state TEXT NOT NULL DEFAULT 'not_started'`
  (app_database.dart:855–865 creation; :1021–1052 idempotent upgrade +
  invalid-layout rejection). Schema version 26.
- The registry is the single source of truth for location. A `separate`
  workspace's file name is additionally validated at open time against
  `DatabaseManager.googleFileNameForWorkspaceId` and
  `^qaza_google_[0-9a-f]{32}\.sqlite$`, with `db_migration_state = 'committed'`
  required (database_manager.dart:158–178).
- Resolution returns: control handle for Guest workspaces and — by design
  intent for the transition — for `shared` Google workspaces; the validated
  per-account file for `separate` workspaces. **The branch's
  `_openDatabaseForWorkspace` currently throws for `shared` instead of
  returning the control handle; that is register item R-01(iv), a blocker,
  not the design.**

## 3. Manager and handle routing (S5, T0.4)

- `DatabaseManager` (`lib/data/local/database/database_manager.dart`) is the
  single foreground owner of opening, per-file connection reuse
  (one handle per file per process, deduplicated through
  `_openingWorkspaceDatabases` / `_provisioningGoogleWorkspaces`),
  closure, and routing. Handles reach consumers explicitly:
  - providers: `databaseManagerProvider` (lib/app/providers.dart:289) →
    `appDatabaseProvider` (control handle), `accountLocalStoreProvider`
    (control handle + manager), `qazaLocalStoreProvider` /
    `qazaAdditionRepositoryProvider` via
    `manager.databaseForActiveWorkspace(activeId)` (providers.dart:397, 445);
  - `AccountLocalStore` receives `database` (control) + optional
    `databaseManager` (account_local_store.dart:16–20);
  - `LocalBackupService` receives `database` (control) + optional
    `databaseManager` (local_backup_service.dart:38);
  - the cloud adapter receives the manager by constructor injection
    (`GoogleCloudSyncProvider`, `LocalPhase1BackupSource`), and the worker
    constructs its own process instance (§5 below).
- Publishing rule (S5 steps 6–7): a Google workspace is published as active
  only after its registered database has been opened and validated
  (`setActiveWorkspace`, database_manager.dart:57–68;
  `databaseForActiveWorkspace`, :116–131, never falls back to another
  account's file or to Guest). **The gate as implemented also rejects
  shared-layout and legacy-ID workspaces whose authoritative handle is the
  control database — register item R-01(iii), a blocker.**
- No-default rule: production `AppDatabase()` / `GoogleWorkspaceDatabase()`
  no-argument constructions outside the manager are banned by the
  construction check added to `tools/offline_architecture_check.py`
  (final block). Coverage limits of that check (named constructors
  unmatched; `apps/` unscanned) are register item R-12.

## 4. Schema split (T0.3)

- Control file: `local_accounts`, `app_session_state`, `device_metadata`,
  `workspace_operation_journal`, `local_workspace_deletion_holds`,
  global `meta_store` keys, all Guest data (owned tables, scoped keys,
  `workspace_sync_metadata` rows, recovery snapshots for Guest workspaces),
  plus `local_account_adoption_snapshots` (created by the backup service).
- Google file: the eight owned tables (that workspace's rows only), the
  five scoped `meta_store` keys, its `workspace_sync_metadata` row, its
  recovery snapshots, and the `workspace_file_owner` marker — protected by
  owner-guard triggers (app_database.dart:926–995) that reject writes
  carrying another workspace's owner ID.
- Workspace revision triggers live with the owned tables: in a Google file
  they cover only its eight owned tables and write its own `meta_store`;
  the `local_accounts` revision trigger exists only in the control file
  (app_database.dart:1184–1319). Matches T0.3's split, including the
  "local_accounts trigger stays control-side" note.

## 5. Worker preflight ordering (S6, T0.5)

As implemented in `packages/qaza_cloud_adapter/lib/src/cloud_workmanager.dart`
(dispatcher, :34–215), and conforming to T0.5's sequence:

1. Cloud-enabled + automatic-sync gates (SharedPreferences) — return
   before any database is opened.
2. Captured Google account from account-scoped state — return if absent.
3. Construct the worker-process `DatabaseManager`; open the **control**
   database; `initialize()` (journal reconciliation for workspace
   creation/migration).
4. Read session generation; verify the captured workspace **is** the
   active workspace — otherwise return **without opening any Google file**.
5. Verify registry row: `db_layout = 'separate'`,
   `db_migration_state = 'committed'`, `db_file_name` equals the S3 name —
   otherwise return.
6. Verify no outstanding journal operation for the workspace
   (`phase NOT IN ('committed','failed','cleaned')`) — otherwise return.
7. Only then `databaseForWorkspace(...)` opens and validates the Google
   file (owner marker + integrity); existing pin / generation /
   upload-block checks and the sync engine follow unchanged.

## 6. Identity, files, encryption (S2, S3)

- File name: `qaza_google_<h>.sqlite`, `<h>` = first 32 hex chars of
  SHA-256 over the UTF-8 stable Google ID (the part after `google_`),
  `DatabaseManager.googleFileNameForWorkspaceId` (database_manager.dart:
  82–91). No raw ID, email, or display name in any filename or path.
  Collision with a different workspace aborts; existing unregistered files
  are never overwritten (creation/migration paths throw instead).
- Staging: creation uses `<file>.staging`; migration uses
  `<file>.migration-staging`; staging files are never opened as live
  workspaces; interrupted staging is quarantined (`<name>.quarantine`) by
  startup reconciliation, never silently reused.
- One key for all files: `DatabaseEncryptionKeyStore` /
  `qaza_namaz_database_key_v1` through the single opener
  `AppDatabase._openEncryptedDatabase` (app_database.dart:47–80);
  Google files are encrypted from the first write
  (`migrateLegacyPlaintext: false`); the control file's
  `PlaintextDatabaseMigrator` behaviour is unchanged.

## 7. Hash, triggers, safety copy (T0.6 record)

- Canonical content hash: **unified in Recovery Stage 4 (decision
  D-D(ii))** in `WorkspaceCanonicalContent`
  (lib/data/local/database/workspace_canonical_content.dart) on the §7
  scoped-export canonicalisation: the eight owned tables (all columns,
  primary-key order), scoped metadata (display-name value tokenised;
  revision counter excluded), and the workspace's scoped recovery
  snapshot, with the owner ID normalised to a token so the hash is
  mapping-invariant across the Guest→Google identity mapping. Used by
  migration, workspace creation, and export-side verification;
  cross-file adoption verification uses the owned-tables part of the
  same canonicalisation (`ownedContentHash`). The retired
  `workspace-content-v1` and `workspace-canonical-v1` forms are no
  longer produced anywhere. Register item R-09 — closed.
- Trigger rule (§7): revision/sync counters are excluded from the
  canonical hash and verified separately — migration compares the
  copied sync row field-by-field at commit (register R-09 evidence).
- Safety copy (§5.1): **implemented in Recovery Stage 4** — one
  `VACUUM INTO` copy of the control database
  (`qaza_namaz.sqlite.migration-safety-copy`), created once before the
  first migration of a startup run, verified openable +
  integrity-checked under the actual key setup, never refreshed; the
  §5.1 storage pre-check (blanket 3× control size via an injectable
  free-space provider) blocks the run before any file is modified.
  Migration commit no longer deletes source rows (§5.4 retention).
  Register item R-04 — closed.

## 8. Manifest and journal (T0.7 record)

- No dedicated manifest table was created; §5.1's alternative (journal
  rows of a dedicated operation type) is used: `workspace_operation_journal`
  (control) with `operation_type` `google_workspace_create` /
  `google_workspace_migration`, deterministic operation IDs
  (`google-workspace-create:<id>`, `google-workspace-migration:<id>`,
  `guest-adoption:<guest>=><google>`), and the journal columns
  `staging_file`, `final_file`, `content_hash`, `snapshot_id`,
  `backup_verified_at` (app_database.dart:996–1019, :1062–1078).
- Phases used: `prepared`, `snapshotted`, `copied`, `verified`,
  `finalizing`, `committed`, `failed`, `cleaned` (per flow; cross-file
  adoption omits `finalizing` — register item R-10). The §5.1 manifest
  state names (`not_started`, `copying`, `verifying`) are not used for
  migration; `db_migration_state` carries `not_started`/`committed` in
  practice.
- Startup reconciliation (manager `initialize()` →
  `_reconcileWorkspaceCreationJournal`, database_manager.dart:474–561)
  covers `google_workspace_create` and `google_workspace_migration` rows
  only, before exposure, implementing §6's staging-only and
  final-without-commit cases for those flows. Adoption rows reconcile
  lazily at retry — register item R-20.

## 9. Adoption and migration protocols (as reconciled)

- Adoption (§4): preconditions unchanged (verified identity, definite
  no-backup Drive result, empty target). Separate target →
  `_adoptGuestWorkspaceAcrossFiles` (local_backup_service.dart:956–1331):
  journal `prepared → snapshotted → copied → verified → committed`;
  commit is **one control transaction** updating registry, journal, and
  the Guest's `adopted_recovery` marking together (:1268–1330 area) —
  §4 step 7 conforms; the `finalizing` phase and staging-file publish of
  §4 steps 3/5/6 are not used for an already-provisioned target file —
  register item R-10. Shared target → the pre-existing single-database
  atomic path (design §4 case (c) defers its layout to §5) — register
  item R-10 note. Guest source + snapshot retention (verified backup +
  30 days) unchanged.
- Migration (§5): implemented as a **lazy, per-activation** migration
  inside `DatabaseManager.ensureGoogleWorkspace` →
  `_DatabaseManagerMigrationHelper._migrateLegacyGoogleWorkspace`
  (database_manager_migration.dart:342–556), with §6-style
  finalization intent, publish-without-overwrite, reopen-and-verify, and
  one-transaction registry+journal commit. This differs from §5.2's
  startup run over every resident workspace, and from §5.1/§5.4 in the
  ways listed in §7 above — register item R-04 (blocker cluster). The
  migrate-vs-block question itself is settled by §5.2 in favour of
  migration — register item R-03.

## 10. What this document does not settle

The register's blockers (R-01, R-02, R-03's Stage 4 test action, R-04)
require Abdul's decisions before Stage 4. This document records the
reconciled design; it does not amend v2.2, and nothing in it authorizes
changing a test expectation or a production behaviour beyond what
Recovery Stage 3 was scoped to do.
