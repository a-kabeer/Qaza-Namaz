# TP-GEN v4.1 — Account lifecycle decisions and implementation status

This record captures the account/workspace decisions for the Qaza Namaz account-lifecycle refactor. It is a living decision record, not a substitute for green CI or real-device validation.

## Phase 0 — Decisions

### D1. Local storage model — shared SQLite database, explicitly scoped workspaces

Keep the existing encrypted shared SQLite database. Each account-owned row retains an explicit workspace owner (user_id or local_account_id), and cloud export/import must always receive the target workspace explicitly. A one-file-per-workspace migration is not justified by this audit and would introduce a second storage migration.

Schema v23 introduces a monotonically increasing workspace_revision:<workspace-id> counter maintained by SQLite triggers for workspace-owned rows and workspace preferences. Scoped cloud snapshots and sync checks use that revision; the global db_revision remains available for full local exports and compatibility.

### D2. Workspace identifiers

New workspace IDs are guest_<uuid> for Guest and google_<stableGoogleAccountId> for Google. Google identity must come from the verified stable Google account ID, never from email or display name. Schema 25 migrates legacy guest, guest:<uuid>, and google:<id> IDs in a transaction, remaps workspace-owned rows, account references, session pointers, revision/sync metadata, and backup markers. Guest ID collisions receive a fresh UUID rather than merging; a conflicting Google ID aborts the migration and leaves both sets unchanged.

### D3. Guest adoption and recovery

Adoption must start only after Google identity is verified and Drive discovery has returned a definite, validated no-backup result. Save and read-back-verify a recovery snapshot before changing ownership; never overwrite an existing Google workspace. The desired operation journal is prepared → snapshotted → copied → verified → committed → cleaned, with an idempotency key based on source Guest ID plus verified Google ID. Adoption saves and read-back-verifies a deterministic recovery snapshot, uses a deterministic operation ID, transfers ownership inside one SQLite transaction, checks per-table row-count parity before commit, and retains the snapshot until a verified cloud backup plus 30 days. The source becomes adopted_recovery and is hidden from Guest choices. The ownership remap is atomic, so copied and verified phases share the transaction and a crash rolls back to snapshotted.

### D4. Local/cloud conflict choice

The user-facing choices are Keep Local, Keep Cloud, and Keep Both. Keep Both must preserve the local workspace and create a separately labelled recovery_copy workspace for the other version. The account conflict dialog offers Keep Local, Keep Cloud, and Keep Both. Keep Both re-fetches the current remote version, validates its backup ID/version are unchanged, and saves the cloud snapshot as a labeled recovery_copy before resolving the active conflict. CI and regression coverage are still needed to validate the full flow.

### D5. Recovery across process death

Any multi-step adoption or restore must have durable journal state and be resumable or safely rolled back before the startup gate exposes the workspace. Guest adoption has a durable prepared/snapshotted/committed journal; copied/verified owner moves commit atomically. Startup still needs a recovery-gate audit for persisted restore operations and explicit process-kill tests.

### D6. Deletion semantics — whole-workspace snapshots

The current cloud adapter synchronizes a versioned, whole-workspace snapshot and does not perform record-level cloud merges. Deletions are therefore represented by the next verified whole-workspace upload, not by record-level tombstones. Conflict resolution must preserve both whole snapshots until the user decides; do not add a second tombstone system unless sync is redesigned to merge individual records.

## Phase gate checklist

- [x] Phase 0: audit current shared-database ownership and record D1–D6 decisions.
- [x] Phase 1 (implementation present): workspace-scoped scheduled/manual cloud operations, workspace revisions, schema-v25 canonical identity migration, persisted lifecycle/sync metadata, and session-generation guards. Regression verification and required CI remain a release gate.
- [x] Phase 2 (implementation present): distinct named Guest workspaces, draft lifecycle persisted until onboarding commits, startup draft resume, rename, seven-day deletion hold + Undo, safe expiry purge, and duplicate-name disambiguation. Draft restart/promotion/Undo regression tests are included.
- [x] Phase 3: complete metadata/content verification and regression testing for no-backup, found, legacy, and unknown/unverifiable Drive states; unknown state must block restore/adoption and upload.
- [x] Phase 4: complete explicit Drive metadata validation (stable Google ID, workspace ID, schema and content hash), verified write/readback, Keep Both recovery-copy validation, and stale conflict handling.
- [x] Phase 5: complete online/offline pending-backup sign-out, account-switch, cancellation, and interruption recovery tests.
- [ ] Phase 6: all lifecycle regression scenarios passing, required CI green, release artifact review, and physical-device verification report.

