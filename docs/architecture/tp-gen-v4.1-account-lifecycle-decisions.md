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
- [ ] Phase 3: complete metadata/content verification and regression testing for no-backup, found, legacy, and unknown/unverifiable Drive states; unknown state must block restore/adoption and upload.
- [ ] Phase 4: complete explicit Drive metadata validation (stable Google ID, workspace ID, schema and content hash), verified write/readback, Keep Both recovery-copy validation, and stale conflict handling.
- [ ] Phase 5: complete online/offline pending-backup sign-out, account-switch, cancellation, and interruption recovery tests.
- [ ] Phase 6: all lifecycle regression scenarios passing, required CI green, release artifact review, and physical-device verification report.

## Safety invariants

1. A scheduled sync captures one verified Google ID and reads/writes only its matching local workspace.
2. Unknown Drive status is not equivalent to no backup; block destructive restore/adoption and block upload until reconciliation.
3. Never delete local data after sign-out, offline sign-out, failed backup, rejected migration, or failed restore.
4. A failed validation/migration keeps both the existing local ledger and remote backup unchanged and reports an actionable error.
5. A passing build does not establish real Google Drive behavior; physical-device sign-in, account-switch, upload, restore, and offline cases remain mandatory.
