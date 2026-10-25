# TP-GEN Progress Tracker — Supabase Offline-First Rebuild

**Status:** Run A: OPEN, blocked on PoC execution; ADR-001 proposed, no backend implementation approved
**Run A gate:** OPEN — proceed with free, isolated local PoC only; do not start backend implementation.  
**Last updated:** 2026-10-25 (Asia/Karachi)  
**Repository:** `a-kabeer/Qaza-Namaz`  
**Working branch:** `tp-gen/supabase-run-a-adr`  
**Current documentation-review base:** `4e9747ed2005806ae81ede78ef2448af9b483aa7`  
**Original architecture-baseline commit:** `565d11f4db150ebcb64cb2cf5e96271821a8a997`  
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
| Run A — source/CI baseline | COMPLETE | Reviewed main at 4e9747ed2 and current CI workflow definitions. |
| CI-AM — baseline test timeout repair | COMPLETE | Existing main's focused regressions and current CI are green; this validates only the app/CI repair, not sync compatibility. |
| Run A — official-docs, options and cost research | COMPLETE — qualitative research | ADR-001 is the single source of research findings and cost snapshot. Recheck prices and terms before provisioning. |
| Run A — workspace topology decision (W1 vs W2) | OPEN — prerequisite | Test minimum encryption in both layouts in POC-1; decide after POC-0 and POC-2, before account-lifecycle experiments. |
| Run A — Qaza event/conflict policy | OPEN — prerequisite | Proposed append-only completion/reversal event model and revision-checked RPC require mapping to real domain/test behavior. |
| POC-0 — toolchain, isolated package, license/version checks and CI fallback | NOT RUN | Capture actual tool output; if local tools are missing, use read-only Docker-capable CI with exact SHA/run. |
| POC-1 — encryption, W1/W2 layouts, wrong key/plaintext header/Base64URL format | NOT RUN | Verify 32-byte Base64URL handling, fail-closed wrong key, no plaintext SQLite header, and both layouts. |
| POC-2 — isolated Drift/data layer/schema and unchanged root architecture checks | NOT RUN | Own pubspec/lockfile outside production package tree; root checks run unchanged on a clean root checkout. |
| POC-3 — Qaza events/reversal/idempotency/revision RPC/queue status | NOT RUN | Unknown pending count must never appear as zero; classify permanent errors. |
| POC-4 — local Docker sync, restart/offline replay and acknowledgement | NOT RUN | Use disposable local volumes, keys and synthetic data only. |
| POC-5 — email/password test users, RLS, publication/Sync Streams and queue isolation | NOT RUN | Two-user server-side isolation is a blocking security gate. |
| POC-6a — Guest adoption, existing cloud data, Restore, Cancel and Guest after sign-out | NOT RUN | No binding/exposure/upload before reconciliation decision. |
| POC-6b — expiry/revocation, same-owner re-auth and permanent-error classification | NOT RUN | Retain owner-bound queue; a different user cannot claim it. |
| POC-7a — key loss, Android backup/restore, reinstall/transfer | NOT RUN | Never silently replace unreadable data with an empty DB. |
| POC-7b — crash-safe local wipe, cloud deletion and stale queued writes | NOT RUN | Local wipe is separate from server-side account/data deletion. |
| POC-8 — Android builds, relevant tests and check-only formatting/root checks | NOT RUN | Do not use write-capable auto-format/push workflows for experiment evidence. |
| POC-GOOGLE — Google-to-Supabase Auth, UUID stability and provider linking | NOT RUN | Requires explicit approval and a throwaway test OAuth client; email/password tests do not cover Google sign-in. |
| Run A — ADR | PROPOSED, awaiting PoC evidence | ADR-001 documents the candidate and quantified no-go gates; not approved for implementation. |
| Human approval before implementation | REQUIRED | Stop after Run A. Do not implement backend until PoC evidence and approved ADR are complete. |

## Repository baseline

