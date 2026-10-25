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

## 3. Requirements the architecture must satisfy

1. **Offline-first:** read and mutate Qaza data locally with no network; durable local writes must survive process death and app restart.
2. **Multi-device:** authenticated users can safely use the same cloud account on more than one device.
3. **Guest path:** local-only Guest use is supported. No cloud account is required to use the offline app.
4. **One active cloud identity per installation:** the first version does not need simultaneous multi-account editing. Local datasets and queued changes must nevertheless remain isolated by owner.
5. **Authoritative cloud owner:** use the immutable Supabase Auth user UUID as the cloud owner key. Email and provider display fields are not authorization identifiers.
6. **Explicit adoption:** Guest-to-cloud adoption is a deliberate user-confirmed transition. If the target cloud account already has data, show an explicit restore/adopt/reconcile choice; never silently merge or overwrite.
7. **No cross-account leakage:** sign-in completion alone must not bind a local workspace or start sync before reconciliation completes. A different account cannot inherit or upload the previous account's local queue.
8. **Safe sign-out:** retain the encrypted local workspace and pending changes, disconnect/pause sync, and resume only when the same account authenticates again. Do not silently reassign the queue to another account.
9. **Separate local wipe:** explicit device-data removal is separate from cloud-account deletion. A crash-safe wipe must remove the relevant key before deleting encrypted database files, sidecars, pending mutations, sync metadata, cached identity and session data; the durable recovery marker remains until cleanup is verified. Local wipe must not delete cloud data.
10. **Deletion safety:** server-side account/data deletion is explicit. An old offline queue must not recreate cloud data after account deletion or invalidation.
11. **Security and maintainability:** enforce ownership on the server, support deterministic/idempotent writes and conflict handling, keep secrets out of the client, and test failures and retries.

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

## 6. Security, account ownership and data semantics

### Authentication and owner identity

- Use Supabase Auth to establish a server-issued user identity. For Google sign-in, test linking the app's current Google credential flow to Supabase Auth (for example, supported ID-token sign-in). Do not map a Google subject or email directly to a cloud row owner.
- After successful Supabase authentication, the server-issued Auth user UUID is the immutable owner key. Use UUID ownership in cloud schemas and bind the local sync workspace to that UUID only after reconciliation succeeds.
- Never ship a Supabase secret/service-role key in the mobile app. A publishable key is not a substitute for server-side authorization.

### Supabase RLS is mandatory

Every client-exposed data table must enable RLS and have explicit policies for each relevant operation (select, insert, update, delete) granted to the authenticated role. Enforce owner equality through auth.uid() for existing and resulting rows, index policy predicate columns, and test both permitted and denied operations using pgTAP / supabase test db.

Official RLS guidance: https://supabase.com/docs/guides/database/postgres/row-level-security

**PowerSync-specific caution:** the official Supabase integration guide's example creates a replication role with BYPASSRLS and reads tables in the Postgres publication; Sync Streams then determine which rows are synchronized to each authenticated client. Therefore RLS cannot be treated as the only privacy boundary for sync distribution. Use least-privilege source-table grants and an explicit publication allowlist; configure each Sync Stream to filter strictly by the authenticated user UUID; test cross-user reads on two test accounts. Never begin with a broad FOR ALL TABLES publication for production data. The service must only replicate approved app tables, and Sync Streams must only publish rows whose owner matches the authenticated client.

References:
- Supabase + PowerSync: https://docs.powersync.com/integrations/supabase/guide
- Supabase RLS: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase Auth: https://supabase.com/docs/guides/auth

### Local database and encryption

- Treat local encryption and cloud/server encryption as different controls. A local encrypted SQLite file does not make the cloud end-to-end encrypted; Supabase and the sync service may process readable row values unless application-level encryption is deliberately designed.
- Preserve a device-secured key store; never place keys in SQLite, SharedPreferences, exported backups, logs or source control.
- Prefer a distinct random local database key per workspace/owner if the chosen local file layout supports it. Keep the key identifier and owner binding outside user-editable data; a file name alone is not authorization.
- Never point the PoC at the real app database or reuse its production/test key. Use disposable files and random test keys.
- PowerSync's local database should be created/opened and keyed using the SDK's documented encryption configuration, rather than adding an independent PRAGMA key call to a connection PowerSync manages. The PoC must establish the supported cipher mode and correct option values.

### Conflict, retry and deletion semantics

PowerSync supplies client-side queuing/retry mechanics but the application still implements the backend upload handler and Qaza-specific mutation semantics. Define and test:
- stable client-generated UUIDs for offline-created records and idempotent upserts;
- owner validation for every upload; reject/quarantine a queue whose owner differs from the current session, never rewrite owner to make an upload pass;
- server-side version/expected-revision or another deterministic conflict policy for concurrent edits to the same record;
- delete tombstones/epochs (or an equivalent explicit protocol) so delayed offline writes cannot resurrect a deleted record or recreate an account's cloud data;
- retry-safe batch acknowledgement only after server acceptance, plus explicit handling for permanent validation/authorization failures;
- catch-up after disconnect from a durable cursor/snapshot. Do not depend on an ephemeral realtime event alone for correctness.

The precise Qaza domain conflict policy (including completion, undo, profile-plan edits and concurrent device activity) is not decided by this ADR and must be specified/tested before data sync is enabled.

## 7. Account lifecycle and workspace matrix

