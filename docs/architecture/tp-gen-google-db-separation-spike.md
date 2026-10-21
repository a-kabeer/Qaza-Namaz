# TP-GEN — Google Database Separation: Phase 0 Architecture Spike

**Status:** Implementation gate not yet passed  
**Audited main commit:** `efadadd6558e8997913ebc248a0798e0a7bc29dd`  
**Target feature plan:** TP-GEN v2.2 — Separate Encrypted Local Database per Google Account  
**Purpose:** Record repository evidence before production storage changes.

## Decision

Do not begin the production database split from a file-path-only change. The current persistence API uses one concrete `AppDatabase` instance for both control-plane operations and workspace-owned data. The proposed architecture is viable only if these responsibilities can be routed explicitly and tested without leaving any workspace operation attached to the control database.

This spike is a gate report, not an implementation of the database split. The v2.2 plan requires a documented routing design before production changes; the present interface surface is not yet proven safe to change incrementally.

## Repository evidence

1. `lib/data/local/database/app_database.dart` constructs `AppDatabase([QueryExecutor? executor])` with a default path of `qaza_namaz.sqlite`. Its schema version is 25. The same class owns database opening, control/session methods, workspace revision/sync methods, metadata, recovery snapshots, and schema setup.
2. `_ensureAccountSchema()` creates both control tables (`local_accounts`, `app_session_state`, `device_metadata`) and workspace-owned tables (`account_profiles`, `account_plan_revisions`). These responsibilities need to be separated before the two physical layouts can be initialized correctly.
3. `_ensureWorkspaceLifecycleSchema()` creates both control-plane operation/deletion tables and per-workspace `workspace_sync_metadata`.
4. `_ensureWorkspaceRevisionSchema()` creates triggers across the account registry and workspace-owned tables and stores counters in `meta_store`. Its trigger inventory and behavior must be split by database role; copying it unchanged into each file would create incorrect ownership.
5. `lib/data/local/account_local_store.dart` accepts a concrete `AppDatabase` and uses it for registry/session operations as well as workspace profile and Qaza data operations.
6. `lib/app/providers.dart` provides a single `appDatabaseProvider` and injects it into Qaza stores and account-scoped services. Selecting a different filename in that provider alone would not route control operations to the control database.
7. `LocalBackupService.exportJson()` without a workspace argument currently enumerates all workspaces and their data from one connection. After the split, it must aggregate authoritative workspaces across the control database and the registered Google files, and fail explicitly if any authoritative workspace cannot be verified.
8. `packages/qaza_cloud_adapter/lib/src/cloud_workmanager.dart` opens `AppDatabase()` before checking whether the persisted Google account matches the active workspace. The required safe ordering is: open the control database, check session/registry/operation state, and only then open the active account's Google workspace file.
9. `lib/main.dart` and additional production construction sites create their own `AppDatabase()` instances. They must be routed through one lifecycle manager, including startup retry and the worker's separate process.
10. The current `main` head includes commit `efadadd` after the plan's stated base `b72aeffe`. That later Guest workspace white-screen fix must be preserved; implementation should be based on current `main`, not reset to the older base commit.

## Required design before implementation

- Map each production database method and raw SQL operation to either control-plane or workspace-owned responsibility.
- Define the APIs that allow `AccountLocalStore`, repositories, providers, backup/export, restore, and workers to resolve a database by the authoritative registry without circular provider dependencies.
- Separate schema initialization for control and Google files. Do not create inert control tables in Google files or workspace-only tables in the control file except where the transition layout requires them.
- Specify how workspace-scoped methods receive an explicit workspace/database handle, and how stale providers and pending writes are rejected on account switches.
- Define the migration manifest states including `finalizing`, durable operation-lock acquisition/recovery, and reconciliation of staging file, final file, registry, and journal after every crash boundary.
- Define deterministic hash canonicalization, revision-trigger handling, and a consistent encrypted SQLite/SQLCipher safety-copy procedure.
- Specify how full local export/import and the WorkManager control-plane preflight operate across both layouts.
- Add an architecture test that forbids production database construction outside the manager and the worker's equivalent manager entry point.

## Execution limitation

A local clone attempt in the current execution environment failed because the environment could not resolve `github.com`. The files were inspected through repository access, but Flutter analysis, code generation, unit/integration tests, and Android process-termination tests have not been run here. No production code has been changed by this spike.

## Go/no-go

**No-go for an unverified production split.** Resume implementation in an environment with a working repository checkout and Flutter toolchain after the API-routing design above is explicit. The implementation must preserve current `main`, implement and test the split in staged commits, and stop if the API shape requires an uncontrolled repository/interface rewrite. Do not claim the migration is implemented until code generation, relevant tests, CI, and required device verification have evidence.
