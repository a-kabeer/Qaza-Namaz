# TP-GEN Progress Tracker — Supabase Offline-First Rebuild

**Status:** Run A: OPEN, blocked on PoC execution; ADR-001 proposed, no backend implementation approved  
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
| Run A — workspace topology decision (W1 vs W2) | OPEN — prerequisite | Compare actual DAO/query/migration/workspace routing changes and Guest/Restore effects in PoC-0 before choosing. |
| Run A — Qaza event/conflict policy | OPEN — prerequisite | Proposed append-only completion/reversal event model and revision-checked RPC require mapping to real domain/test behavior. |
| POC-0 — local toolchain/dependency resolution/checkers/topology | NOT RUN | First executable gate. Local self-hosted Supabase + PowerSync is documented; no hosted service/paid plan is needed. |
| POC-1 — PowerSync encryption/reopen/wrong-key | NOT RUN | Test sqlite3mc first, SQLCipher fallback if needed; pin SDK/changelog. |
| POC-2 — Drift/data layer/schema and architecture checks | NOT RUN | Include offline_architecture_check.py and phase_boundary_check.py; use check-only formatting. |
| POC-3 — Qaza events/reversal/idempotency/RPC/queue count | NOT RUN | Determine reliable pending queue count; never report unknown as zero. |
| POC-4 — local Docker sync/offline replay | NOT RUN | Use disposable local volumes/keys/users only. |
| POC-5 — RLS, publication allowlist, Sync Streams, two-user queue isolation | NOT RUN | Blocking security gate. |
| POC-6 — adoption, Guest, Restore, Cancel, expiry/revoke, permanent errors | NOT RUN | Must test explicit state transitions. |
| POC-7 — key loss, backup/restore, wipe crash recovery and account deletion | NOT RUN | Must not replace unreadable data with empty DB silently. |
| POC-8 — Android release and test/checker suite | NOT RUN | CI evidence must point to the exact PoC commit and use formatting check-only. |
| Run A — ADR | PROPOSED, awaiting PoC evidence | ADR-001 documents the candidate and quantified no-go gates; not approved for implementation. |
| Human approval before implementation | REQUIRED | Stop after Run A. Do not implement backend until PoC evidence and approved ADR are complete. |

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
- **Run C implementation:** only after Run A evidence is complete and the user explicitly approves the ADR.
- These criteria are planning requirements. They do not mean the ADR is decided or any app/backend implementation is complete.

## Run A: OPEN — blocked on PoC (updated 2026-10-25)

1. **COMPLETE — repository/code inventory:** inspected the encrypted database opener and key store, Drift schema/DAO shape, workspace manager and registry, account session and Google identity boundary, root/host manifests, architecture scripts and current CI evidence.
2. **COMPLETE — official-documentation review:** checked PowerSync Flutter/encryption docs, PowerSync + Supabase setup, Sync Streams lifecycle, Drift-on-sqlite_async package docs, Supabase Auth/RLS docs, and current package/pricing pages. Sources and version snapshot are in ADR-001.
3. **COMPLETE — alternatives and cost comparison:** custom sync is documented as fallback; Supabase Realtime alone is not sufficient as a durable offline sync protocol.
4. **COMPLETE — proposed ADR draft:** options, workspace alternatives, Qaza conflict-policy candidate, session/deletion/key-loss, backup/recovery, sensitive-data and queue-count requirements plus go/no-go thresholds are recorded in [ADR-001](adr-001-supabase-powersync-candidate.md). It is not approved for production.
5. **NOT RUN — compatibility PoC:** PowerSync officially documents a self-hosted local Supabase + PowerSync Docker workflow, so hosted credentials are not a prerequisite. Runtime execution still requires verifying actual local/runner tooling; first execute POC-0, then POC-1 through POC-8 in the experiment ledger. No test is marked passed until results/logs exist.
6. **REQUIRED — owner review:** no Run B and no backend implementation before the PoC evidence is attached, the ADR is updated to Accepted/Rejected, and the owner explicitly approves.

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


## 9. Run A official-docs assessment and candidate recommendation (2026-10-25)

### What the research establishes