- Remote default branch: `main`.
- Current main SHA for this review: `4e9747ed2005806ae81ede78ef2448af9b483aa7` (`Fix account-choice CI timeouts and document Supabase migration baseline`).
- Original code-inspection baseline: `565d11f4db150ebcb64cb2cf5e96271821a8a997` (`Remove Google Drive; keep Google identity and local storage`).
- Earlier planning branch `tp-gen/supabase-offline-first` was created from the original baseline; the current documentation-only review branch is `tp-gen/supabase-run-a-adr`.
- Baseline report: `docs/architecture/supabase-migration-baseline.md`.
- Root app uses Drift `^2.35.0`, SQLite `^3.5.2`, SQLite3MultipleCiphers hook, and `flutter_secure_storage` `^10.3.4`.
- Root app database schema version is 26.
- `apps/qaza_app_cloud` currently describes itself as Google Sign-In and local-only host; Supabase is not implemented.
- Repository `AGENTS.md` confirms pre-release status and disposable test data. Its storage-redesign wording still mentions Google Drive backup and per-account encrypted databases; treat it as stale where it conflicts with current main and update it after the architecture is approved.

## CI-AM — pre-implementation CI audit and fix

**Historical baseline result: RED; current status: FIXED AND VERIFIED.**

Baseline evidence from `main`:
- Flutter CI run [40131841997](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40131841997) and Google Identity App CI run [40131842012](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40131842012) both showed 758 tests passed and four 10-minute timeouts in `test/features/onboarding/account_choice_screen_test.dart`.
- Failing cases were:
  1. `Google sign-in creates or resumes a local Google workspace`
  2. `Continue as Guest offers saved local workspaces and Start Fresh`
  3. `Google sign-in offers an explicit local Guest adoption`
  4. `Google identity failure leaves local account choice available`

### Fix applied

- The shared test harness did real temporary-directory I/O and native Drift database/session setup directly inside `testWidgets`' fake-async zone. The tests timed out before mounting the account-choice UI.
- The test harness now runs real filesystem/native database setup and teardown via `tester.runAsync`; direct database setup and readback in test bodies also use the real async path.
- Replaced unbounded `pumpAndSettle()` calls with bounded waits for expected UI states. Each of the four regression tests has a 45-second limit.
- Added a preflight that runs the four named regression tests individually before code generation and the full suite, so a recurrence fails early with a specific test result.
- No application behavior was changed, no test was deleted, and no assertion was weakened.

### Verification evidence

- [Flutter CI run 40170592701](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40170592701) completed successfully. The four-test preflight passed, then the full root `flutter test --coverage` suite passed. The workflow ran Dart formatting and pushed the formatting-only follow-up commit `c4f0004b960b5afe9a0c3ce39b4f09ae28d77fee` during the successful job.
- [Google Identity App CI run 40170592703](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40170592703) completed successfully. The preflight passed, the full offline-app suite passed, Google identity host tests passed, and the Google identity Android release APK built successfully.
- Both workflows use Flutter `3.47.4`. These checks verify CI-AM for the current test-harness fix. The original failing runs remain linked above as historical baseline evidence.
- CI workflows contain `contents: write` and can auto-format/commit/push on branch pushes; account for that when comparing run head SHA with the latest branch head.

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
- **Run B implementation planning:** only after Run A evidence is complete and the user explicitly approves the ADR.
- These criteria are planning requirements. They do not mean the ADR is decided or any app/backend implementation is complete.

## Latest CI and branch state

- Main after PR #351: 4e9747ed2005806ae81ede78ef2448af9b483aa7.
- [Flutter CI on the merged main commit — run 40172042979](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40172042979): completed successfully.
- [Google Identity App CI on the merged main commit — run 40172042972](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40172042972): completed successfully.
- These runs verify the merged test/CI repair, **not** PowerSync, Supabase, encryption interoperability, two-user isolation or cross-device conflict behavior.
- Supabase is not implemented; no PowerSync PoC has run. The proposed ADR remains unapproved.
- Documentation branch `tp-gen/supabase-run-a-adr` was created from main at `4e9747ed2`; it contains ADR/tracker/baseline documentation only. Original prior planning branch `tp-gen/supabase-offline-first` began at `565d11f4d`; that earlier SHA is the code-inspection baseline, not the current main HEAD.

## Change log

- 2026-10-25: Created feature branch from audited main SHA.
- 2026-10-25: Inspected root and host dependency manifests, AGENTS.md, encryption/database/session code, account-choice tests, architecture policy scripts, and both CI workflows.
- 2026-10-25: Recorded the shared four-test CI timeout baseline and created the migration baseline report.
- 2026-10-25: Added official package, RLS, and pricing research.
- 2026-10-25: Added account-reconciliation, crash-safe wipe, ownership matrix, queued-change ownership, masked-email, destructive-warning, test, and phase-mapping criteria to the tracker. Planning documentation only; no application code has been changed.
- 2026-10-25: Fixed the account-choice test harness by running native filesystem/Drift setup and teardown through `tester.runAsync`; replaced `pumpAndSettle()` waits with bounded UI waits.
- 2026-10-25: Added CI preflight commands to run each failing account-choice test individually before generated-code work/full suite.
- 2026-10-25: CI-AM verified green: both relevant workflows passed the focused tests; root and offline full suites passed; Google identity host tests and APK build passed.



