# TP-GEN Progress Tracker — Supabase Offline-First Rebuild

**Status:** Run A in progress; account-safety requirements added to plan; CI-AM remains RED pending diagnosis/fix  
**Last updated:** 2026-10-25 (Asia/Karachi)  
**Repository:** `a-kabeer/Qaza-Namaz`  
**Working branch:** `tp-gen/supabase-offline-first`  
**Base commit:** `565d11f4db150ebcb64cb2cf5e96271821a8a997`  
**Purpose:** Living record for the Supabase architecture audit. Update after each meaningful audit, experiment, decision, test, or blocker. Do not mark a gate complete without evidence.

## Scope and guardrails

- V1 supports one active authenticated cloud account per app installation; multi-device sync is required.
- Local-only guest use remains supported, with explicit guest-to-cloud adoption.
- Sign-out warns about pending changes, retains the encrypted workspace and queue, and suspends sync until the same account signs in again.
- “Sign out and remove data from this device” is a separate explicit action; it removes local workspace data, key, queue, sync metadata, owner-binding metadata, sensitive cache, and local session. It does not delete cloud data.
- Cloud-account deletion is separate. Any retained local copy becomes local-only; old queued work must not recreate deleted cloud data.
- Guest and signed-in user messages must not promise cloud recovery unless a recoverable cloud copy exists.
- Do not implement the backend or change production application behavior before ADR approval.
- Protect unrelated work. Test-only data is disposable, but destructive operations must remain scoped to this app's own test data.
- Repository instructions, secret handling, security controls, formatting, lint, and meaningful tests remain in force.

## Gate status

| Gate | Status | Evidence / notes |
|---|---|---|
| Run A — repository and CI baseline | COMPLETE | Remote main and both current workflow definitions inspected. Baseline report created. |
| CI-AM — diagnose/fix baseline test timeouts | BLOCKED | Four identical 10-minute timeouts confirmed; fixing requires running targeted Flutter tests. This session has no checked-out working tree, Flutter executable, or Android SDK. No test fix is claimed. |
| Run A — environment readiness | BLOCKED / NOT VERIFIED | GitHub-connected inspection only; local Windows working tree, Docker/Supabase CLI, Android SDK/emulator, and PowerSync service are not available in this session. |
| Run A — PowerSync/encryption/Drift PoC | NOT STARTED | Requires an executable environment; no compatibility claim made. |
| Run A — custom-sync fallback and cost comparison | NOT STARTED | To complete after focused research. |
| Run A — ADR | NOT STARTED | Must include evidence, package versions/date, account model, encryption/key recovery, costs, security, conflict rules, and fallback trigger. |
| Human approval | REQUIRED | Stop after Run A and obtain explicit user approval before Run B/backend implementation. |

## Repository baseline

- Remote default branch: `main`.
- Audited main SHA: `565d11f4db150ebcb64cb2cf5e96271821a8a997`.
- Commit message: `Remove Google Drive; keep Google identity and local storage`.
- Feature branch created from that SHA: `tp-gen/supabase-offline-first`.
- Baseline report: `docs/architecture/supabase-migration-baseline.md`.
- Root app uses Drift `^2.35.0`, SQLite `^3.5.2`, SQLite3MultipleCiphers hook, and `flutter_secure_storage` `^10.3.4`.
- Root app database schema version is 26.
- `apps/qaza_app_cloud` currently describes itself as Google Sign-In and local-only host; Supabase is not implemented.
- Repository `AGENTS.md` confirms pre-release status and disposable test data. Some of its architecture-specific wording still mentions Google Drive backup and per-account databases; treat that as stale against current main and update it only with the approved redesign.

## CI-AM — pre-implementation CI audit

**Baseline result: RED.**

- Flutter CI run [40131841997](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40131841997): test job failed; Android release artifacts job succeeded.
- Google Identity App CI run [40131842012](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40131842012): offline test job failed; Google identity Android host analyze/build job succeeded.
- Both failed test runs report 758 tests passed and four failures. The same four tests each timed out after 10 minutes:
  1. `Google sign-in creates or resumes a local Google workspace`
  2. `Continue as Guest offers saved local workspaces and Start Fresh`
  3. `Google sign-in offers an explicit local Guest adoption`
  4. `Google identity failure leaves local account choice available`
