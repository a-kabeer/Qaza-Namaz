# TP-GEN Progress Tracker — Supabase Offline-First Rebuild

**Status:** Run A in progress  
**Last updated:** 2026-10-25 (Asia/Karachi)  
**Repository:** `a-kabeer/Qaza-Namaz`  
**Working branch:** `tp-gen/supabase-offline-first`  
**Base commit:** `565d11f4db150ebcb64cb2cf5e96271821a8a997`  
**Purpose:** Living record for the Supabase architecture audit. Update after each meaningful audit, experiment, decision, test, or blocker. Do not mark a gate complete without evidence.

## Scope and guardrails

- V1 supports one active authenticated cloud account per app installation; multi-device sync is required.
- Local-only guest use remains supported, with explicit guest-to-cloud adoption.
- Sign-out warns about pending changes, retains the encrypted workspace and queue, and suspends sync until the same account signs in again.
- “Sign out and remove data from this device” is a separate explicit action; it removes local workspace data, key, queue, sync metadata, owner binding, sensitive cache, and local session. It does not delete cloud data.
- Cloud-account deletion is separate. Any retained local copy becomes local-only; old queued work must not recreate deleted cloud data.
- Do not implement the backend or change production application behavior before ADR approval.
- Protect unrelated work. Test-only data is disposable, but destructive operations must remain scoped to this app's own test data.
- Repository instructions, secret handling, security controls, formatting, lint, and meaningful tests remain in force.

## Gate status

| Gate | Status | Evidence / notes |
|---|---|---|
| Run A — repository and CI baseline | IN PROGRESS | Remote main and CI inspected; see findings below. |
| Run A — environment readiness | BLOCKED / NOT VERIFIED | GitHub-connected inspection only; no local Windows working tree, Docker/Supabase CLI, Android SDK/emulator, or PowerSync service available in this session. |
| Run A — PowerSync/encryption/Drift PoC | NOT STARTED | Requires an executable environment; no compatibility claim made. |
| Run A — custom-sync fallback and cost comparison | NOT STARTED | To complete after focused research. |
| Run A — ADR | NOT STARTED | Must include evidence, package versions/date, account model, encryption/key recovery, costs, security, conflict rules, and fallback trigger. |
| Human approval | REQUIRED | Stop after Run A and obtain explicit user approval before Run B/backend implementation. |

## Repository baseline

- Remote default branch: `main`.
- Audited main SHA: `565d11f4db150ebcb64cb2cf5e96271821a8a997`.
- Commit message: `Remove Google Drive; keep Google identity and local storage`.
- Root app uses Drift, SQLite, SQLite3MultipleCiphers hook, and `flutter_secure_storage`.
- `apps/qaza_app_cloud` currently describes itself as Google Sign-In and local-only host; Supabase is not implemented.
- Repository `AGENTS.md` confirms pre-release status and that test data is disposable, while retaining normal correctness and security requirements.
- Latest remote main CI runs inspected: Flutter CI run [40131841997](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40131841997) and Google Identity App CI run [40131842012](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40131842012).

## CI-AM — pre-implementation CI audit

**Baseline result: NOT GREEN.**

- Flutter CI: Analyze, test, and offline architecture checks job failed during `flutter test --coverage`; Android release artifacts job succeeded.
- Google Identity App CI: Protect offline application job failed during `flutter test --coverage`; Google identity Android host analyze/build job succeeded.
- Both failing test runs report 758 tests passed and four failures. The same four tests each timed out after 10 minutes:
  1. `Google sign-in creates or resumes a local Google workspace`
  2. `Continue as Guest offers saved local workspaces and Start Fresh`
  3. `Google sign-in offers an explicit local Guest adoption`
  4. `Google identity failure leaves local account choice available`
- Analysis, formatting, offline architecture policy, phase-boundary policy, dead-code/dependency audit, and Android artifact/build steps passed in the inspected runs.
- This is a baseline blocker, not yet attributed to the Supabase work. Do not weaken or delete these tests. Investigate the common hang, reproduce targeted tests, and record whether it is caused by provider/container lifecycle, widget pumping, pending asynchronous work, or test-environment behavior.
- Current workflow definitions use Flutter 3.47.4. Verify whether this is intentional relative to the repository's current SDK policy before changing it.
- CI workflows have `contents: write` and can auto-format/commit/push on branch pushes. Review this behavior before using the workflow on the feature branch; avoid unintended bot commits or branch mutation.

## Next actions

1. Finish baseline inventory: database encryption/key lifecycle, app composition, local persistence/write paths, account/session behavior, CI conventions, and current dependencies.
2. Investigate the four baseline test timeouts as CI-AM, using targeted test evidence where an executable environment is available. Do not change product behavior or mask failures.
3. Verify prerequisites and current official package versions.
4. Run a focused PowerSync + encryption + Drift compatibility spike in an isolated throwaway location if an executable environment becomes available.
5. Compare custom sync as fallback and document cost/operational burden.
6. Produce the ADR and baseline report; stop for explicit approval.

## Change log

- 2026-10-25: Created the Supabase feature branch from the audited main SHA and began the remote repository/CI baseline audit.
- 2026-10-25: Recorded two failing CI workflows with the same four account-choice test timeouts; Android build jobs succeeded.
