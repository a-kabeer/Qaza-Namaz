# ADR-001 — Candidate Sync Architecture for Supabase Offline-First Qaza Namaz

**Status:** PROPOSED — not approved for implementation; final choice blocked on executable proof of concept and owner review  
**Date:** 2026-10-25 (Asia/Karachi)  
**Repository baseline:** main at 4e9747ed2005806ae81ede78ef2448af9b483aa7  
**Decision scope:** cloud identity, sync engine, local database integration, ownership, reconciliation, conflict handling and operational cost  
**Phase:** Run A only. Do not implement backend or change production app behavior until the owner explicitly approves the final ADR.

## 1. Executive recommendation

Evaluate **Supabase Auth + Postgres/RLS + PowerSync** first in an isolated, disposable proof of concept. PowerSync is the leading candidate because its Flutter SDK is explicitly designed to keep a local SQLite database in sync, retain client-side writes in an upload queue while offline, and stream changes from Postgres. Its current Dart SDK documents native SQLite encryption through SQLite3MultipleCiphers or SQLCipher. The app already configures SQLite3MultipleCiphers, so package-level support is promising.

This is a **candidate recommendation, not a production architecture decision**. The project has not run PowerSync against its exact encrypted SQLite/Drift setup, has not verified how the app's existing Drift schema and database manager would map to a PowerSync-managed database, and has not tested ownership isolation or offline replay across account changes. Do not add these packages to the production app or create a hosted project as a side effect of this ADR.

If the proof of concept passes the acceptance gates in Section 9, recommend PowerSync for the sync protocol and queue, with Supabase as the source of truth for identity and durable cloud records. If the proof of concept cannot meet the encryption, database integration, ownership or conflict requirements without an excessive rewrite or fragile fork, evaluate the custom-sync fallback in Section 4 before approving any implementation.

## 2. Context and facts established from the repository

The app is pre-release and not published. Test data is disposable; this reduces the need for legacy data compatibility but does not reduce the required correctness or security bar.

At the audited baseline:

- Supabase is not implemented. The optional apps/qaza_app_cloud target is currently a Google Sign-In/local-only host, and the root app is still offline-first.
- The root app uses Drift 2.35.x, sqlite3 3.5.x, drift_flutter 0.3.x and flutter_secure_storage 10.3.x. The pubspec currently configures the sqlite3mc build hook for SQLite3MultipleCiphers.
- The encrypted database opener creates/reads a random 32-byte key through flutter_secure_storage, issues PRAGMA key, checks cipher support and validates the database before normal Drift queries.
- The current schema version is 26. The current implementation includes a control database, workspace registry and per-workspace database resolution, plus account/session state. These are current implementation details, not requirements that must all survive a storage redesign.
- Google identity is currently used to select a local workspace; Google sign-in is not a cloud-storage service.
- The repository was verified after merge commit 4e9747ed2. The merged change fixed CI test timeouts and documented the migration baseline; it did not implement Supabase or alter production storage behavior.

## 3. Decisions required before the sync PoC

These design choices precede any hosted-backend or production implementation.

### 3.1 Local workspace topology — evaluate both options before deciding

The workspace topology is a prerequisite decision. The current code uses a control database, registry-based workspace resolution, and per-workspace databases. That topology should not be retained automatically just because it exists today.

- **W1 — one local encrypted workspace per installation:** when switching from account A to B, sync for A stops and the app must explicitly detach A's workspace as local-only or ask for an explicit local wipe before B can start. Any pending queue must be retained in a quarantined owner-bound state or explicitly discarded only after a clear warning showing the actual count. If the count cannot be determined, show “Unable to verify pending changes,” never “0.” This is the simpler topology but has a more destructive user experience.
- **W2 — separate encrypted DB file and key per owner:** A's encrypted data/queue can remain on the device while B uses a separate DB/key. This preserves more local data but retains registry, key/file lifecycle, account-routing and cleanup complexity.

The PoC Step 0 must inventory the real DB manager, registry, DAO/query/migration paths, local control state, queue isolation and architecture-checker constraints, then compare the actual implementation changes for W1 versus W2. Select a topology only after that evidence. Do not claim either is finalized yet.

Regardless of topology, signing out as A and choosing Guest must stop A's cloud sync and must not expose A's authenticated workspace as an unowned Guest workspace. If Guest has local data and selects “Restore” over an existing cloud account, preserve the Guest dataset unchanged as a local-only workspace if W2 is selected; if W1 is selected, require an explicit export or removal decision before restoring. Never silently discard Guest data.

### 3.2 Qaza conflict policy — prerequisite, not deferred