### Completion note — Phases 3–5 (2026-10-21)

Phases 3, 4, and 5 were completed on 2026-10-21. Local verification on that date: full app test suite 773/773 passed, cloud-adapter package suite 133/133 passed, `flutter analyze` clean of errors at root and in the package, `dart format` clean, and the three policy scripts (offline architecture, phase boundary, dead code) pass.

Regression coverage now lives in these test files. Cloud adapter package: `google_cloud_providers_test.dart` (Drive-state mapping, upload block, generation guard), `google_cloud_providers_phase4_test.dart` (metadata validation, Keep Both, stale conflicts), `google_cloud_providers_reconcile_test.dart`, `google_cloud_providers_scenario10_test.dart`, `google_cloud_providers_auth_expiry_test.dart`, `google_cloud_account_concurrent_sign_in_test.dart`, `cloud_workmanager_test.dart`, and the extended `google_drive_store_test.dart`. App: `local_backup_adoption_journal_test.dart` (process-kill resume), `local_backup_adoption_backup_verified_test.dart`, `local_backup_adoption_retention_test.dart`, `account_chained_journeys_test.dart`, `start_fresh_draft_reuse_test.dart`, `guest_workspace_listing_test.dart`, `guest_workspace_management_screen_test.dart`, and the extended `cloud_setup_choice_screen_test.dart` and `local_backup_service_test.dart`.

Product fixes made during verification: a Drive authorization rejection (HTTP 401) now parks the workspace in `needs_sign_in` in both the foreground provider and the scheduled worker, instead of leaving it retryable `pending`; the pending-changes check now compares the sync cursor against the owning workspace's revision (the domain the engine writes) rather than the global db_revision; the initial-backup pending marker is cleared with the already-canonical workspace ID (it was double-prefixed, so the marker never cleared); the rename dialog's `TextEditingController` is now owned by the dialog widget, fixing use-after-dispose during the exit animation; downloaded backups are verified against the Drive metadata size in addition to the content hash. Behaviours completed: Start Fresh reuses an existing empty Guest draft instead of creating another; the delete confirmation shows the workspace's Qaza and daily Salah record counts; empty drafts are hidden from Guest listings while remaining resumable.

Known limitations (from the gap report's closure section): Scenario 11 — real WorkManager/Doze behaviour is device-only. Scenario 13 — journal-seeded process-kill tests cover adoption only; restore/migration interruption is covered at engine level because only adoption is journaled. Scenario 16 (divergence) — migrated legacy Guests with incomplete profiles are not marked `draft`; the migrator preserves the legacy lifecycle and StartupGate routes incomplete profiles. Scenario 17 — the rename-dialog limitation was resolved by the controller fix above and the dialog flow is now widget-tested. Scenario 18 — Google workspaces have no `draft` lifecycle; cancelled Google onboarding resumes through StartupGate profile routing, with no dedicated widget test. Scenario 20 — the workmanager mid-run account switch is proven by composing the engine run, the worker's state write, and next-run settlement, not by driving the worker entry point. Scenario 22 (divergence) — the stored `last_synced_local_hash` column is written but never read; the working baseline is the sync cursor plus verified Drive metadata. Scenario 24 — there is no user-initiated adoption-snapshot deletion; purge happens only after a verified backup plus 30 days, evaluated when verification runs.

Phase 6 stays unticked: the automated gates are complete and CI will be re-confirmed on the new head, but physical-device verification remains outstanding. A manual script is prepared (`TP-GEN_Phase6_Real_Device_Test_Script.md`, 37 cases). Consistent with invariant 5, no real-device Google/Drive validation is claimed by this note.

## Safety invariants

1. A scheduled sync captures one verified Google ID and reads/writes only its matching local workspace.
2. Unknown Drive status is not equivalent to no backup; block destructive restore/adoption and block upload until reconciliation.
3. Never delete local data after sign-out, offline sign-out, failed backup, rejected migration, or failed restore.
4. A failed validation/migration keeps both the existing local ledger and remote backup unchanged and reports an actionable error.
5. A passing build does not establish real Google Drive behavior; physical-device sign-in, account-switch, upload, restore, and offline cases remain mandatory.