- Analysis, formatting, offline architecture policy, phase-boundary policy, and dead-code/dependency audit passed in the inspected runs.
- The failing tests use asynchronous account/session/database flows and `pumpAndSettle()` in the relevant journeys. This is a diagnostic lead only; logs do not establish the root cause.
- Both workflows use Flutter 3.47.4. Confirm whether this is intentional against the repo's current SDK policy before changing it.
- Workflows have `contents: write` and may auto-format/commit/push on branch pushes. Account for this before interpreting branch CI.
- Do not remove tests, weaken assertions, or change product behavior to hide the failures.
- A remote re-run alone would likely spend up to 40 minutes timing out again without new diagnostic instrumentation; targeted local reproduction is the next useful action.
- This session could not run Flutter tests, Android builds, Docker, Supabase CLI, or the PowerSync PoC: there is no checked-out repository and shell network access to GitHub is unavailable. Remote source and CI evidence were inspected instead.

## Architecture findings

- The existing key store uses `flutter_secure_storage` and a 32-byte random key encoded as Base64URL. The key is not intentionally stored in SQLite or SharedPreferences.
- The encrypted database opener applies `PRAGMA key`, checks cipher support, and validates the key before Drift queries. The root manifest configures SQLite3MultipleCiphers using the `sqlite3mc` build hook.
- Current code has a control database, registry-based workspace resolution, workspace factories, and account-session management. This is evidence of the existing implementation, not a requirement to preserve it.
- V1 is one active authenticated cloud account per app installation, multi-device synchronization, and local-only guest usage. The ADR should compare one encrypted local database bound to the active identity with the selected sync engine's managed database.
- Guest adoption remains a product requirement. Existing cloud data must not be silently overwritten or merged.
- No sync-engine choice has been made. Encryption compatibility, Drift integration, Android release build, and database ownership remain unproven.

## Account ownership, reconciliation, and destructive-action requirements

These requirements are accepted into the planning scope. They are design/test criteria only; no application behavior or backend has been implemented.

### Pending account reconciliation and Cancel

- Completing provider sign-in must not by itself bind a local workspace, expose workspace data, or start synchronization while cloud/account reconciliation is pending.
- Keep the account and workspace context in a pending/isolated state until reconciliation resolves.
- Cancel must sign out the newly authenticated account, leave the previous local workspace unchanged, and guarantee no data was exposed or synced during the pending check.
- Do not assume the prior provider session can always be restored; if necessary, require the previous account to sign in again.
- If the target account already has cloud data, present an explicit restore/adopt/reconcile decision; never silently overwrite or merge.

### Crash-safe local wipe

- Persist a durable wipe-in-progress marker outside the database and outside the encryption key being removed.
- Delete the relevant encryption key first, then remove workspace database files (including SQLite sidecars), pending changes, sync metadata, ownership bindings, cached identity/email, and local session state.
- Keep the marker until cleanup is verified complete. On every startup, recover any marked wipe before opening the affected database, selecting a workspace, or exposing account data.
- Recovery must be idempotent and tolerate interruption at every step. Failed cleanup leaves the marker for retry. Wiping local data must never silently delete cloud data.
- “Remove data and continue” must show an explicit irreversible-loss warning and the real pending-change count. If the count cannot be determined reliably, do not display zero or imply there are no pending changes.

### Ownership matrix required in the ADR

| Local state | Identity selected | Required outcome |
|---|---|---|
| Empty, unbound workspace | Account X | Bind to X |
| Data-bearing Guest workspace | Account X | Explicit guest-to-X adoption only |
| Workspace owned by Account X | Account X | Resume X |
| Workspace owned by Account X | Account Y | Block direct rebinding; use the defined account-switch/reconciliation flow |
| Wipe marker present | Any identity | Complete/recover wipe before account access |

“Unowned” must distinguish an empty workspace from a data-bearing guest workspace. Guest-to-cloud adoption is the only permitted ownership change, and it must pass through the explicit adoption screen. Define behavior for existing target-account cloud data before approving adoption.