Candidate model: represent each Qaza completion and undo as an immutable event with a globally unique client-generated UUID, owner UUID, prayer type, original prayer date, operation type/event lineage, client-created timestamp and schema version. Counts and remaining balances should be derived projections, not the authoritative mutable counter replicated with last-write-wins. An undo should append a compensating/reversal event referencing the completion it reverses; it should not erase an event already synced to another device. Uniqueness constraints should prevent the same logical event being applied twice.

This is a candidate, not yet a final domain decision. Map the actual existing complete/undo/revision behavior to the event model. Test duplicate completion from two devices, reversals, historical rows, profile target changes and prayer-plan edits. Prefer append-only records for factual events and an explicit conflict policy for mutable settings. Do not sync mutable per-prayer counters as authoritative state unless a conflict-free merge strategy is proven.

### 3.3 Upload/write protocol

Plain PostgREST upsert by itself does not provide an expected-revision compare-and-swap protocol. For revision-checked mutable records, use a narrow Postgres RPC/transaction or carefully specified database function that checks owner, expected revision and idempotency key atomically. Return typed accepted/conflict/permanent-rejection outcomes. Append-only event inserts should use stable IDs and idempotency constraints. Do not acknowledge queue entries until server acceptance or an explicit permanent-rejection/quarantine result. Classify transient failures for retry with backoff; permanent authorization/validation/schema errors must not retry forever or disappear silently.

### 3.4 Cloud and local identity semantics

Use the Supabase Auth UUID as the only cloud owner key. Google provider subjects, email, casing and masked email are not authorization keys. If the same email appears from different providers, treat identities as distinct until a trusted explicit linking flow confirms they belong to the same Supabase Auth user. Do not merge on email alone.

An expired or revoked token is not the same as intentional sign-out: pause sync, keep the encrypted dataset/queue bound to the same UUID, require re-authentication as that same identity, and resume only after verification.

Account deletion is a separate operation initiated by a server-side administrative/Edge Function path, never by shipping a service-role key to the mobile app. Design foreign keys/cascade and deletion/tombstone behavior so inserts with a still-valid old JWT fail after the user is deleted; account recreation must receive a new UUID and must not inherit old queues/data. Classify permanent errors and allow explicit recovery.

### 3.5 Key loss and mobile backup

Key loss may make ciphertext unrecoverable. Never silently reset the key and create an empty DB as if the old data were recovered. Test Android auto-backup/device transfer restoring ciphertext without its keystore-backed key, data-only restore, reinstall and database restore. Either exclude database files from OS backup or define a deliberate secure key/backup recovery design. Local-only unsynced changes cannot be promised recoverable if both the database and key are lost.

### 3.6 Sensitive data and application-level encryption

Prayer-completion and missed-prayer history can reveal religious practice and must be treated as sensitive personal data. Minimize fields, restrict access to the owner, avoid storing history in logs/analytics, and define retention/deletion and service-region handling.

Application-level payload encryption is an explicit open decision. The proposed PoC default is **not to implement E2EE yet**; document this as a non-goal because server-side row filtering requires readable metadata and app-level encryption adds key-management complexity. The final ADR must explicitly accept or reject this non-goal before any real-user data is used. Local DB encryption and TLS do not mean the sync service cannot read cloud-synced fields.

### 3.7 Pending upload count

PoC must verify whether the pinned PowerSync SDK exposes a supported, reliable pending-queue count and its behavior for in-flight/retrying/permanently rejected mutations. Sign-out/removal UI must never display a fabricated zero. If an exact trustworthy count is unavailable, show “Unable to verify pending changes” and block any destructive operation whose safety depends on a known count.

## 4. Options considered

| Option | Strengths | Costs and risks | Assessment |
|---|---|---|---|
| **A. Supabase + PowerSync Cloud** | Purpose-built SQLite sync; local-first reads/writes; durable upload queue and retry; sync streams; reduced custom sync protocol code; documented Supabase integration. | Additional vendor and bill; another hosted copy/processing location; custom upload handling and business conflict policy still required; must integrate with current encryption and Drift architecture; vendor-specific client data model. | **Preferred candidate for isolated PoC.** Do not approve until gates pass. |
| **B. Supabase + custom sync** | Full control over wire protocol, database shape, conflict policy, retries and provider dependencies; can keep existing Drift data layer and migrations more directly. | We must design, implement and maintain a durable outbox, acknowledgement/idempotency, pull cursor, pagination, deletes/tombstones, retry/backoff, reconnect/reconciliation, cross-device conflict rules, schema changes, monitoring and crash recovery. High correctness burden. | Fallback if PowerSync fails a hard requirement or total cost/lock-in is unacceptable. |
| **C. Supabase Realtime alone** | Native event delivery for online clients; fewer sync dependencies. | Realtime notifications alone are not a durable offline write queue or a complete replay/catch-up, deletion, conflict and account-switch protocol. Offline clients need a separately designed durable queue and server reconciliation. | Not sufficient as the full sync solution. May be a hint/notification channel, not the source of sync correctness. |
| **D. Cloud-only CRUD / online-required app** | Simplest data path. | Violates the offline-first and local-usage requirements. | Rejected. |
| **E. Keep local-only for now** | No new backend risk or spend; matches current runtime behavior. | No multi-device sync yet. | Correct current state while investigation/approval is pending. |