| Local state | Account selected | Required result |
|---|---|---|
| Empty/unbound local workspace | Supabase user A | Bind only after successful reconciliation. |
| Data-bearing local Guest workspace | User A | Explicit Guest adoption only; do not auto-adopt. |
| Local workspace bound to user A | User A signs in again | Resume that user's isolated workspace and queue after verifying owner binding. |
| Workspace/queue for A is present | User B signs in | Keep A's data inaccessible and sync disconnected; B receives a separate workspace. Never reassign A's queue to B. |
| User A already has cloud data during adoption | User A | Show explicit restore, adoption/import, or cancel decision. No silent overwrite or merge. |
| Wipe-in-progress marker exists | Any identity | Complete/recover wipe before opening a workspace or exposing data. |
| Cloud account deleted | Any later sign-in | Old queued changes must not recreate the deleted cloud account's data; local remnants remain local-only until separately removed. |

Sign-in and data reconciliation are distinct phases. While reconciliation is pending, the newly authenticated account must not receive workspace access or start syncing. Cancel must sign out that pending account and leave the previous local workspace unchanged. Do not promise restoration of a previous provider session; requesting that account to sign in again is acceptable.

Signing out retains the encrypted local workspace/queue but disconnects sync. An explicit “remove data from this device” action first records a durable wipe marker outside the encrypted database and key, then removes the encryption key, database files and SQLite sidecars, queue/sync metadata, owner bindings, cached identity and local session. Startup must finish a marked wipe before opening affected state. Cloud-account deletion is separate and must not be triggered by local wipe.

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

## 9. Required proof of concept and go/no-go criteria

The current environment used for this audit did not provide a local repository checkout, runnable Flutter toolchain, Docker/Supabase CLI, Android emulator/device, or PowerSync service credentials. GitHub Actions has verified the existing app/tests but has **not** verified any PowerSync integration. Thus this proof of concept is still a blocker, not a completed experiment.

Build a disposable spike outside production app code and use test projects/accounts only. Pin the exact package versions in the spike lockfile. At minimum, evaluate the observed versions above and record any required minimum-Dart-SDK change.

### Required experiments

1. **Encrypted database:** create, close, reopen and query a disposable PowerSync database with SQLite3MultipleCiphers using the documented encryption options and a fresh random test key. Verify wrong-key failure and integrity. If SQLite3MultipleCiphers fails, repeat with the officially documented SQLCipher option before rejecting PowerSync. Verify the built APK includes the intended native implementation and does not silently open a plaintext database.
2. **Drift integration and data layer:** demonstrate the required Drift reads/writes, joins/custom queries, transactions/nested transactions, query-watch notifications and teardown/reopen on the same PowerSync-managed database. Test schema changes and local-only/raw tables. If the current database's DAO/migration design cannot run over PowerSync, quantify the required repository/data-layer refactor before deciding whether to retain Drift.
3. **Offline lifecycle:** write while offline, kill the process, reopen offline, then reconnect and confirm the mutation is uploaded exactly once logically and acknowledged only after server acceptance. Exercise retries, duplicate upload attempts and permanent authorization errors.
4. **Two-account isolation:** use two disposable Supabase Auth users. Prove Sync Streams never deliver user A's rows to B, that RLS denies spoofed owner IDs for each operation, and that an A-owned pending queue cannot upload under B. Include automated pgTAP tests and an explicit publication/Sync Stream allowlist.
5. **Cross-device conflict/deletion:** make concurrent changes on two clients; test the proposed revision/conflict rule, out-of-order changes, deletion tombstones, delayed offline upload and account deletion.
6. **Guest adoption and cancel:** exercise empty cloud, cloud with existing data, local Guest with data, explicit adoption, restore and cancel. Cancel must leave old local data unchanged and must not expose or sync it during reconciliation.
7. **Sign-out and wipe:** prove sign-out pauses sync while preserving local data/queue for the same owner; a different account cannot access it. Inject crashes between every wipe stage and prove the next startup recovers before database open. Wipe must never delete remote cloud data.
8. **Android and CI:** run unit/integration tests, Android debug and release builds, encrypted file reopen/integrity smoke tests, RLS tests and the full app test suite. Capture logs/results without secrets or personal data.

### Go/no-go acceptance gates

**GO only if all are true:**
- The documented cipher option works in Android debug and release, survives process restart and refuses an incorrect key.
- Drift integration is either demonstrably sound or a bounded/approved repository refactor is fully scoped.
- Offline changes survive restart, retry safely and converge across two devices.
- RLS and Sync Streams jointly prevent cross-user leakage; mismatched owners and obsolete queues cannot be rebound to another user.
- Guest adoption, existing-cloud-data choices, cancellation, sign-out, wipe and cloud deletion all have deterministic, tested state transitions.
- Costs, provider data residency/retention, package/toolchain constraints and ongoing service ownership are accepted by the owner.
- A written conflict policy and automated tests cover Qaza records/profile data.

**NO-GO for PowerSync** if encrypted native builds are unreliable, Drift integration requires an unacceptably invasive rewrite, the Sync Stream ownership boundary cannot be convincingly tested, or pricing/vendor/data-processing constraints are unacceptable. At NO-GO, estimate custom-sync complexity and produce a separate design before any backend implementation. Do not silently fall back to Supabase Realtime-only writes.

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
- sqlite_async: https://pub.dev/packages/sqlite_async
- drift_sqlite_async: https://pub.dev/packages/drift_sqlite_async
- Supabase Flutter: https://pub.dev/packages/supabase_flutter
- Supabase Auth: https://supabase.com/docs/guides/auth
- Supabase RLS and pgTAP guidance: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase pricing: https://supabase.com/pricing
- PowerSync pricing: https://powersync.com/pricing