### Ownership on queued changes and server enforcement

- Use the immutable Supabase Auth user ID as the owner key, never email or masked email.
- Each queued cloud mutation must retain its owner identity from enqueue time where the selected sync engine exposes an application-managed queue.
- The upload path must refuse or quarantine any queued change whose owner differs from the currently authenticated user. Never rewrite a mismatched owner to make upload pass.
- Supabase RLS must independently block unauthorized reads/writes; client-side owner checks are not the security boundary.
- If PowerSync is selected, verify its upload queue/metadata model before adding a duplicate custom queue or redundant ownership mechanism.

### Identity display and deletion semantics

- Masked email is only a display hint; it is not an authorization key or durable account identifier.
- Remove the cached email during the local wipe.
- Clearly distinguish removal of local device data from deletion of cloud data. Account deletion is a separate explicit operation.

### Required tests and phase mapping

- **Phase 4 tests:** (1) Cancel signs out the newly authenticated account, preserves old local data, and exposes/syncs nothing during reconciliation; (2) an interrupted wipe is completed safely on next startup, including failure injection between each stage; (3) an upload with a mismatched owner is refused client-side and unauthorized server writes are denied by RLS.
- **Phase 5 UI:** pending reconciliation/cancel flow and explicit guest adoption; local-data removal confirmation with actual pending-change count and irreversible-loss warning.
- **Run A ADR:** ownership matrix, cancellation contract, wipe protocol, queued-change ownership, email/display-only policy, cloud-existing-data behavior, and architecture-specific proof for the chosen sync engine.
- **Run C implementation:** only after Run A evidence is complete and the user explicitly approves the ADR.
- These criteria do not mean the ADR is decided, CI-AM is fixed, or any app implementation is complete.

## Next actions

1. In a runnable Windows/Flutter environment, reproduce the four timeouts individually with expanded test output; identify the shared hang and apply the smallest justified fix.
2. Re-run targeted tests, then the full Flutter test suite and both CI workflows. Record exact results; do not claim CI-AM complete until green or a justified, explicitly documented external blocker is accepted.
3. Complete remaining source inventory and environment checks.
4. Verify current official package versions/release notes.
5. Run the focused PowerSync/encryption/Drift compatibility spike in an isolated throwaway location. If one encryption option fails, test the other supported documented option before rejecting PowerSync.
6. Compare custom sync as fallback, including cost and operational burden.
7. Create the ADR and present evidence to the user.
8. **Stop for explicit approval. Do not begin backend implementation before approval.**

## Current branch CI

- Latest branch head at last status check: `4ae584b18e239b328a5e4ba4488428b8a7fdb924` (`docs: track initial PowerSync research and branch CI`).
- Latest Flutter CI run: [40166108911](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40166108911), status `in_progress` when checked. Setup, pub get, localization/Drift code generation, offline architecture policy, phase-boundary policy, dead-code/dependency audit, analysis, and formatting completed successfully; `Test with coverage` was still running. This is **not a green CI result**.
- Earlier docs-only runs [40166074570](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40166074570) and [40166098688](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40166098688) were cancelled by newer branch pushes; they do not provide a complete test result.
- The known main-branch baseline remains RED due to four 10-minute account-choice test timeouts. No fix is claimed.
- No application/backend code has been changed. No PowerSync encryption/Drift proof of concept has run. CI-AM remains unresolved until the shared timeout is diagnosed and a justified fix passes targeted tests and full CI.

## Change log

- 2026-10-25: Created feature branch from audited main SHA.
- 2026-10-25: Inspected root and host dependency manifests, AGENTS.md, encryption/database/session code, account-choice tests, architecture policy scripts, and both CI workflows.
- 2026-10-25: Recorded the shared four-test CI timeout baseline and created the migration baseline report.
- 2026-10-25: Added official package, RLS, and pricing research.
- 2026-10-25: Added account-reconciliation, crash-safe wipe, ownership matrix, queued-change ownership, masked-email, destructive-warning, test, and phase-mapping criteria to the tracker. Planning documentation only; no application code has been changed.
- 2026-10-25: Refreshed branch CI status; test-with-coverage remains in progress and CI-AM remains unresolved.