## 5. Current official-documentation findings

Versions below are a snapshot of official package listings checked on 2026-10-25, not a promise to use those versions without a fresh compatibility check.

| Component | Observed stable package/version | Relevant finding | Project impact |
|---|---|---|---|
| PowerSync Flutter SDK | powersync 2.5.0; package listing says Dart >= 3.10 | Client-side SQLite sync, local CRUD and watch APIs, credential connector, durable local CRUD upload queue. uploadData() is application-supplied and is retried after errors. | Candidate meets the broad offline-sync shape, but the app still owns backend-write semantics and business conflict policy. The package's Dart minimum is higher than the root pubspec's declared lower bound (>=3.5); adopting it may require revising the minimum SDK contract. |
| PowerSync encryption | EncryptionOptions in current PowerSync API | Official API docs state native encryption requires SQLite3MultipleCiphers (sqlite3mc) or SQLCipher. The root project currently configures sqlite3mc. | This confirms documented package-level support, not successful integration with this app's database lifecycle, native build graph, existing key handling or Drift connection. |
| sqlite_async | 0.14.6 | Async SQLite API with asynchronous calls, write/read concurrency, update watching and transactional APIs. | A relevant low-level database dependency in the ecosystem; not evidence by itself that Drift and PowerSync operate correctly together here. |
| drift_sqlite_async | 0.3.1 | Uses Drift on a sqlite_async database; documents common queries, transactions/nested transactions, update propagation and optional Drift migrations. | A plausible bridge to test. Compatibility with the exact PowerSync-managed database and this app's Drift DAOs is not yet verified. |
| Supabase Flutter | 2.18.3 | Official Flutter client for Supabase Auth, database and related services. | Evaluate Google authentication through Supabase Auth; do not treat the existing Google provider subject or email as the Supabase owner UUID. |

Official sources:
- PowerSync Dart/Flutter SDK: https://pub.dev/packages/powersync
- PowerSync Flutter SDK reference: https://docs.powersync.com/client-sdks/reference/flutter
- PowerSync encryption options: https://pub.dev/documentation/powersync/latest/powersync/EncryptionOptions-class.html
- sqlite_async: https://pub.dev/packages/sqlite_async
- drift_sqlite_async: https://pub.dev/packages/drift_sqlite_async
- Supabase Flutter: https://pub.dev/packages/supabase_flutter
- Supabase + PowerSync integration: https://docs.powersync.com/integrations/supabase/guide

PowerSync's current Flutter reference documents a managed client-side schema derived from the backend schema/Sync Streams, ordinary table views, automatic handling for synced table schema, and separately managed raw tables. The current app instead has a hand-authored Drift schema at version 26 with DAOs, custom migrations and local recovery/control data. Therefore, this is not a dependency-only change: the PoC must prove whether the domain/repository layer can remain on Drift, which tables should be synchronized, which remain local-only, and how raw-table migrations work.

Use **Sync Streams** for a new configuration. PowerSync's docs identify legacy Sync Rules as deprecated in favor of Sync Streams: https://docs.powersync.com/sync/rules/overview

## 6. Security and cross-service trust boundaries

### Supabase Auth and RLS

Use Supabase Auth to establish the authenticated identity and bind every synchronized row to immutable auth.uid() UUID. Never use email/provider subject as an authorization identifier. Never ship a service-role or secret key inside the mobile app.

Every client-exposed table must enable RLS and define explicit policies for relevant operations. Test unauthorized reads/inserts/updates/deletes, spoofed owner IDs, and attempts to change an owner's ID. Include pgTAP tests and run supabase test db.

Official guidance: https://supabase.com/docs/guides/database/postgres/row-level-security

### PowerSync replication and Sync Streams

PowerSync's official Supabase guide describes a replication role with BYPASSRLS in its example; therefore RLS alone is not the security boundary for rows copied by PowerSync. Limit source-table grants and publications to explicitly approved tables. Use strict user-specific Sync Stream filters and test directly that one user cannot receive another user's rows. Do not synchronize sensitive tables until two-user isolation passes.