- The latest package listing observed is PowerSync Flutter SDK 2.5.0 (Dart minimum 3.10), sqlite_async 0.14.6, drift_sqlite_async 0.3.1 and supabase_flutter 2.18.3. These are dated observations, not lockfile entries or proof they work together. The root pubspec advertises a Dart lower bound of 3.5; adding PowerSync 2.5.x may require raising that lower-bound contract even though current CI used a newer Dart SDK.
- PowerSync's current native encryption API explicitly documents both SQLite3MultipleCiphers (the current root build hook is sqlite3mc) and SQLCipher. This is positive package-level evidence. The precise encryption option, key format, native dependency graph, Android release artifact and Drift connection lifecycle have not been exercised in this app.
- PowerSync's Flutter reference documents a client-side schema managed from backend schema/Sync Streams, and separately handled raw/local-only tables. The app currently uses a custom Drift schema v26, numerous DAOs/custom queries, migrations, and control/workspace database routing. This implies a data-layer/schema migration decision, not just adding a dependency.
- PowerSync's Supabase guide uses a replication role that can bypass RLS and explains that data in a Postgres publication is read by the service regardless of whether every table appears in a Sync Stream. Therefore the design requires least-privilege table grants/publication allowlisting and strict owner-filtered Sync Streams in addition to client-facing RLS; cross-user stream isolation must be tested directly.
- The PowerSync SDK queues client-side writes, calls the app-supplied upload handler and retries when that handler errors. It does not define Qaza-specific conflict semantics. Stable IDs, idempotency, owner validation, revision/conflict rules, deletion tombstones and account-deletion handling remain application responsibilities.
- Supabase RLS docs call for explicit operation/role policies, owner checks, appropriate indexes and automated tests. The intended test path is pgTAP / supabase test db.
- Pricing snapshot in the proposed ADR: Supabase Free $0 with 500 MB database/50,000 MAU and pausing after inactivity; Supabase Pro from $25/month. PowerSync Cloud Free has 2 GB sync/month, 500 MB hosted data/50 peak concurrent clients and inactivity deactivation; Pro starts at $49/month. Both-plan Pro baseline is approximately $74/month before applicable overages/other costs. Recheck price, compute and region before provisioning. No paid plan or project was provisioned.

### Recommendation status

PowerSync + Supabase is the first option to test in an isolated PoC because it removes the need to build the core change queue and replication loop from scratch. It is not selected for production until a proof of concept demonstrates encryption, Drift/data-layer integration, offline replay, two-account ownership isolation, guest adoption/cancel, account switching, conflict/deletion semantics and Android release builds. If those gates fail, prepare a custom-sync design and estimate its durable outbox, retry, cursor, tombstone, monitoring and conflict-policy burden before deciding.

### Official source links

- PowerSync Flutter SDK: https://docs.powersync.com/client-sdks/reference/flutter
- PowerSync encryption options: https://pub.dev/documentation/powersync/latest/powersync/EncryptionOptions-class.html
- PowerSync + Supabase: https://docs.powersync.com/integrations/supabase/guide
- Sync Streams / legacy Sync Rules status: https://docs.powersync.com/sync/rules/overview
- Drift integration: https://pub.dev/packages/drift_sqlite_async
- sqlite_async: https://pub.dev/packages/sqlite_async
- Supabase Auth: https://supabase.com/docs/guides/auth
- Supabase RLS: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase pricing: https://supabase.com/pricing
- PowerSync pricing: https://powersync.com/pricing


- 2026-10-25: Added ADR-001 as a proposed PowerSync-first candidate; review gaps are being resolved. Local self-hosted PoC is available in principle without a hosted project. No encryption/Drift/cross-account runtime test is marked complete until run evidence exists; backend implementation remains blocked pending evidence and owner approval.


## Review follow-up — Claude review issues (2026-10-25)

The second review has been incorporated into ADR-001 and the experiment ledger. The ADR is the single source of architecture research; this tracker points to it rather than repeating the research narrative.

Key additions:
- Workspace topology W1 versus W2 is now a prerequisite decision. Guest-after-sign-out and Guest data when choosing Restore are specified for both.
- Append-only Qaza completion/reversal events with client UUIDs are a conflict-policy candidate; mutable settings require revision conflict handling. This remains to be mapped and verified against existing domain semantics.
- Expired/revoked auth, provider identity linking, server-side account deletion, permanent upload failures, key loss, Android backup/restore, religious-data sensitivity and pending-queue count are explicit PoC/design items.
- PoC Step 0 covers a clean isolated dependency resolution, SDK/host tooling, architecture checkers and topology inventory.
- Official PowerSync guidance describes self-hosted Supabase + PowerSync via Docker for local integration testing, so the local PoC does not inherently require a hosted service or payment. The exact environment readiness remains NOT RUN until command output is recorded.
- All runtime POC rows remain NOT RUN. No app runtime/backend implementation was made.