- 2026-10-25: Incorporated the external review: added W1/W2 topology gate; Qaza append-only completion/reversal candidate; Auth expiry/deletion and provider-linking cases; key-loss/Android backup; sensitive-data treatment; queue-count requirement; local self-host PoC path; quantified no-go triggers; and POC-0 through POC-8 ledger. Runtime experiments remain NOT RUN.
## Research source of truth

All official documentation, version snapshots, candidate options, security implications and cost notes belong in [ADR-001](adr-001-supabase-powersync-candidate.md). This tracker records current gate status and links the source of truth to avoid duplicating research that can drift. The [migration baseline](supabase-migration-baseline.md) records repository facts and environment readiness.

## Run A: OPEN — current status

- **Source inventory and baseline:** COMPLETE.
- **Official-docs and qualitative options review:** COMPLETE; details live in ADR-001.
- **Workspace topology (W1 vs W2):** OPEN; POC-1 tests minimum encryption in both layouts; decide after POC-0 and POC-2, before lifecycle experiments.
- **Qaza completion/undo conflict policy:** OPEN; map append-only event candidate to current domain behavior and tests.
- **PoC:** NOT RUN. Use an independently versioned package outside the production app tree; local self-hosted Docker is the intended zero-budget route, with a read-only CI fallback if the local toolchain is missing.
- **ADR:** PROPOSED only; owner approval required before Run B.
- **Implementation:** NOT APPROVED; no app/backend behavior may be changed by this documentation PR.

## Experiment ledger
## Run A evidence rules and closure

- Define expected outcomes before executing each experiment. Every row needs **PASS**, **FAIL**, or **BLOCKED**, exact command(s), PoC commit SHA, CI run URL if used, and an evidence summary. **NOT RUN** never implies PASS.
- Use an independently versioned PoC package with its own manifest/lockfile outside the production app package tree. Run `tools/offline_architecture_check.py` and `tools/phase_boundary_check.py` unchanged against a clean production checkout; record the intended future integration boundary separately.
- If local tool/version checks fail, use a Docker-capable CI path that is read-only, formatting check-only and cannot auto-format/commit/push. Preserve the local setup failure as part of the evidence.
- Overall execution timebox: two engineering days after Step 0 prerequisites are runnable. Any extension requires an explicit owner decision.
- Run A closes only when every ledger row has an evidence-backed result (including POC-GOOGLE, or an explicitly owner-approved written deferral), ADR-001 is revised to **Accepted** or **Rejected**, and the owner explicitly decides whether Run B is authorized. No backend/app implementation is approved while this gate is open.


See the authoritative list of POC-0 through POC-8 plus POC-GOOGLE, detailed commands, pass/fail criteria, timebox, licensing gate and exit conditions in [ADR-001 §9](adr-001-supabase-powersync-candidate.md). All experiments remain NOT RUN until exact commands, PoC SHA, CI run URL where applicable and evidence summary are recorded. [Stable ADR commit permalink](https://github.com/a-kabeer/Qaza-Namaz/blob/b2bbb20fb09f3492d306dcedecff9518bfe08300/docs/architecture/adr-001-supabase-powersync-candidate.md).

## Current main CI baseline

- [Flutter CI — run 40172042979](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40172042979): success on merged main commit \`4e9747ed2\`.
- [Google Identity App CI — run 40172042972](https://github.com/a-kabeer/Qaza-Namaz/actions/runs/40172042972): success on the same commit.
- These runs verify current app/CI behavior, not PowerSync or Supabase compatibility.


- 2026-10-25: Applied second review: added separate Google OAuth experiment, standalone PoC package boundary, read-only CI fallback, after-POC-2 W1/W2 checkpoint, split lifecycle/key/wipe tests, Base64URL/plaintext-header checks, quantified pass/fail/timebox/exit criteria, and a licensing/terms gate. All runtime experiments remain NOT RUN.