### Local encryption and key recovery

The existing key store uses flutter_secure_storage and a random 32-byte key; that does not prove OS backup/device-transfer compatibility. Test cold open, wrong key, reinstall, Android backup/device transfer, database-only restore and key loss. Exclude the encrypted database from OS backup unless a deliberate recoverable key design is provided. If key loss occurs, do not overwrite the old ciphertext or silently initialize an empty ledger; tell the user that unsynced data may be unrecoverable.

### Sensitive personal data

Prayer completion and missed-prayer history can reveal religious practice and should be treated as sensitive personal data. Collect only necessary fields, restrict access, minimize logs/analytics, and define retention/deletion. Application-level payload encryption is an explicit open decision; local SQLite encryption and TLS do not mean cloud-synced values are unreadable to the service. Decide before any real-user data is used.

### Upload failures and acknowledgement

Use stable event IDs, idempotent writes, owner validation and a durable queue. Retry transient network/service failures with backoff. Classify authorization, schema, constraint and invalid-payload failures as permanent until explicitly resolved; do not retry them forever or discard them silently. Acknowledge mutations only after server acceptance or documented permanent-rejection/quarantine handling.

## 7. Account lifecycle and workspace topology

The topology must be selected after the PoC inventories current dependencies; see Section 3.1. Both W1 and W2 must satisfy:

| State | Required result |
|---|---|
| User A signs out intentionally | Stop A's sync; retain A's encrypted data/queue bound to A's Supabase UUID. |
| User A token expires/revokes | Pause sync; retain data/queue; require re-authentication as the same owner. |
| User switches from A to B | Never bind A's local DB or queue to B. W2 uses B's separate DB/key; W1 requires quarantining/detaching A or explicitly wiping it before B starts. |
| User signs out A and selects Guest | Guest is local-only and isolated; it must not expose A's authenticated data or queue. |
| Data-bearing Guest adopts A | Explicit confirmation and reconciliation; owner binding only after successful resolution, no sync while pending. |
| Guest chooses Restore while local data exists | Preserve Guest data as separate local-only workspace in W2; under W1 require explicit export/removal before restore. |
| A already has cloud data | Offer explicit restore, import/reconcile, or cancel; never silently merge or overwrite. |
| Cancel during reconciliation | Sign out newly authenticated identity, preserve prior workspace, expose/sync nothing while pending. |
| Wipe marker exists | Recover wipe before opening DB or exposing account data. |
| A deleted; same email later signs up | New Auth UUID is a new identity; old queue/data are never attached on email match. |

A local wipe is a separate irreversible action: persist a marker outside the DB and key; delete the key first, then DB and SQLite sidecars, queue/sync metadata, owner binding, cached identity and local session; verify cleanup before clearing the marker. Startup retries interrupted wipes idempotently. Local wipe never deletes cloud data. Cloud deletion is a separate server-side operation.

## 8. Cost, vendor and privacy assessment

Pricing observed from official pages on 2026-10-25; recheck before provisioning or launch.

| Service | Development tier observed | Production baseline observed | Important limits/notes |
|---|---|---|---|
| Supabase | Free: $0; current page lists 500 MB database, 50,000 MAU, 5 GB egress; free projects pause after 1 week of inactivity. | Pro starts at $25/month; compute/project usage and overages can change the actual bill. | Free is appropriate for a disposable proof of concept, not a production availability promise. |
| PowerSync Cloud | Free: $0; 2 GB synced/month, 500 MB hosted data, 50 peak concurrent clients; free projects deactivated after 1 week of inactivity. | Pro starts at $49/month, including higher synced/hosted-data and concurrency allowances. | Introduces a second service, bill, operational dependency and data-processing location. |
| Supabase + PowerSync Cloud | $0 nominal for a development spike, subject to plan caps and inactivity pauses. | From approximately $74/month for the listed Supabase Pro and PowerSync Pro base plans, before any applicable extra compute, usage overages, extra projects or other services. | Price is not the only cost: the sync service holds/serves replicated data and introduces vendor and region review. |
| Supabase + custom sync | Supabase Free for a disposable spike. | Supabase Pro base from $25/month plus any applicable compute/usage. | Lower direct vendor line items, but materially higher engineering, testing, monitoring and incident-response cost for the custom sync system. |

Official pricing:
- Supabase: https://supabase.com/pricing
- PowerSync: https://powersync.com/pricing

