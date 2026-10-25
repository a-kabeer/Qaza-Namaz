# TP-GEN Progress Tracker — Supabase Offline-First Rebuild

**Status:** Run A in progress; CI-AM baseline audit complete, repair blocked by execution environment  
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

## Next actions

1. In a runnable Windows/Flutter environment, reproduce the four timeouts individually with expanded test output; identify the shared hang and apply the smallest justified fix.
2. Re-run targeted tests, then the full Flutter test suite and both CI workflows. Record exact results; do not claim CI-AM complete until green or a justified, explicitly documented external blocker is accepted.
3. Complete remaining source inventory and environment checks.
4. Verify current official package versions/release notes.
5. Run the focused PowerSync/encryption/Drift compatibility spike in an isolated throwaway location. If one encryption option fails, test the other supported documented option before rejecting PowerSync.
6. Compare custom sync as fallback, including cost and operational burden.
7. Create the ADR and present evidence to the user.
8. **Stop for explicit approval. Do not begin backend implementation before approval.**

## Change log

- 2026-10-25: Created feature branch from audited main SHA.
- 2026-10-25: Inspected root and host dependency manifests, AGENTS.md, encryption/database/session code, account-choice tests, architecture policy scripts, and both CI workflows.
- 2026-10-25: Recorded the shared four-test CI timeout baseline and created the migration baseline report.
