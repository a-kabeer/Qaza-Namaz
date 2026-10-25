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

**A local PoC is possible without hosted services or paid plans.** PowerSync's official guide recommends self-hosting Supabase + PowerSync locally via Docker for integration testing, and its public self-host-demo repository contains a Supabase example:
- https://docs.powersync.com/integrations/supabase/local-development
- https://github.com/powersync-ja/self-host-demo

**Execution status remains NOT RUN.** The docs establish a free route, not that the user's Windows toolchain is ready. Record the actual outputs before claiming a test passed.

### Step 0 — environment, dependency resolution, topology and package boundaries

1. On a throwaway branch, inventory Flutter/Dart/JDK/Android SDK/Docker/Compose/Supabase CLI versions and disk/RAM.
2. Build a disposable PoC project outside production source packages. Pin PowerSync, sqlite_async, drift_sqlite_async and encryption packages in the lockfile. Run clean dependency resolution against current root constraints; record conflicts and minimum Dart SDK. Do not change root pubspec.
3. Read `tools/offline_architecture_check.py` and `tools/phase_boundary_check.py`, record their invariants and run them from the test branch. Keep cloud-only imports out of root Phase 1 source until approved. Evaluate whether cloud integration belongs in `apps/qaza_app_cloud` or a separate package that honors these checks.
4. Compare W1 single-workspace/detach and W2 per-owner DB/key against actual DAO/query/transaction/migration counts, account routing, local metadata and queue isolation. Record concrete touched items and choose a topology before adoption/account-switch experiments.
5. Check Docker/Compose/Supabase CLI/Flutter availability. The PowerSync self-hosted demo is the starting reference. No hosted project, credentials or payment card is required for this local route.

### Step 1 — encrypted database and package/version gate

- Create, close, reopen and query a disposable PowerSync DB with SQLite3MultipleCiphers using documented EncryptionOptions and a random test key. Test wrong-key rejection and integrity.
- If SQLite3MultipleCiphers fails, try the documented SQLCipher mode. Encryption support shifted across PowerSync SDK releases; pin the version and inspect that version's changelog. Verify the APK actually includes the intended cipher and does not silently create/open plaintext.
- Test database-only restore, reinstall/device transfer, key loss and missing-key behavior. Never wipe ciphertext or silently start an empty database after key failure.

### Step 2 — Drift, raw/local tables and app boundaries

- Demonstrate Qaza-like reads/writes, joins/custom queries, transactions/nested transactions, watch notifications, close/reopen, schema migration and local-only/control rows on the same PowerSync DB through Drift.
- Quantify necessary DAO/query/migration changes. Initial NO-GO thresholds: more than 25 DAO/query implementations require rewriting, or the PoC cannot demonstrate a viable migration plan within a two-engineering-day timebox. These are review thresholds, not universal quality laws.
- Run both architecture checker scripts; do not weaken them to make the PoC pass. CI uses format-check only, never a format-and-push step for experiment evidence.

### Step 3 — Qaza event/conflict protocol and queue count

- Map real complete/undo/revision behavior. Test append-only completion/reversal events with stable UUIDs and derived counts; concurrent duplicates must not double-count.
- Test mutable profile/target changes with an expected-revision RPC/transaction, not plain PostgREST upsert alone.
- Verify supported PowerSync pending-change count/status API with in-flight, retrying and permanent-error items. If exact count is not trustworthy, removal UI must say “Unable to verify pending changes” and never show a false zero.
- Prove transient errors retry with backoff and permanent authorization/validation errors are surfaced without infinite retry.

### Step 4 — local Docker Supabase + PowerSync and offline replay

- Use the official self-host-demo Supabase setup as a reference. Keep DB volumes, JWT keys, accounts, rows and encryption keys disposable and local. No paid cloud project or personal data.
- Create a local write while offline, terminate app/process, reopen offline, reconnect and verify exactly one logical server mutation and correct acknowledgement only after acceptance.

### Step 5 — two-account security and lifecycle

- Create two disposable Auth users. Test RLS for all CRUD operations, spoofed owners, explicit publication allowlisting, per-user Sync Stream isolation and A-queue rejection under B.
- Test same email via different providers; no merge absent trusted explicit linking. Test deletion while a token remains valid, deleted/re-created UUID, delayed inserts and permanent upload failures.
- Test Guest adoption with empty cloud, existing cloud rows, Restore and Cancel; sign-out versus token expiry/revocation; pending queue on switching; Guest after sign-out; crash injection at each wipe stage; Android backup/restore with missing key.
- Include religious-practice data sensitivity and explicitly record the payload-encryption decision before real-user use.

### Step 6 — Android, tests and result ledger

- Run Android debug/release build, wrong-key/reopen smoke tests, app tests, pgTAP/RLS tests and architecture checks. Use check-only formatting in CI.
- Record each experiment independently and link the exact commit/run. Do not infer PoC success from existing app CI.

### Quantified NO-GO triggers

PowerSync is NO-GO if any occurs: encrypted Android release cannot reliably create/reopen and reject wrong keys; a two-user stream leakage test fails; a queue can be uploaded under a different owner; the queue count cannot support safe sign-out/removal semantics and no safe “unknown” UI is accepted; key loss/backup behavior silently loses or replaces data; more than 25 DAO/query implementations require rewrite; or no viable integration/migration plan can be demonstrated in two engineering days. If a trigger fires, record evidence and separately estimate a custom-sync implementation before approval.

### Experiment ledger

| ID | Experiment | Result | Evidence | Gate |
|---|---|---|---|---|
| POC-0 | Toolchain, clean dependency resolution, package boundaries, W1/W2 topology | NOT RUN | No run log yet | First prerequisite |
| POC-1 | Encrypted create/close/reopen, wrong key, SQLite3MultipleCiphers then SQLCipher if needed | NOT RUN | No run log yet | Blocking |
| POC-2 | Drift DAOs/transactions/watch/migrations and checker scripts | NOT RUN | No run log yet | Blocking |
| POC-3 | Append-only completion/reversal model, idempotency, revision RPC, queue count | NOT RUN | No run log yet | Blocking |
| POC-4 | Local Docker Supabase + PowerSync, offline replay and acknowledgement | NOT RUN | No run log yet | Blocking |
| POC-5 | Two-user RLS + publication/Sync Streams + owner-bound queue | NOT RUN | No run log yet | Blocking |
| POC-6 | Guest restore/adoption/cancel, expiry/revoke, switching and permanent errors | NOT RUN | No run log yet | Blocking |
| POC-7 | Key loss, Android backup/reinstall, crash-safe wipe and server deletion | NOT RUN | No run log yet | Blocking |
| POC-8 | Android release build, full tests and architecture checks with check-only formatting | NOT RUN | No run log yet | Final gate |

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