Review the region and data-processing implications for both Supabase Postgres and PowerSync's synced-data service before creating production resources. PowerSync Cloud stores and streams a copy of approved synced rows, so this is not simply “Supabase only.” If policy requires that no third party beyond Supabase holds synced data, evaluate self-hosting PowerSync or the custom-sync fallback explicitly. No paid service or cloud project is authorized by this ADR.

## 9. Zero-budget proof of concept and go/no-go criteria

**A local PoC is possible without hosted services or paid plans.** PowerSync documents a self-hosted Supabase + PowerSync Docker route for local integration testing:
- https://docs.powersync.com/integrations/supabase/local-development
- https://github.com/powersync-ja/self-host-demo

**All experiments are currently NOT RUN.** Documentation is not execution evidence. Use synthetic data, local disposable volumes and fresh test keys only. Do not create a hosted project, subscription, payment method, production credential or production data set for Run A.

### Step 0 — environment, isolated package, and CI fallback

1. Record `flutter --version`, `dart --version`, `java -version`, `flutter doctor -v`, `docker version`, `docker compose version`, and `supabase --version`, along with available RAM/disk.
2. Keep the PoC as an independently versioned, disposable package with its own `pubspec.yaml` and lockfile, outside the production app's package tree. Do not add its dependencies/imports to the root app manifest or source. Preserve the exact PoC commit SHA.
3. If a required local tool or compatible version check is missing/fails, do not guess or mark the experiment failed solely due to local setup: use a CI runner with Docker available, record the workflow run URL and exact PoC SHA, and capture the version/setup failure as part of the evidence.
4. For CI fallback, use a dedicated/read-only workflow or another run path with `contents: read`, check-only formatting, and no auto-format commit/push. Do not trigger write-capable workflows that format and push changes on the throwaway branch.
5. Run `tools/offline_architecture_check.py` and `tools/phase_boundary_check.py` **unchanged against the clean production-repository checkout** as a separate boundary check. Do not weaken, patch, or special-case either checker to accommodate the PoC package. Record separately which production package/phase boundary a future approved integration would cross; do not treat a checker result as proof that the PoC itself passed.
6. Check current package versions, minimum SDK requirements, license files and service terms before pinning dependencies. Record the selected versions and clean resolution result.

### Experiment checkpoint — workspace topology (W1 vs W2)

After Step 0 and POC-2, the owner/reviewer must choose W1 (one encrypted workspace with explicit detach/wipe before rebinding) or W2 (a separate encrypted DB/key per owner) **before the account lifecycle and ownership experiments**. Record the actual DAO/query/migration counts, affected files, Guest-after-sign-out behavior, Restore behavior for an account that already has cloud data, and pending-queue isolation for both designs. POC-1 must exercise the minimum encryption/open/close/wrong-key behavior for both W1 and W2 shapes so the choice is not based on an untested assumption. If evidence does not distinguish them, keep the decision OPEN.

### Step 1 / POC-1 — encrypted database and key-format gate

- Create, close, reopen and query a disposable PowerSync database with the documented encryption option(s). Start with SQLite3MultipleCiphers where supported; test SQLCipher as the documented alternative if required. Pin exact SDK and cipher versions and inspect version-specific changes.
- Match the app's existing key format: 32 random bytes encoded as Base64URL. Document whether each API expects raw bytes, a Base64URL string, or another representation; decode/encode explicitly and test round-trip handling. Never accidentally use the UTF-8 bytes of the Base64URL text as though those were the original 32-byte key.
- Verify correct-key reopen and integrity; opening with a missing/wrong key must fail closed. Inspect the file signature/header and assert the encrypted database does not begin with the plaintext SQLite header `SQLite format 3\\0`. A missing/wrong-key failure alone is not enough to prove the file is encrypted.
- Verify the application does not silently create/open a plaintext database after an encryption/key error. Repeat these minimum checks with both W1 and W2 file/key layouts.

### Step 2 / POC-2 — Drift and production boundary checks

- In the isolated package, demonstrate Qaza-like reads/writes, joins/custom queries, transactions/nested transactions, update watchers, close/reopen, schema migration, and local-only/control-table behavior on the same PowerSync-managed database through Drift.
- Count affected DAO/query/migration implementations and describe the migration path. Initial NO-GO thresholds: more than 25 DAO/query implementations require rewriting, or there is no viable integration/migration plan within the two-engineering-day overall timebox. These are explicit project review thresholds, not universal quality laws.
- Run both architecture checker scripts unchanged on the clean root checkout. Keep the result separate from isolated package tests, and document the real integration boundary without weakening the scripts.

### Step 3 / POC-3 — Qaza event/conflict protocol and queue count

