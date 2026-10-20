# TP-GEN v4.1 — Account lifecycle decisions and implementation status

This record captures the account/workspace decisions for the Qaza Namaz account-lifecycle refactor. It is a living decision record, not a substitute for green CI or real-device validation.

## Phase 0 — Decisions

### D1. Local storage model — shared SQLite database, explicitly scoped workspaces

Keep the existing encrypted shared SQLite database. Each account-owned row retains an explicit workspace owner (user_id or local_account_id), and cloud export/import must always receive the target workspace explicitly. A one-file-per-workspace migration is not justified by this audit and would introduce a second storage migration.

Schema v23 introduces a monotonically increasing workspace_revision:<workspace-id> counter maintained by SQLite triggers for workspace-owned rows and workspace preferences. Scoped cloud snapshots and sync checks use that revision; the global db_revision remains available for full local exports and compatibility.

### D2. Workspace identifiers

The target format for newly created workspaces is guest_<uuid> for Guest and google_<stableGoogleAccountId> for Google. Google identity must come from the verified stable Google account ID, never from email or display name. Existing guest, guest:<uuid>, and google:<id> IDs are legacy data and must be migrated without losing or merging records; identifier-format migration remains a gated schema task until row/reference parity tests pass.

### D3. Guest adoption and recovery

Adoption must start only after Google identity is verified and Drive discovery has returned a definite, validated no-backup result. Save and read-back-verify a recovery snapshot before changing ownership; never overwrite an existing Google workspace. The desired operation journal is prepared → snapshotted → copied → verified → committed → cleaned, with an idempotency key based on source Guest ID plus verified Google ID. The current implementation has snapshot-before-transfer and a transactional ownership change, but the full resumable journal, parity verification, and retention/cleanup policy are still required.

### D4. Local/cloud conflict choice

The user-facing choices are Keep Local, Keep Cloud, and Keep Both. Keep Both must preserve the local workspace and create a separately labelled recovery_copy workspace for the other version. Existing two-choice conflict handling is not yet complete against this decision.

### D5. Recovery across process death

Any multi-step adoption or restore must have durable journal state and be resumable or safely rolled back before the startup gate exposes the workspace. The existing single-transaction ownership transfer prevents partial row remapping, but the surrounding workflow still needs a durable journal and process-death tests.

### D6. Deletion semantics — whole-workspace snapshots

The current cloud adapter synchronizes a versioned, whole-workspace snapshot and does not perform record-level cloud merges. Deletions are therefore represented by the next verified whole-workspace upload, not by record-level tombstones. Conflict resolution must preserve both whole snapshots until the user decides; do not add a second tombstone system unless sync is redesigned to merge individual records.

## Phase gate checklist

- [x] Phase 0: audit current shared-database ownership and record D1–D6 decisions.
- [x] Phase 1 (partial): make scheduled cloud backup/restore workspace-scoped and add workspace-local revision tracking.
- [ ] Phase 1: complete identifier migration, persisted lifecycle/sync metadata, and row/reference parity migration tests.
- [x] Phase 2 (partial): distinct named Guest workspaces and onboarding flow exist.
- [ ] Phase 2: draft resume, rename/delete with seven-day hold and Undo, and duplicate-name disambiguation.
- [ ] Phase 3: fully reconcile existing, empty, legacy, and unknown/unverifiable Drive backups without treating an unknown result as no backup.
- [ ] Phase 4: embedded Google identity + schema/workspace metadata, content hashes, Keep Both, and verified cloud write/readback.
- [ ] Phase 5: finalize pending-backup online/offline sign-out branches without deleting or hiding local records.
- [ ] Phase 6: all lifecycle regression scenarios, clean CI, and physical-device verification report.

## Safety invariants

1. A scheduled sync captures one verified Google ID and reads/writes only its matching local workspace.
2. Unknown Drive status is not equivalent to no backup; block destructive restore/adoption and block upload until reconciliation.
3. Never delete local data after sign-out, offline sign-out, failed backup, rejected migration, or failed restore.
4. A failed validation/migration keeps both the existing local ledger and remote backup unchanged and reports an actionable error.
5. A passing build does not establish real Google Drive behavior; physical-device sign-in, account-switch, upload, restore, and offline cases remain mandatory.