- Map actual complete/undo/revision behavior. Test append-only completion/reversal events with stable UUIDs and derived counts; repeated uploads and concurrent duplicates must not double-count.
- Test mutable profile/target changes with an expected-revision RPC/transaction, not plain PostgREST upsert alone.
- Verify documented PowerSync pending-change count/status behavior for in-flight, retrying and permanently failed items. If an exact count is not reliable, the UI/flow must say “Unable to verify pending changes” and must never display a false zero.
- Prove transient errors retry with backoff and permanent authorization/validation errors are classified and surfaced rather than retried forever.

### Step 4 / POC-4 — local Docker sync, restart and replay

- Use the official self-host demo as a reference. Keep services, volumes, JWT keys, test users, rows and encryption keys disposable and local.
- Write while offline, terminate/restart the process while still offline, reconnect, and verify one logical server mutation, idempotent replay, and acknowledgement only after accepted upload. Record the expected and observed state at every transition.

### Step 5 / POC-5 — two-user server isolation

- Use two disposable **email/password** Supabase Auth users for local two-user tests. No Google OAuth client or external credential is required for this experiment.
- Test RLS for all CRUD operations, spoofed owner IDs, explicit publication allowlisting, per-user Sync Stream isolation, and rejection of user A's queued mutation while user B is active. Test deleted/re-created Auth UUIDs and delayed stale inserts.
- A successful client-side owner check is not sufficient: prove server-side denial, including when using the replication role/Sync Stream configuration.

### Step 6a / POC-6a — Guest adoption, Restore, and Cancel

- Test adoption into an empty cloud account; an account with existing cloud data; Restore; Cancel; and Guest behavior after sign-out.
- During reconciliation, do not bind/expose/sync local data until the choice is resolved. Cancel signs out the newly authenticated account and preserves the prior local workspace; no data may be exposed or uploaded during the pending decision.
- Compare the observed behavior to the previously selected W1/W2 topology.

### Step 6b / POC-6b — session expiry, revocation, and permanent failure

- Test expired and revoked sessions, same-owner re-auth, a different owner attempting to resume, transient network failures, permanent authorization/validation failures and retry classification.
- Expiry/revocation pauses sync while retaining the owner-bound local data/queue. A different account must not claim or upload those queued changes.

### Step 7a / POC-7a — key loss, backup, reinstall and transfer

- Test database-only backup/restore, Android backup/restore, reinstall/device transfer, deleted/missing/mismatched keystore key, and inability to decrypt old ciphertext.
- Never overwrite unreadable ciphertext or silently initialize an empty ledger. Define deliberate backup exclusion or a documented recoverable-key design before production approval.

### Step 7b / POC-7b — wipe and cloud-account deletion

- Inject crashes at each local wipe stage. Recovery must be idempotent and complete before workspace selection or database access. Delete the relevant key and all scoped DB/sidecar, queue, sync metadata, ownership and cached identity state; retain a durable marker until cleanup is verified.
- Test cloud deletion with a still-valid token, delayed queued writes and stale local state. Old queued work must not resurrect a deleted cloud account/data set. Clearly distinguish local wipe from cloud deletion.

### Step 8 / POC-8 — Android and regression verification

- Run Android debug/release builds, encryption smoke tests, relevant package tests, app regression tests, server/RLS tests and unchanged root architecture checks.
- Use check-only formatting. Do not rely on a workflow that automatically reformats and pushes during experiment verification.

### Separate identity experiment / POC-GOOGLE — Google sign-in through Supabase Auth

**Status: NOT RUN; external OAuth setup required.** The local email/password users in POC-5 do not prove Google-to-Supabase authentication. Once the owner explicitly authorizes a throwaway test Google OAuth client and its redirect configuration, test Google ID-token sign-in with Supabase Auth, stable Supabase Auth UUID across repeated sign-ins, provider linking versus same-email-but-unlinked behavior, and sign-out/re-auth. Do not put client secrets or tokens in source control or use personal/production OAuth credentials. Until this separate experiment is run (or the owner explicitly records a justified deferral), Google identity integration remains unverified.

### Pass/fail rules, overall timebox, and Run A exit

- Each experiment must have a written expected result before execution, a result of **PASS**, **FAIL**, or **BLOCKED**, the exact command(s), PoC commit SHA, CI run URL if used, and a brief evidence summary. **NOT RUN** is not a pass and must never be inferred from a related test or app CI run.
- POC-1 passes only if correct-key reopen/integrity work, wrong/missing-key open fails closed, the file has no plaintext SQLite header, Base64URL key handling is verified, and both W1/W2 minimum layouts are covered.
- POC-2 passes only if the declared Drift operations/migrations work in the isolated package, clean resolution is reproducible, and the two root checkers pass unchanged against the clean production checkout. Any checker failure is recorded as a boundary finding, not fixed by weakening the checker.
- POC-3 through POC-7b pass only when their described state-transition, integrity, replay, ownership/security, error-classification and deletion assertions are supported by captured output/tests. Any cross-user read/write, false-zero queue count, silent data reset, or deleted-account resurrection is a blocking FAIL.
- POC-8 passes only when required Android builds, relevant tests and unchanged root checks complete successfully on the recorded SHA.
- POC-GOOGLE passes only when Google ID-token sign-in, stable UUID, identity-linking semantics and repeat sign-in are demonstrated with the throwaway OAuth setup. If OAuth cannot be provisioned, it remains BLOCKED/NOT RUN, not passed.
- Timebox the Run A execution to **two engineering days total** after Step 0 is runnable. Any experiment needing more time must record what remains, evidence so far and the reason; further work requires an explicit owner decision to extend the timebox. Missing prerequisites do not count as passing tests.
- **Run A closes only when every experiment ledger row has a supported result/evidence (including the separate Google identity experiment, or an explicit owner-approved written deferral), the ADR is revised to Accepted or Rejected based on evidence, and the owner explicitly decides whether to authorize Run B.** Do not implement backend or production behavior while this gate is open.

### Quantified NO-GO triggers

PowerSync is NO-GO if encrypted Android release cannot reliably create/reopen and reject wrong keys; a two-user stream-leakage test fails; a queue can upload under a different owner; queue count cannot support safe sign-out/removal and no acceptable unknown-state UX exists; key-loss/backup silently loses or replaces data; more than 25 DAO/query implementations require rewrite; or no viable integration/migration plan is demonstrated within the two-engineering-day timebox. A material licensing/terms incompatibility is also a NO-GO for the proposed deployment. Record evidence and separately estimate custom sync before approval.

### Experiment ledger

| ID | Experiment | Result | Command / PoC SHA / CI run / evidence | Gate |
|---|---|---|---|---|
| POC-0 | Toolchain, package/license/version checks and CI fallback decision | NOT RUN | Not yet recorded | First prerequisite |
| POC-1 | Encryption, W1/W2 layouts, wrong key, plaintext-header and 32-byte Base64URL key handling | NOT RUN | Not yet recorded | Blocking |
| POC-2 | Isolated Drift/SQL/migration behavior and unchanged root architecture checks | NOT RUN | Not yet recorded | Blocking; then W1/W2 checkpoint |
| POC-3 | Qaza events, reversal/idempotency, expected-revision RPC and queue status/count | NOT RUN | Not yet recorded | Blocking |
| POC-4 | Local Docker sync, offline writes, process restart, replay and acknowledgement | NOT RUN | Not yet recorded | Blocking |
| POC-5 | Email/password test users, RLS, publication/Sync Streams and owner-bound queue | NOT RUN | Not yet recorded | Blocking security gate |
| POC-6a | Guest adoption, existing cloud data, Restore, Cancel and Guest-after-sign-out | NOT RUN | Not yet recorded | Blocking |
| POC-6b | Expiry/revocation, same-owner re-auth, different owner and permanent-error classification | NOT RUN | Not yet recorded | Blocking |
| POC-7a | Key loss, Android backup/restore, reinstall/transfer and missing-key behavior | NOT RUN | Not yet recorded | Blocking |
| POC-7b | Crash-safe local wipe, cloud account deletion and stale queued-write rejection | NOT RUN | Not yet recorded | Blocking |
| POC-8 | Android builds, relevant tests and check-only formatting/root checkers | NOT RUN | Not yet recorded | Final technical gate |
| POC-GOOGLE | Google ID-token sign-in through Supabase Auth, UUID stability and provider linking | NOT RUN | Requires approved throwaway test OAuth client | Identity integration gate |

## 10. Decision and approval state

**Current decision: proposed candidate only.** Documentation research is complete enough to justify a focused proof of concept, but the required runtime integration and two-user security tests have not run. No sync engine is selected for production.

Next:
1. Review this proposed ADR.
2. Run the isolated proof of concept and attach reproducible evidence to the tracker.
3. Reassess the recommendation and revise this ADR to Accepted or Rejected with evidence.
4. Obtain explicit owner approval.
5. Only then create a separate Run B implementation plan. Backend implementation must remain out of scope until approval.

## 11. References

- PowerSync Flutter SDK and schema/queue behavior: https://docs.powersync.com/client-sdks/reference/flutter
- PowerSync encryption options: https://pub.dev/documentation/powersync/latest/powersync/EncryptionOptions-class.html
- PowerSync + Supabase architecture, replication and Sync Streams: https://docs.powersync.com/integrations/supabase/guide
- PowerSync Sync Streams vs deprecated Sync Rules: https://docs.powersync.com/sync/rules/overview
- PowerSync package/version constraints: https://pub.dev/packages/powersync/versions
- PowerSync licensing and terms by edition (Open Edition FSL service vs Apache-2.0 client SDK): https://powersync.com/legal/licensing-terms
- PowerSync open-source/source-availability summary: https://powersync.com/open-source
- Supabase self-hosting responsibilities and Docker route: https://supabase.com/docs/guides/self-hosting
- sqlite_async: https://pub.dev/packages/sqlite_async
- drift_sqlite_async: https://pub.dev/packages/drift_sqlite_async
- Supabase Flutter: https://pub.dev/packages/supabase_flutter
- Supabase Auth: https://supabase.com/docs/guides/auth
- Supabase RLS and pgTAP guidance: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase pricing: https://supabase.com/pricing
- PowerSync pricing: https://powersync.com/pricing


## 12. Review addendum — explicit blockers and clarifications (2026-10-25)
- **Execution rigor update (2026-10-25):** the PoC is a separately versioned package outside the production app tree with its own manifest/lockfile; root architecture checks run unchanged against the clean production checkout, and the intended future phase boundary is documented separately. CI fallback must be read-only/check-only and avoid auto-format/push workflows.
- **Experiment split and exit criteria:** encryption now explicitly checks the existing 32-byte Base64URL key representation and absence of the plaintext SQLite header for both W1/W2 layouts; lifecycle work is split into POC-6a/6b and POC-7a/7b; local two-user tests use email/password. Google-to-Supabase sign-in is a separate POC-GOOGLE item, NOT RUN until a throwaway OAuth client is approved. Run A has a two-engineering-day timebox and closes only after evidence/results for every row (or an owner-approved written OAuth deferral), an Accepted/Rejected ADR, and explicit owner decision.
- **Licensing gate:** inspect the exact package/transitive licenses and PowerSync edition terms before deployment. Official summaries distinguish Apache-2.0 client SDKs from the Functional Source License for the self-hosted PowerSync Open Edition service; do not equate “free local PoC” with an unconditional right to every deployment/usage model.


- **Workspace model remains a gate.** Before sync experiments beyond dependency resolution, POC-0 compares one encrypted workspace plus explicit detach/wipe with separate encrypted DB/key per owner. It must specify Guest after sign-out and Guest data handling when the user chooses Restore. No silent owner change, data loss or queue rebind.
- **Qaza conflict model is a prerequisite.** Append-only completion/reversal events with stable UUIDs and derived counts are the leading candidate; real DAO/domain behavior and undo/revision semantics still need mapping. Use a transaction/RPC for expected-revision writes rather than assuming ordinary REST upsert is compare-and-swap.
- **Auth/deletion:** expired or revoked auth pauses sync but retains owner-bound local data and queue for same-owner re-auth. Same email from different provider identities is not sufficient to merge accounts. Cloud account deletion runs server-side; deleted or re-created auth identities must not accept old queued writes.
- **Key loss / Android backup:** test database-only restore, keystore key mismatch and reinstall/device transfer. Never overwrite unreadable ciphertext or silently create a new empty ledger. Define OS-backup exclusion or a deliberate recoverable key strategy.
- **Sensitive data:** prayer completion history can reveal religious practice. Data minimization, retention, logging, access and service region need explicit treatment. Application-layer payload encryption/E2EE is an open decision and is not implemented by this PoC.
- **Pending queue count:** verify a supported PowerSync queue-count/status API for in-flight, retrying and permanent errors. Unknown must be displayed as unknown, not zero; destructive behavior must be safe even when an exact count is unavailable.
- **Boundaries:** run `tools/offline_architecture_check.py` and `tools/phase_boundary_check.py` unchanged against a clean production-repository checkout, as separate boundary checks. The PoC package itself is independently versioned and outside the production app package tree; document which Phase 1 → Phase 2 boundary a future integration would cross. Do not weaken the scripts or assume their success proves PoC compatibility.
- **Free local path:** PowerSync documents a Docker self-hosted Supabase + PowerSync development flow, so a paid hosted project is not required in principle. Actual command/tool availability and test results remain NOT RUN.
- **Research source of truth:** this ADR is the single source for sync architecture research/package snapshot/cost trade-offs. The tracker should link here rather than duplicate the research. Prices and package versions are dated snapshots and must be rechecked before provisioning.
