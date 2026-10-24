# TP-GEN — Separate Google DB: Discrepancy Register and Inventory

**Produced:** Recovery Plan Stage 3 (2026-10-22), branch
`tp-gen/separate-google-db` @ `ef5f646c` (Stage 2 head; Stage 3 changed no
production code — see §6 of the Stage 3 report).
**Authorities:** design plan v2.2 (S1–S7, §4–§7 protocols, §8 matrix);
implementation task plan (Phases 0–5, T0.1–T5.5). Per the recovery plan's
precedence rule, v2.2 wins over every other document. Companion document:
`tp-gen-google-db-separation-design.md` (reconciled routing design).
**Verdict key:** `conforms` / `conforms-in-effect` (mechanism differs,
outcome matches) / `gap` (required behaviour absent) / `conflict`
(implementation contradicts the design) / `blocker` (architecture-affecting;
Stage 4 cannot begin until Abdul decides).
**Decisions recorded (2026-10-23):** Abdul approved the Part E decisions
D-A…D-D on 2026-10-23 (see E.2). The Stage 4 gate condition — Stage 4
cannot begin while D-A, D-C, or D-D are unresolved — is now **satisfied**:
Stage 4 may begin, implementing the decided remediations and the §8
requirement-to-test matrix.

---

# Part A — Discrepancy register

## A.1 Blockers handed over from Stage 2

### R-01 — Directory/handle routing bypasses the injected provider (Stage 2 blocker 1) — **BLOCKER**

**Design.** S5: a single manager owns opening/routing; database classes
take an *explicit target* — "no default-file construction remains in
production code". Task plan T0.4: consumers receive handles by "explicit
parameter/provider — no globals". Task-plan Phase 1 gate: with every
workspace still `shared`, the manager's introduction must be a
user-visible no-op and all pre-existing journeys pass unchanged. §5.2(7):
a shared-layout workspace "remains fully operational on the shared
layout". §8(12): pre-existing suites pass unweakened.

**Code behaviour — the five bypass paths** (all verified at `ef5f646c`):

1. `DatabaseManager`'s default directory provider silently binds the real
   platform channel: `documentsDirectoryProvider ??
   getApplicationDocumentsDirectory`
   (`lib/data/local/database/database_manager.dart:22–23`). Every call
   site that needs a directory goes through the injected provider
   (`database_manager.dart:179, 255, 483`;
   `database_manager_migration.dart:348, 564`) — but almost no production
   or test construction ever injects one.
2. `AccountLocalStore` fabricates a manager when none is injected:
   `databaseManager ?? DatabaseManager(controlDatabase: database)`
   (`lib/data/local/account_local_store.dart:19`). The fabricated manager
   has the caller's control database but the **real** default directory
   provider and the **real** default Google-file factory. Every
   pre-existing unit/adapter test constructs the store this way.
3. Activation routes through file machinery: `AccountLocalStore.activate`
   calls `ensureGoogleWorkspace` for every `google_` ID
   (account_local_store.dart:126), as does `ensureInitialized` for the
   active workspace (:35). For an existing shared workspace this reaches
   `_ensureGoogleWorkspace`'s creation path
   (database_manager.dart:255, directory call) or the migration helper
   (database_manager_migration.dart:348, directory call) — real filesystem
   effects for what the design's Phase 1 defines as a control-database
   no-op.
4. Publish/resolve gates reject the control handle:
   `setActiveWorkspace` (database_manager.dart:57–68) throws
   `Cannot publish a Google workspace before its database is validated.`
   for any non-Guest ID lacking a validated separate-file handle **in
   this manager instance** — including shared-layout workspaces (whose
   authoritative database is the control file) and legacy colon-form IDs
   (`google:<id>`) that the store layer otherwise accepts. Direct cause
   of 2 app failures (stacks: `database_manager.dart:63` ←
   `account_local_store.dart:158`). `databaseForActiveWorkspace`
   (:116–131) has the same shape.
5. `_openDatabaseForWorkspace` throws for `db_layout = 'shared'`
   (database_manager.dart:158–163: "legacy shared development layout…
   explicit development conversion or reset") instead of resolving
   through the registry to the control handle. No "development conversion
   or reset" exists anywhere in v2.2; §5.2's policy is the opposite
   (migrate at startup; shared stays operational). This blocks every
   registry-routed read of a shared workspace: full export
   (`local_backup_service.dart:61, 86`), scoped restore/Keep Both
   (:1056, :1871), the adapter bridge
   (`phase1_backup_bridge.dart:66, 154, 163, 172`), and the adapter
   provider (`google_cloud_providers.dart:470`).
   Also in this family: `providers.dart:83–95`
   (`loadInitialHomePrayerSelection`) fabricates a throwaway
   `DatabaseManager()` to read control `meta_store`, and
   `DatabaseManager.controlDatabase` (database_manager.dart:69) lazily
   opens the real control file via `AppDatabase.control()` —
   `app_database.dart:52` is the one direct
   `getApplicationDocumentsDirectory()` call outside the manager.

**Failure census (Stage 2, unchanged at Stage 3):** 12 app tests fail
with "Binding has not yet been initialized" (stack top:
`database_manager.dart:255` / migration `:348`), 2 app tests fail with
the publish `StateError` (path 4), 27 adapter tests fail with
`MissingPluginException` on the path_provider channel (adapter tests
reach paths 2+3 via `AccountLocalStore(database: …)` —
e.g. `cloud_workmanager_test.dart` setUp calls
`store.ensureAccountActive('google_google-account-A')`).

**Disposition.** Root cause is fully identified; the design's mandated
*outcome* is clear (explicit injection; shared resolves via the registry;
activation of an existing shared workspace is a control operation). The
production *fix shape* is **not** unambiguous — at least three shapes
exist, with different production consequences:

- **Shape A — registry-true resolution:** `shared` resolves to the
  control handle in `_openDatabaseForWorkspace`; publish/active-handle
  gates accept registry-resolved shared workspaces; `ensureGoogleWorkspace`
  stops provisioning/migrating on activation (provisioning stays with the
  verified sign-in creation flow; migration becomes the §5.2 startup run —
  depends on R-04's decision). Largest behavioural correction; matches
  the design most literally.
- **Shape B — injection completion:** remove the provider/factory
  defaults and thread the app manager (or an explicit directory) through
  every construction, including `AccountLocalStore`'s fallback. Breaks
  the `AccountLocalStore(database:)` / `LocalBackupService(database)`
  construction contract used by dozens of pre-existing tests → requires
  test call-site edits, which Stage 3/4 rules prohibit without a listed,
  approved reason (§8(12) allows listed changes, but that decision is
  Abdul's).
- **Shape C — scoped defaults:** keep defaults only in the two
  composition roots (foreground provider graph, worker) and make the
  store/service fallback manager inherit the caller-supplied database's
  directory context — not currently knowable from an `AppDatabase`
  handle; would need a new seam.

**Status: BLOCKER — decision required from Abdul (see Part E, D-A).**
No production fix was attempted in Stage 3.
**Decision (2026-10-23, approved by Abdul — D-A): Shape A,
registry-true resolution.** Implementing Shape A is Stage 4
production work; the 41 failing tests must pass unweakened under it.
**Tests required:** the 41 failing tests must pass unweakened; §8 items
2, 9, 11, 12.

### R-02 — Two adoption-journey widget tests hang (Stage 2 blocker 2) — **BLOCKER** (depends on R-01)

**Tests.** `test/features/account/account_chained_journeys_test.dart` —
"scenario 5 Case B: found backup reconciles the existing local Google
workspace via Keep Local…" and
`test/features/onboarding/cloud_setup_choice_screen_test.dart` — "new
Google sign-in adopts the chosen saved Guest, backs it up, and marks the
adoption verified". Both pass at `efadadd`; both hang indefinitely at
every branch commit (Stage 2: isolated repro killed at 300 s; Stage 3:
re-confirmed non-completion at `ef5f646c`, logs in
`~/workspace/qaza_recovery/stage3_logs/`).

**Root cause (Stage 2's hypothesis — CONFIRMED, mechanism refined).**
Same family as R-01, different symptom per test zone:

- Both journeys drive Google sign-in / activation / adoption flows whose
  Google workspaces hold data in the **shared** layout (seeded into the
  tests' in-memory database). The flows reach
  `AccountLocalStore.activate` → `ensureGoogleWorkspace` → migration
  helper (R-01 path 3), which awaits the **default** directory provider
  (platform channel) and the **default** Google-file factory (a real
  encrypted file via `NativeDatabase.createInBackground`,
  app_database.dart:47–80, :1543–1559).
- Both tests are `testWidgets` (fake-async zone). Platform-channel and
  background-isolate file futures cannot settle under fake async, so
  `pumpAndSettle` never returns. In real-async zones the identical reach
  produces the R-01 errors instead (binding error with no binding;
  `MissingPluginException` with a binding) — one cause, three symptoms.
- Contributing seam break: the tests override only
  `appDatabaseProvider` (the pre-split seam; chained journeys :364,
  cloud setup :657). On the branch, `accountLocalStoreProvider` and the
  session graph derive from `databaseManagerProvider`
  (providers.dart:189–194, :206–215, :289–297), which no test overrides —
  so provider-driven legs of the journeys construct a **real**
  `DatabaseManager()` whose control database is the real on-disk file.
  **Direct Stage 3 evidence:** during the cloud-setup adoption test, a
  drift warning stack printed from inside the test shows the real
  construction happening: `new AppDatabase.control`
  (app_database.dart:31) ← `DatabaseManager.controlDatabase`
  (database_manager.dart:69) ← `accountLocalStoreProvider`
  (providers.dart:195) ← `accountSessionManagerProvider`
  (providers.dart:209) — i.e. the session graph opened the real control
  file despite the test's `appDatabaseProvider` override
  (`stage3_logs/hang_cloud_setup.log`). The chained-journeys repro at
  `ef5f646c` stalled inside scenario 5 Case B for the full 240 s timeout
  (`stage3_logs/hang_chained_journeys.log`).

**Disposition.** No separate fix exists: any R-01 shape that keeps
activation of a shared workspace control-local (Shape A) removes the
filesystem reach from these journeys; Shapes B/C must be evaluated
against these files explicitly. **Status: BLOCKER, disposition tied to
D-A.** Stage 4 must demonstrate both files running to completion.
**Decision (2026-10-23, approved by Abdul — D-A): Shape A** (see R-01).
Shape A keeps activation of a shared workspace control-local, which is
the disposition this item depends on; Stage 4 must demonstrate both
journey files running to completion under it.
**Tests required:** §8 items 4, 5, 10, 12.

### R-03 — Auto-migrate vs block on `ensureGoogleWorkspace` (Stage 2 blocker 3) — **disposition final (D-B approved 2026-10-23)**

**The disagreement** (Stage 2 report §8, verbatim): test
`legacy shared Google data is preserved and not silently replaced`
(`test/data/local/database/database_manager_test.dart`, expectation at
:181) expects `ensureGoogleWorkspace` on a shared-layout workspace with
data to throw `StateError` and leave everything untouched. The code
auto-migrates (`_ensureGoogleWorkspace` → `_migrateLegacyGoogleWorkspace`,
database_manager.dart:240–242) and emits the `GoogleWorkspaceDatabase`.

**Design text (quoted).** §5.2: "**Migration runs at startup, before any
workspace is exposed (StartupGate pattern), for every Google workspace
still resident in the control database**", with the per-workspace
sequence ending at step 7: "On failure at any step: manifest `failed`
with the error, staging quarantined, **the workspace remains fully
operational on the shared layout**, and the failure is reported."
§5.3 assigns migration rules to every lifecycle state. §6: "Registry
says separate, file is missing or invalid: **block access** to that
workspace…" — the design's *block* applies to a **separate** workspace
whose file is bad, never to a shared workspace awaiting migration.
Nothing in v2.2 or the task plan directs `ensureGoogleWorkspace` (or any
open path) to refuse a shared workspace.

**Disposition.** The design mandates **migration, not a block**: on the
migrate-vs-block question the code's direction conforms and the test's
`StateError` expectation **conflicts with design §5.2**. (The code's
migration *mechanics* separately conflict with §5.1/§5.4 — R-04; the two
findings are independent.) Per Stage 3's scope, **neither the test
expectation nor the behaviour was changed**. Recorded Stage 4 action:
rewrite this test's expectation to the §5.2 behaviour (verified
migration with hash parity, source preserved per R-04's resolution) —
an existing-test change that §8(12) requires be listed with its reason,
and that needs **Abdul's awareness/approval before Stage 4 applies it**
(Part E, D-B). The test's title intent ("preserved and not silently
replaced") remains the property to prove — by parity evidence, not by a
refusal.
**Decision (2026-10-23, approved by Abdul — D-B): APPROVED.** The Stage 4
rewrite of this test's expectation to the §5.2 behaviour is authorized;
it is executed and listed (per §8(12)) in Stage 4, not in Stage 3. This
disposition is final.
**Tests required:** §8 items 3, 4, 5 (migration parts).

## A.2 Migration mechanics vs §5 (blocker cluster)

### R-04 — §5.1/§5.2/§5.3/§5.4 mechanics not implemented as designed — **BLOCKER**

Design §5.1 (quoted): "**Safety copy — once, not per workspace.** Before
the *first* workspace is touched, create **one** consistent, encrypted,
integrity-checked safety copy of the control database and verify it
opens… **The safety copy is never refreshed or overwritten during the
migration run**"; "**Storage pre-check.** Before starting, confirm free
space is adequate… If the check fails, migration does not start and no
file is modified." §5.4 (quoted): cleanup deletes "the superseded Google
rows from the control database (only for workspaces whose manifest is
`committed` and whose separate file has been re-verified…)" **after**
device validation, as a follow-up commit in the same task; "Until
cleanup lands, superseded rows are retained and are never read (the
registry decides)" and rollback before cleanup is "reinstall the
transition build and, if a workspace's data is in doubt, restore the
safety copy".

Code behaviour (database_manager_migration.dart, verified by full read):

1. **No safety copy exists.** No code creates one (the only `VACUUM INTO`
   in the repo is the pre-existing plaintext migrator,
   database_encryption.dart:113). No storage pre-check exists either.
2. **Source rows are deleted at commit.**
   `_commitLegacyGoogleWorkspaceMigration` (:269–343) deletes the
   workspace's rows from all eight owned tables, its
   `workspace_sync_metadata` row, its scoped `meta_store` keys, and its
   recovery snapshot **inside the migration commit transaction** — the
   exact retention §5.4 reserves for the post-validation cleanup. The
   §5.4 rollback story is thereby destroyed: after one successful lazy
   migration there is nothing retained to fall back to.
3. **Trigger is lazy, not the §5.2 startup run.** Migration runs only
   when `ensureGoogleWorkspace` is called for that workspace
   (activation / active-workspace init). Non-active shared workspaces
   are never migrated until activated — and per R-01(iv) they cannot
   even be *read* meanwhile. §5.2's "every Google workspace still
   resident" startup run does not exist; `DatabaseManager.initialize()`
   reconciles only journal leftovers.
4. **§5.3 mid-operation rule unimplemented.** §5.3: "`adopting`,
   `restoring`: migration **waits** until the in-flight operation's
   journal reaches a terminal state." The lazy path checks none of:
   lifecycle state, outstanding journal operations for the workspace,
   or active adoption/restore.
5. **Manifest fields partial.** §5.1 allows journal rows (chosen, see
   design doc §8), but the manifest fields are only partially carried:
   one `content_hash` (verified equal for source and target at commit —
   the parity itself is implemented, :519–546, :296–307) instead of
   distinct `source_hash`/`target_hash`; no `copying`/`verifying`
   states (journal phases `prepared`/`finalizing` are used instead).

**What does conform in the migration path:** finalization intent before
publish (§6), publish-without-overwrite, reopen + owner/integrity/hash
re-verification, one-transaction registry + journal commit, staging
quarantine on failure, startup reconciliation of `finalizing` rows
(database_manager_migration.dart:558–637), and §6's
final-without-commit finish-or-quarantine rule.

**Status: BLOCKER** — remediating (safety copy + pre-check + retained
rows + startup trigger + §5.3 waits) is architecture-affecting
production work whose shape interacts with R-01's decision (Shape A
assumes it) and with Recovery Plan Stage 6's default-retain cleanup
boundary (Part D). **Decision required from Abdul (Part E, D-C).**
**Tests required:** §8 items 3, 4, 5, 10, 11 — none can be built
truthfully until this is resolved.
**Decision (2026-10-23, approved by Abdul — D-C): implement §5.1–§5.4
AS DESIGNED in Stage 4** — safety copy, storage pre-check, retained
superseded rows until the Recovery-v1.2-Stage-6-gated cleanup, §5.2
startup-run trigger, §5.3 mid-operation waits. **v2.2 §5 is NOT
amended.**

## A.3 Conflicts and gaps (non-blocker, Stage 4 scope unless noted)

### R-05 — Cross-file adoption omits `finalizing` and the staging publish (§4) — conflict (mechanism)

§4 mandates phases `prepared → snapshotted → copied → verified →
finalizing → committed`, with finalization intent recorded **before**
publishing a staging file (steps 3, 5, 6). `_adoptGuestWorkspaceAcrossFiles`
(local_backup_service.dart:956–1331) writes **directly into the
already-provisioned target file** and uses no `finalizing` phase and no
staging file (verified: no occurrence of `finalizing` or staging in the
service). Its commit *does* satisfy §4 step 7 (one control transaction:
registry + journal + Guest `adopted_recovery` marking, :1268–1330).
Consequence: a crash mid-copy leaves partially copied rows in the live
target file; exposure is prevented only because activation is gated on
the commit, and retry with existing target data blocks ("The Google
target contains data but no matching committed adoption import
exists"). §8 item 4 requires retry seeded at **every** §4 phase
including `finalizing` — untestable as designed until this is resolved.
**Status: conflict; Stage 4 adoption work needs the resolution (Part E,
D-D, may be decided with D-C).**
**Decision (2026-10-23, approved by Abdul — D-D(i)): AS DESIGNED** —
cross-file adoption gains the §4 `finalizing` + staging-publish
sequence in Stage 4. **v2.2 §4 is NOT amended** for already-provisioned
targets.

### R-06 — Shared-target adoption keeps the single-database path (§4 case (c)) — conforms-in-effect, noted

For a `shared` target the branch runs the pre-existing v4.1 atomic
adoption (local_backup_service.dart:536–955), whatever the manager
state. §4 case (c) explicitly allows an empty shared-layout target and
defers its layout to §5, so the outcome conforms; the journal phases
are D3's, not §4's. Recorded so the §8 matrix does not claim §4-phase
coverage for shared targets.

### R-07 — `deletedHold` expiry for separate Google workspaces (§5.3) — gap

§5.3: expiry purge for a separate-layout workspace "deletes its
database file and its registry row". No code deletes a Google workspace
file on hold expiry: deletion holds are a Guest-only flow in the branch
(`scheduleGuestWorkspaceDeletion`, account_local_store.dart:394;
purge :525–602 is Guest-scoped), and no Google hold flow exists at all.
**Status: gap. Tests required:** §8 item 12 / Stage 4 register row.

### R-08 — Unrecognized-file quarantine (§6) — gap (partial)

§6: "Unrecognized file: quarantine it; never expose it." Creation and
migration paths refuse to overwrite unregistered files and quarantine
interrupted *staging* files, but no startup scan enumerates
`qaza_google_*.sqlite` files against the registry. **Status: gap.**
Tests required: §8 item 5/6 (Stage 4 items 2, 5).

### R-09 — Canonical hash rules (§7) — conflict (partial)

§5.2 step 2: "Compute the canonical source hash (**scoped-export hash,
§7**)". §7: "Reuse the existing scoped-export canonicalisation and
hashing wherever possible… Define exactly which records and metadata are
included… how… revision counters… are handled." The branch defines two
new canonical forms (`workspace-content-v1` for migration,
`workspace-canonical-v1` for creation — design doc §7) and reuses
neither the scoped-export canonicalisation nor a single shared
definition. Within `workspace-content-v1`: the `meta_store` revision
counter is excluded (§7 option 2, first half) but the sync row's
`local_revision` **is** hashed — an unexplained asymmetry; the "verify
them separately against the expected post-copy values" half of §7
option 2 is not implemented (the metadata write-after-copy overwrites
the counter with the source value instead, which is a third mechanism —
recorded, not judged). Identity mapping for adoption: cross-file
adoption verifies per-table parity inside its own flow; whether its
comparison is the §7 mapping-invariant form is a Stage 4 evidence task.
**Status: conflict (partial). Tests required:** §8 items 3, 7.
**Decision (2026-10-23, approved by Abdul — D-D(ii)): AS DESIGNED** —
the canonical hash is unified on §7's scoped-export canonicalisation
in Stage 4. The branch's `workspace-content-v1` is **NOT** adopted into
the design record as the definition.

### R-10 — Startup reconciliation covers only create/migrate journals (§6) — gap (partial)

§6: "At startup, reconcile incomplete operations **before** exposing
affected workspaces or allowing background sync". `initialize()`
reconciles `google_workspace_create` + `google_workspace_migration`
rows only (database_manager.dart:474–483). Incomplete cross-file
**adoption** rows are reconciled lazily when adoption is retried
(local_backup_service.dart:986–1018), and restore operations are not
journalled for reconciliation at all. **Status: gap (partial).**

### R-11 — Worker preflight ordering (S6 / T0.5) — conforms

Verified step-by-step against T0.5 (design doc §5 of the companion
document): control first, active-only rule before any Google file is
opened, registry + durable-operation checks before opening, pin /
generation / upload-block checks retained. The worker's bare
`DatabaseManager()` (cloud_workmanager.dart:59) is S5's sanctioned
own-process manager instance. **No action.**

### R-12 — Construction-policy coverage and the cloud host app — gap

The construction check (tools/offline_architecture_check.py, final
block) matches only no-argument `AppDatabase()` /
`GoogleWorkspaceDatabase()` in `lib` and the adapter's `lib`.
`AppDatabase.control()` (a default-file construction) is unmatched, and
`apps/qaza_app_cloud/lib/main.dart:113` still constructs `AppDatabase()`
directly, outside the scanned roots and outside the manager — a fifth
production construction site the design §2 baseline did not enumerate.
**Status: gap. Action:** extend the check (named constructors; `apps/`
root) and route the host app through a manager — Stage 4/5 scope, not
a Stage 4-start blocker.

### R-13 — Schema 25 → 26 mechanism — conforms, evidence pending

`schemaVersion => 26` (app_database.dart:87); the registry columns are
added by idempotent ensure-style ALTERs
(`_ensureRegistryDatabaseRoutingSchema`, :1021–1052), invoked from
`onCreate` (control role) and from `onUpgrade` under `from < 26`
(:205–207), in this codebase's ensure-based evolution style; existing
rows default to `shared` / `not_started` with `db_file_name` NULL,
matching Recovery Stage 4 item 8's expectation. The decision record
update (companion change) records the bump with evidence status
**pending**: the realistic-data upgrade test is a Stage 4 (§8 item 8)
deliverable and does not exist yet. **No §8 item 8 claim is made.**

### R-14 — Full export/import aggregation (§7 / T2.5) — conforms (dependent on R-01/R-04)

`exportJson()` with no workspace argument merges the control export
with every `db_layout = 'separate'` workspace's scoped export
(local_backup_service.dart:44–182), failing explicitly when a separate
workspace cannot be opened (the manager throws); shared workspaces come
from the control export; no superseded duplicates can appear because
R-04(2)'s commit-time deletion leaves none — i.e., this conformance
currently *depends on* the §5.4 conflict in R-04 and must be re-verified
against retained superseded rows if R-04 is remediated.
Scoped restore into a separate workspace is implemented
(`_importSeparateGoogleWorkspace`, :1535–1862; Keep Both at :1398–1519
creates the recovery copy as a registered workspace — whether as its
own file in all paths is a Stage 4 §8 item 12 evidence task).
§7 case (b) (fresh-install restore) is realised as: sign-in provisions
the file, then scoped import fills it — there is no restore-driven
file creation. **Status: conforms with dependencies noted.**

### R-15 — Scoped recovery-snapshot selection — gap (minor)

`_readScopedRecoverySnapshot` (database_manager_migration.dart:
44–85) selects the **latest** row of `local_recovery_snapshots`
unscoped, then validates it belongs to the workspace; if the latest
snapshot belongs to another workspace it returns `null` even when an
older snapshot for this workspace exists. During migration such a
snapshot would be silently left behind (it is also not deleted — it
stays in control — so this is a completeness gap, not data loss).
**Status: gap (minor). Tests required:** §8 item 11 (adapter/restore
compatibility) evidence.

### R-16 — Account-switch connection handling (S5 steps 1–7) — conforms-in-effect, variance noted

Generation advancement, provider invalidation, and
open-and-validate-before-publish are implemented (session layer +
manager gates). S5 step 4 ("close the outgoing workspace connection
safely") is realised as connection *retention* under the manager's
one-handle-per-file reuse (S5's own manager definition includes
"connection reuse"); handles close at manager teardown
(database_manager.dart:640–661). Recorded as a variance, not a defect.

### R-17 — Drift class shape (Stage 3 conformance check) — conforms-in-effect

Design S1 + task plan T0.3 ask for two database classes sharing table
definitions. Implemented: one `@DriftDatabase` class with a role enum +
`GoogleWorkspaceDatabase extends AppDatabase`, one generated part set.
**Conformance route taken (per Stage 3 instruction):** verification by
compilation + existing tests, no disposable spike — `flutter analyze`
= 0 errors at `ca26a9f9`/`ef5f646c` (Stages 1–2), Drift codegen
consistency check produced an empty diff at all three Stage 2
references, and the manager test file exercises both roles (control
file + `GoogleWorkspaceDatabase.forTesting`) at +6 −1 (the −1 is R-03).
The implemented shape **can** be verified; no spike was run and no
spike artifacts exist. **Status: conforms-in-effect; variance recorded
in the design doc §1.**

---

# Part B — Contract confirmations (Recovery Stage 3 item 5)

| Contract | Verdict | Evidence |
|---|---|---|
| Filename / identity (S3) | **Confirmed** | `googleFileNameForWorkspaceId` (database_manager.dart:82–91): SHA-256 of the stable ID, first 32 hex, `qaza_google_<h>.sqlite`; open-time regex + registry equality check (:166–178). No raw ID/email/name in paths. Collision/unregistered file → throw, never overwrite (:259–266). |
| Encryption key (S2) | **Confirmed** | Single opener `AppDatabase._openEncryptedDatabase` (app_database.dart:47–80) using `DatabaseEncryptionKeyStore` / `qaza_namaz_database_key_v1` for both roles; Google files encrypted from first write (`migrateLegacyPlaintext: false`, :1543–1552); control plaintext-migrator behaviour unchanged. |
| Owner marker (S1) | **Confirmed** | `workspace_file_owner` meta key (app_database.dart:901–925) + guard triggers (:926–995) rejecting cross-owner writes; verified at open (manager :182–184), creation (:385–399, :405–427), migration (helper :466–475, :519–546), adoption (service :1056–1062). |
| Registry schema (S4) | **Confirmed** | Extension of `local_accounts` chosen (S4 permits either); columns + defaults at app_database.dart:855–865 / :1021–1052; invalid layout values throw rather than being read as shared (:1040–1051). |
| Journal / manifest fields & states (§5.1, §4) | **Partial** | Journal-row manifest (design §8 of companion doc); `staging_file`/`final_file`/`content_hash`/`snapshot_id`/`backup_verified_at` present; §5.1 state names and distinct source/target hashes absent → R-04(5). Adoption omits `finalizing` → R-05. |
| Lock / reconciliation rules (§6, S6) | **Partial** | In-process single-flight maps (manager :31–35); startup reconciliation for create/migrate journals (§6 cases for those flows implemented); no cross-process lock; adoption/restore not reconciled at startup → R-10. Worker-side durable-operation check confirmed (R-11). |
| Canonical content-hash rules (§7) | **Partial** | Deterministic (PK-ordered rows, sorted keys, tagged forms) but two forms exist and neither is the scoped-export hash → R-09. |
| Revision-trigger ownership (S1, T0.3) | **Confirmed** | Google file: triggers only on its 8 owned tables + scoped meta prefixes, writing its own `meta_store`; `local_accounts` trigger control-only (app_database.dart:1184–1319). |
| Snapshot scoping (S1, §4) | **Confirmed with note** | `local_recovery_snapshots` exists per database; a Google file holds its own workspace's snapshot; adoption snapshots (`local_account_adoption_snapshots`) are control-only, created by the backup service (local_backup_service.dart:669, :976). Selection caveat → R-15. |
| Worker preflight ordering (S6, T0.5) | **Confirmed** | R-11. |

---

# Part C — Line-level inventory (Recovery Stage 3 item 3)

Line numbers are at `ef5f646c`. Classification key: **C** = control,
**W** = workspace, **B** = both/shared (role-branched or layout-routed),
**—** = n/a.

## C.1 `app_database.dart` (1559 lines) — schema ensures

| Function | Line | Class | Notes |
|---|---|---|---|
| `_openEncryptedDatabase` | 47 | B | Single opener; control default file `qaza_namaz.sqlite`; direct `getApplicationDocumentsDirectory()` call (R-01 path 5). |
| `migration.onCreate/onUpgrade` | 94 / 117 | B | Role-branched ensure chains; Google role excludes registry/journal ensures. |
| `_ensureMetaStoreSchema` | 213 | B | Creates `meta_store`; seeds `db_revision` (control semantics). |
| `_ensureDailySalahTrackingSchema` (+Link :269, Scope-migration :299) | 246 | B | Creates `daily_salah_logs`; migrates legacy global prefs to scoped keys. |
| `is/setDailySalahTrackingEnabled`, `…SetupDismissed` (+InTransaction) | 335–427 | W | Scoped by userId. |
| `_ensureCloudSetupChoiceSchema` + choice/prompt accessors | 429–497 | C | Control-only ensure (onCreate control branch). |
| `_ensureLocalRecoverySnapshotSchema` + save/read/has/clear | 498–555 | B | Table in both DBs; rows are per-workspace (S1). |
| `isOnboardingCompleted`, `readDbRevision`, `setDbRevisionInTransaction`, `incrementDbRevisionInTransaction`, `transactionWithRevision` | 556–850 | C/B | `db_revision` is the global control counter; `transactionWithRevision` is the shared mutation wrapper. |
| `readWorkspaceRevision` | 579 | W | Reads `workspace_revision:<id>` from the handle's own meta_store. |
| Initial-backup marker family (`_activeAccountForInitialBackup` … `clearPendingInitialCloudBackup`) | 599–741 | B | Scoped key `initial_cloud_backup_pending:<id>` + legacy unscoped pair (Part C.5). |
| `isFreshInstallationForCloudRestore` | 743 | C | Reads control registry/session. |
| `_ensureAccountSchema` | 852 | B | Control-only: `local_accounts`, `app_session_state`, `device_metadata`. Both: `account_profiles`, `account_plan_revisions`. |
| `readWorkspaceFileOwner` / `writeWorkspaceFileOwner` / `_ensureWorkspaceOwnerGuardSchema` | 901–995 | W | Marker + guard triggers (Google role only). |
| `_ensureWorkspaceOperationJournalColumns` | 996 | C | Adds `staging_file`/`final_file`/`content_hash` to the journal. |
| `_ensureRegistryDatabaseRoutingSchema` | 1021 | C | Schema-26 columns + validation (R-13). |
| `_ensureWorkspaceLifecycleSchema` | 1059 | B | Control-only: `workspace_operation_journal`, `local_workspace_deletion_holds`. Both: `workspace_sync_metadata`. |
| `readWorkspaceSyncState` / `writeWorkspaceSyncState` / `isWorkspaceCloudUploadBlocked` | 1103–1183 | W | Per-workspace sync row on the owning handle. |
| `_ensureWorkspaceRevisionSchema` | 1184 | B | Trigger set differs by role (Part B). |
| `_removeLegacyQazaHistorySchema` | 1321 | C | Legacy cleanup (upgrade path). |
| `_ensureQazaAdditionSchema` | 1373 | W | `qaza_additions`, `qaza_deletion_actions`, `qaza_deletion_action_record_snapshots`. |
| `_ensureQazaProfilePlanProvenanceSchema` | 1414 | W | `qaza_profile_plan_provenance`. |
| `_ensureDeletionActionVersionColumn`, `_ensureWorkspaceGenerationColumn` | 1425 / 1440 | W / C | Generation column is on `app_session_state` (control). |
| `readSessionGeneration`, `readActiveLocalAccountId`, `isCurrentWorkspaceGeneration` | 1460–1497 | C | Session state. |
| `_ensurePerformanceIndexes` | 1486 | B | Indexes on owned tables. |
| `GoogleWorkspaceDatabase` (+ `forTesting`) | 1543 | W | See R-17. |
| Generated: `app_database.g.dart`, `qaza_records_dao.g.dart` | — | B | Drift codegen; consistency verified Stage 2 (empty diff). |

## C.2 `database_manager.dart` (661) + `database_manager_migration.dart` (638)

| Member | Line | Class | Notes |
|---|---|---|---|
| Constructor (control?, directoryProvider?, factory?) | 15–42 | — | Defaults are R-01 path 1. |
| `setActiveWorkspace` | 57 | B | Publish gate — R-01 path 4. |
| `controlDatabase` | 69 | C | Lazy `AppDatabase.control()` — R-01 path 5. |
| `googleFileNameForWorkspaceId` | 82 | — | S3 (Part B). |
| `initialize` / `_initialize` | 103–108 | C | `readDbRevision` + journal reconciliation. |
| `_migrateLegacyGoogleWorkspace` / `_reconcileLegacyGoogleWorkspaceMigration` wrappers | 112 / 120 | W | Delegate to the Stage 1 helper. |
| `databaseForActiveWorkspace` | 116 | B | No-fallback rule (S5) ✓; gate shape is R-01 path 4. |
| `databaseForWorkspace` / `_openDatabaseForWorkspace` | 133–214 | B | Registry-routed open + owner/integrity validation ✓; `shared` throw is R-01 path 5. |
| `ensureGoogleWorkspace` / `_ensureGoogleWorkspace` | 219–461 | W | Provisioning (journalled create: staging → verify → `finalizing` → publish → re-verify → one-transaction registry+journal+scoped-row removal) + shared-data branch into migration. |
| `_hasSharedWorkspaceData` | 463 | W | Probes the 8 owned tables in control. |
| `_reconcileWorkspaceCreationJournal` | 474 | C | §6 cases for create/migrate rows (R-10 for the rest). |
| `_canonicalWorkspaceCreationHash` | 608 | W | `workspace-canonical-v1` (R-09). |
| `close` | 640 | B | Closes all handles. |
| Helper: `_readWorkspaceMetadata`, `_readScopedRecoverySnapshot` | 36 / 44 | W | R-15 (snapshot selection). |
| Helper: `_tableColumns`, `_tablePrimaryKeyColumns`, `_copyOwnedTableRows` | 108–188 | W | Row copy (Stage 2 Fix B site). |
| Helper: `_canonicalWorkspaceContentHash` | 190 | W | `workspace-content-v1` (R-09). |
| Helper: `_commitLegacyGoogleWorkspaceMigration` | 269 | W | **Deletes source rows at commit — R-04(2).** |
| Helper: `_migrateLegacyGoogleWorkspace` | 342 | W | Lazy migration — R-04(1,3,4). |
| Helper: `_reconcileLegacyGoogleWorkspaceMigration` | 558 | W | §6 finalizing-case reconciliation ✓. |

## C.3 `account_local_store.dart` (1314) — all methods run on the control handle except where noted

| Method | Line | Class | Notes |
|---|---|---|---|
| Constructor (fabricates manager) | 16–20 | — | R-01 path 2. |
| `_workspaceDatabase` | 25 | B | Routes via manager (R-01 path 5 exposure). |
| `ensureInitialized` | 28 | C | Device ID, local account, onboarding journals, then `ensureGoogleWorkspace` + `setActiveWorkspace` for an active Google workspace (R-01 path 3). |
| `hasAnyQaza`, `hasAnyAccountData` | 46 / 603 | W | Via `_workspaceDatabase`. |
| `deviceInstanceId` | 55 | C | `device_metadata`. |
| `getAccount`, `activeAccount`, `_mapAccount` | 73 / 99 / 1278 | C | Registry reads; `getAccount` exposes `db_layout` (:76). |
| `activate` | 111 | B | `ensureGoogleWorkspace` (:126) → session transaction → `setActiveWorkspace` (:158) — R-01 paths 3+4. |
| `ensureAccountActive`, `ensureLocalAccountActive` | 163 / 191 | B | Sign-in / startup activation entry points. |
| `createGuestWorkspace`, `findReusableEmptyGuestDraft`, `startFreshGuestWorkspace` | 213 / 258 / 282 | C | Guest registry rows (layout defaults `shared`). |
| `countWorkspaceRecords` | 293 | W | Owned-table counts. |
| `loadWorkspaceDisplayName`, `saveWorkspaceDisplayName` | 311 / 322 | B | Scoped meta key; for `separate` accounts the name is read from the control row join — see Part C.5 note. |
| `listGuestWorkspaces` | 367 | C | Guest-only listing. |
| `scheduleGuestWorkspaceDeletion`, `undoGuestWorkspaceDeletion`, `purgeExpiredGuestWorkspaceDeletions`, `listGuestWorkspaceDeletionHolds` | 394 / 458 / 525 / — | C | Guest deletion holds — R-07. |
| `loadProfile`, `saveProfile`, `saveProfileLocalOnly`, `clearProfile` | 625 / 642 / 697 / 1092 | W | `account_profiles` on the owning handle via `_workspaceDatabase` where routed; profile reads for Google accounts resolve through the manager. |
| `commitOnboarding`, `_writeOnboardingWorkspaceData`, `_reconcileOnboardingCommitJournals` | 765 / 912 / 1018 | B | Onboarding journal in control; workspace writes routed. |
| `loadPlanRevisions`, `savePlanRevision`, `_upsertProfilePlanProvenance` | 1122 / 1146 / 1181 | W | `account_plan_revisions` + provenance. |
| `_ensureLocalAccount` | 1211 | C | Legacy `guest` account bootstrap. |

## C.4 Stores, DAOs, repositories, migrator

| File | Surface | Class |
|---|---|---|
| `drift_qaza_local_store.dart` (765) | `DriftQazaLocalStore` — constructed with ONE handle (`database:`), all queries workspace-scoped by `userId`; provenance helpers (:631–765). | W (handle supplied by `qazaLocalStoreProvider` via `databaseForActiveWorkspace`, providers.dart:391–399) |
| `qaza_records_dao.dart` (1017) + `.g.dart` | `QazaRecordsDao` — the only Drift DAO; record CRUD/pages/activity on `qaza_records`. | W |
| `qaza_addition_repository.dart` (752) | `DriftQazaAdditionRepository(handle)` — additions/deletion actions on the active handle (providers.dart:439–447). | W |
| `account_scoped_user_profile_repository.dart` (51), `account_scoped_qaza_plan_revision_repository.dart` (21) | Thin adapters over `AccountLocalStore` with an `activeAccountId` callback. | B |
| `onboarding_commit_repository.dart` (29) | Adapter over the store's onboarding commit. | B |
| `qaza_local_store.dart` (856) | `QazaLocalStore` interface + offline-first repository logic (no direct SQL). | W (interface) |
| `workspace_identity_migrator.dart` (296) | Schema-25 canonical ID migration (`guest:`/`google:` → `guest_`/`google_`) inside one control transaction; remaps registry, session, holds, sync + meta keys. Pre-split component, unchanged by the branch except as noted in R-01 path 4 (colon IDs remain acceptable to store APIs). | C |

## C.5 Tables and `meta_store` key ownership (Recovery Stage 3 item 4)

**Tables (17):**

| Table | Owner | In Google file? |
|---|---|---|
| `qaza_records` (Drift) | workspace | yes (own rows) |
| `daily_salah_logs` | workspace | yes |
| `qaza_additions` | workspace | yes |
| `qaza_deletion_actions` | workspace | yes |
| `qaza_deletion_action_record_snapshots` | workspace | yes |
| `qaza_profile_plan_provenance` | workspace | yes |
| `account_profiles` | workspace | yes |
| `account_plan_revisions` | workspace | yes |
| `workspace_sync_metadata` | workspace (one row per workspace) | yes (own row) |
| `local_recovery_snapshots` | workspace (snapshot of the owning workspace) | yes (own snapshot) |
| `meta_store` | split by key (below) | scoped keys only |
| `local_accounts` | control (registry, S4 columns) | **no** |
| `app_session_state` | control | **no** |
| `device_metadata` | control | **no** |
| `workspace_operation_journal` | control | **no** |
| `local_workspace_deletion_holds` | control | **no** |
| `local_account_adoption_snapshots` | control (§4 step 2) | **no** |

This matches S1's inventory exactly, including the owner-guard and
revision-trigger placement. No table was found in a Google file that
S1 assigns to control, and vice versa (verified via the role branches
in C.1 ensures and the manager test's on-disk assertions).

**`meta_store` keys:**

| Key / family | Owner | Notes |
|---|---|---|
| `workspace_revision:<id>` | scoped → Google file | S1 list ✓. Written by revision triggers. |
| `workspace_display_name:<id>` | scoped → Google file | S1 list ✓. |
| `daily_salah_tracking_enabled:<id>` | scoped → Google file | S1 list ✓. |
| `daily_salah_tracking_setup_dismissed:<id>` | scoped → Google file | S1 list ✓. |
| `initial_cloud_backup_pending:<id>` | scoped → Google file | S1 list ✓. |
| `workspace_file_owner` | Google file only | S1 marker ✓ (Part B). |
| `db_revision` | control (global) | Global export counter; never copied (not in the scoped lists used by creation/migration). |
| `is_onboarding_completed` | control (global) | Global onboarding flag. |
| `cloud_setup_choice_complete`, `returning_account_choice_pending`, `guest_google_prompt_shown` | control (global) | Cloud-setup flow state (app_database.dart:429–497). |
| `initial_cloud_backup_pending`, `initial_cloud_backup_pending_account_id` | control (legacy) | Pre-scoping marker pair, still maintained by the marker family (app_database.dart:599–741) for legacy installs; the scoped family is authoritative post-split. Classified control/legacy — preserved, never copied. |
| `qaza_home_completion_mode`, `qaza_home_auto_sequence_prayer`, `qaza_home_selected_prayer` | control (global) | Home UI preferences read via providers.dart:83–113. **Not mentioned by v2.2** — classified here as control/global by evidence (they are device-level UI state); they are *not* copied into Google files (absent from all scoped lists) and must be preserved as-is. Recorded as the inventory's only design-unclassified family; no block is triggered because no code path copies or deletes them per-workspace. |
| Export-document aggregates `daily_salah_tracking_enabled_by_account`, `daily_salah_tracking_setup_dismissed_by_account`, `workspace_display_names_by_account` | — | JSON shapes inside export documents (local_backup_service.dart:405–412), **not** stored keys. |

No other stored key families were found. Unknown-key rule: any key not
in this table must be treated as preserved-or-block until classified
(Recovery Plan Stage 3 item 4); the scoped copy lists in creation
(database_manager.dart:301–312) and migration
(database_manager_migration.dart:13–19) copy exactly the five S1
families and nothing else — conforming.

## C.6 `local_backup_service.dart` (3392) — service surface

| Method | Line | Class | Notes |
|---|---|---|---|
| `exportJson` (scoped + full) | 44 | B | Full export aggregates separate files (R-14). |
| `_exportFromSource` | 184 | B | Scoped export synthesizes `local_accounts`/`app_session_state` rows for Google handles (:351, :367). |
| `adoptGuestWorkspace` | 515 | B | Dispatches: separate target + manager → cross-file; else legacy atomic path (R-06). |
| `_adoptGuestWorkspaceAcrossFiles` | 956 | B | R-05 (no `finalizing`/staging); commit transaction conforms to §4 step 7. |
| `markGuestAdoptionBackupVerified` | 1332 | C | Journal `backup_verified_at`; retention purge :1357 (verified + 30 days, D3/§4 ✓). |
| `saveCloudRecoveryCopyFromBackup` | 1398 | B | Keep Both — creates `recovery_copy_…` workspace (R-14 note). |
| `analyzeImport` | 1520 | B | Payload validation incl. SHA-256 of payload (:1597). |
| `_importSeparateGoogleWorkspace` | 1535 | W | Requires registry `separate` + `committed` (:1585–1591) — R-14 (case (b) note). |
| `importJson` | 1863 | B | Shared-layout import path + dispatch. |
| `_insertMaps`, `_clearBusinessState`, `_filterOwnedRows` | 3315 / 3340 / 2162 | B | Row-level import machinery (pre-existing). |
| Snapshot call sites | passim | B | `local_account_adoption_snapshots` created at :669 and :976 (control); recovery snapshots via `AppDatabase` snapshot methods on the owning handle. |

## C.7 Adapter (`packages/qaza_cloud_adapter/lib/src/`)

| File | Role in routing |
|---|---|
| `cloud_workmanager.dart` (290) | Worker dispatcher — R-11 (conforms). Own-process manager at :59. |
| `phase1_backup_bridge.dart` (188) | `LocalPhase1BackupSource` — routes revision/export/import/snapshot calls through the injected manager when present (:60–179); falls back to the fixed handle when no manager was injected (pre-split behaviour for host-less uses). |
| `google_cloud_providers.dart` (1164) | `GoogleCloudSyncProvider` — `_workspaceDatabase` (:464–471) routes via the injected manager; Keep Both calls `LocalBackupService(_phase1.database, databaseManager: …)` (:916). |
| `sync_engine.dart` (624), `google_drive_store.dart` (749), `cloud_state_store.dart` (385), `google_sign_in_gateway.dart` (374), `cloud_models.dart` (590) | No database construction or routing (payload/state/gateway layers) — inventory-negative, verified by grep. |

## C.8 Construction sites and startup/retry paths

| Site | Routed? |
|---|---|
| `lib/main.dart:121` (`_initializeDatabase`) | Bare `DatabaseManager()`; opens control via the manager ✓ (own-process startup validation). |
| `lib/app/providers.dart:84` (`loadInitialHomePrayerSelection`) | Throwaway bare manager — R-01 path 5 note. |
| `lib/app/providers.dart:290` (`databaseManagerProvider`) | The foreground composition root ✓; bare manager by design (S5). |
| `packages/qaza_cloud_adapter/lib/src/cloud_workmanager.dart:59` | Worker-process manager ✓ (S5/R-11). |
| `apps/qaza_app_cloud/lib/main.dart:113` | `AppDatabase()` direct — **unrouted** (R-12). |
| `lib/features/data_management/qaza_data_management_screen.dart:34` | `getApplicationDocumentsDirectory()` for export *file saving* (not a database construction) — outside S5's scope, noted for completeness. |
| Startup/retry | `main.dart` `_step('database', …)` timeout + diagnostics; `StartupGate` pattern unchanged; manager `initialize()` reconciliation runs from store init and worker start (R-10). |

## C.9 Tests touching this surface (inventory)

- `test/data/local/database/database_manager_test.dart` — the branch's
  only new test file: manager resolution, Guest control handle,
  born-separate creation, legacy migration (R-03), isolation. Injects
  directory + factory properly (setUp :21–33).
- Pre-existing suites exercising the routed surface (all passing at
  `efadadd`; branch status per Stage 2): `local_backup_service_test.dart`,
  `local_backup_adoption_journal_test.dart`,
  `local_backup_adoption_backup_verified_test.dart`,
  `local_backup_adoption_retention_test.dart`,
  `local_backup_integrity_test.dart`,
  `test/features/account/local_session_test.dart`,
  `account_chained_journeys_test.dart` (R-02),
  `guest_workspace_management_screen_test.dart` (PR #347 protected),
  `test/features/onboarding/cloud_setup_choice_screen_test.dart` (R-02),
  `cloud_setup_choice_recovery_test.dart`,
  `daily_salah_migration_test.dart`, `qaza_workspace_paging_test.dart`,
  `qaza_pending_pagination_test.dart`.
- Adapter suites: `cloud_workmanager_test.dart`,
  `google_cloud_providers*_test.dart` (×6), `phase1_backup_bridge_test.dart`,
  `google_sign_in_gateway_test.dart`, `google_drive_store_test.dart`.
- Policy: `tools/offline_architecture_check.py` construction block
  (R-12); `tools/phase_boundary_check.py`, `tools/dead_code_audit.py`
  (pass at all Stage 2 references).

---

# Part D — §8 requirement mapping (status at Stage 3)

| §8 item | Status | Register link |
|---|---|---|
| 1. Per-account files, on-disk assertions, no PII in paths | Partially evidenced (manager tests) | Stage 4 to complete |
| 2. Switch/restart isolation; worker file-access assertion | Blocked by R-01/R-02 | D-A |
| 3. Guest hash invariance; adoption parity | Partially evidenced | R-03, R-04 |
| 4. Retry seeded at every journal phase (incl. `finalizing`) | **Cannot be built as designed** | R-05 |
| 5. Crash recovery per §6 case | Partially implemented | R-04, R-08, R-10 |
| 6. Missing/corrupt/wrong-key/schema failure isolation | Open-path behaviour implemented (manager validation); tests Stage 4 | — |
| 7. Hash correctness with triggers/metadata | Blocked by R-09 definition | D-D |
| 8. No silent overwrite/merge; §7 cases (a)–(d) | Partially evidenced | R-14 |
| 9. Export completeness across layouts | Implemented (R-14); test Stage 4 | R-01(iv) blocks shared-leg |
| 10. Safety-copy consistency under journaling mode | **Not implementable — feature absent** | R-04 |
| 11. Insufficient-storage pre-check | **Not implementable — feature absent** | R-04 |
| 12. Pre-existing suites pass unweakened | **Currently failing** (41 + 2 failures, 2 hangs, 1 design-conflict test) | R-01, R-02, R-03 |

---

# Part E — Legacy policy composition and decisions for Abdul

## E.1 Legacy shared-layout policy (Recovery Stage 3 item 9)

The governing policy, from the authoritative documents, is **full
transition migration**: design §5.2 migrates every resident shared
Google workspace at startup with §5.1's safety mechanics; task-plan
Phase 4 (T4.1–T4.4) implements exactly that, gated by T4.5 device
validation before T4.6 cleanup. Neither document offers a bounded
opt-in conversion or a reset path; a reset is never automatic
(Recovery Plan Stage 3 item 9) and the branch's "explicit development
conversion or reset" error text (R-01 path 5) has no basis in either
document.

**Composition with Recovery Plan v1.2 Stage 6** (settled by Abdul's
adoption of v1.2; not re-opened): v2.2 §5.4's *timing* (cleanup as a
follow-up commit in the same task, after device validation) is
superseded by v1.2 Stage 6's *authorization boundary* — physical
cleanup is default-retain and requires Abdul's explicit approval of the
exact destructive action after evidence. The two compose as: migration
policy and mechanics from v2.2; cleanup **execution** only under
v1.2 Stage 6's six conditions. The branch's commit-time source deletion
(R-04(2)) satisfies neither document: it is §5.4's deletion performed
at the wrong time, without §5.1's safety copy, and without Stage 6's
approval gate.

## E.2 Decisions — DECIDED by Abdul, 2026-10-23

All four decisions were approved by Abdul on **2026-10-23** as a single
package. Each is recorded below as DECIDED with its approved resolution.

- **D-A (from R-01/R-02) — DECIDED: Shape A, registry-true
  resolution.** `shared` resolves to the control handle; publish/active
  gates accept registry-resolved shared workspaces;
  `ensureGoogleWorkspace` stops provisioning/migrating on activation
  (provisioning stays with the verified sign-in creation flow; migration
  becomes the §5.2 startup run). Implementing Shape A is Stage 4
  production work.
- **D-B (from R-03) — DECIDED: APPROVED.** The Stage 4 rewrite of the
  `legacy shared Google data…` test expectation from
  block-with-`StateError` to §5.2 verified migration is authorized
  (listed §8(12) change, reason: expectation conflicts with design
  §5.2). The rewrite is executed and listed in Stage 4, not before.
- **D-C (from R-04) — DECIDED: implement §5.1–§5.4 AS DESIGNED.**
  Safety copy, storage pre-check, retained superseded rows until the
  Recovery-v1.2-Stage-6-gated cleanup, §5.2 startup-run trigger, §5.3
  mid-operation waits. **v2.2 §5 is NOT amended.** Stage 4 migration
  test items (Part D rows 3, 4, 5, 10, 11) are built against the design
  as written.
- **D-D (from R-05/R-09) — DECIDED: AS DESIGNED on both halves.**
  (i) Cross-file adoption gains the §4 `finalizing` + staging-publish
  sequence; **v2.2 §4 is NOT amended** for already-provisioned targets.
  (ii) The canonical hash is unified on §7's scoped-export
  canonicalisation; the branch's `workspace-content-v1` is **NOT**
  adopted into the design record as the definition.

**Stage 4 gate condition: SATISFIED.** The Recovery Plan Stage 3 gate
("Stage 4 cannot begin while D-A, D-C, or D-D are unresolved") no longer
blocks: all three gating decisions — and D-B with them — are decided.
Stage 4 = implement the decided remediations (Shape A routing, §5
mechanics as designed, §4 adoption sequence, §7 hash unification) +
build the §8 requirement-to-test matrix + execute the D-B
test-expectation rewrite, listed per §8(12).


---

# Stage 4 addendum (2026-10-23) — dispositions after remediation

Produced by Recovery Stage 4 under decisions D-A…D-D (approved by Abdul
2026-10-23). The Stage 3 text above is preserved as the historical
record; this addendum records what Stage 4 changed and the resulting
status of every item. Full evidence: `~/workspace/qaza_recovery/STAGE4_REPORT.md`.

## Item dispositions

- **R-01 — CLOSED.** Shape A implemented: `shared` resolves to the
  control handle in `_openDatabaseForWorkspace`; publish/active gates
  accept registry-resolved shared workspaces (control-resolved ID set);
  `ensureGoogleWorkspace` returns the control handle for an existing
  shared row and no longer provisions or migrates on activation (the
  registry is consulted before any filename derivation, so legacy
  colon-form IDs resolve too); the "development conversion or reset"
  throw is removed. Provider-graph routing completed: `appDatabaseProvider`
  owns the single control handle and `databaseManagerProvider` is built
  over it (the branch had inverted this, silently routing
  provider-driven flows to a different database than the overridden
  `appDatabaseProvider` — the R-02 seam break); `DatabaseManager.close()`
  no longer closes a caller-injected control database. All 41 Stage 2
  census failures pass unweakened (app suite 800/800, adapter 133/133).
- **R-02 — CLOSED.** Both journey files run to completion and pass:
  `account_chained_journeys_test.dart` (scenarios 5B, 6, 9) and
  `cloud_setup_choice_screen_test.dart` (all tests).
- **R-03 — CLOSED (D-B executed).** The legacy test was rewritten to the
  §5.2 behaviour as the stage's single authorized pre-existing-test
  change: activation resolves shared→control without provisioning;
  `runStartupMigrations()` performs the verified migration; the record
  is preserved in the separate file; the shared source rows are
  retained as superseded (§5.4). Listed with reason in the Stage 4
  report per §8(12).
- **R-04 — CLOSED (D-C, §5 as designed).** (a) Safety copy: one
  `VACUUM INTO` copy of the control DB, created once before the first
  migration, verified (openable + `integrity_check`; encrypted copies
  verified under the real SQLCipher key via `DatabaseSafetyCopy`),
  never refreshed. (b) Storage pre-check: required = safety copy +
  staging/final + margin, satisfied by a blanket 3× control size;
  free space via injectable provider (POSIX `statvfs` FFI default);
  failure blocks before any file is modified. (c) Startup-run trigger:
  `DatabaseManager.runStartupMigrations()`, invoked from both apps'
  startup database step, for every resident shared Google workspace;
  failure leaves the workspace fully operational on shared.
  (d) §5.3 waits: `adopting`/`restoring` lifecycles and workspaces with
  non-terminal journal operations are skipped per run; the per-workspace
  migration also refuses mid-adopting/restoring states. (e) §5.4
  retention: the commit no longer deletes source rows, scoped meta, the
  sync row, or the recovery snapshot; the registry decides authority.
  Manifest: journal phases `copying`/`verifying`/`finalizing`/
  `committed`/`failed` with distinct `source_hash`/`target_hash`
  (schema-26 journal columns added by ensure), mirrored into
  `db_migration_state`.
- **R-05 — CLOSED (D-D(i), §4 as designed).** Cross-file adoption now
  imports into a staging copy of the target file (`VACUUM INTO` from
  the live file, inheriting its baseline), verifies there (counts,
  foreign-row, owner, integrity, canonical owned-content hash), records
  the `finalizing` intent (staging/final names + content hash) BEFORE
  publish, publishes by file swap with reopen + re-verification and
  rollback to the retained pre-adoption file on failure, then runs the
  §4 step-7 commit transaction and discards the retained file. Retry is
  idempotent at every phase (tested: fresh, `copied`, `finalizing`
  pre-publish, `finalizing` post-publish/pre-commit, committed).
- **R-06 — unchanged** (conforms-in-effect; shared-target adoption
  keeps the single-database path per §4 case (c)).
- **R-07 — DISPOSITIONED, not Stage 4 work.** No Google deletion-hold
  flow exists anywhere in the product (holds are a Guest-only v4.1
  feature); §5.3's file-expiry rule governs a flow that has not been
  built. There is no behaviour to remediate in this stage: when/if a
  Google hold flow is built, §5.3's rule (delete file + registry row
  on expiry) is its acceptance criterion. Recorded here so the matrix
  does not claim coverage.
- **R-08 — CLOSED.** The startup run scans the documents directory:
  `qaza_google_<32hex>.sqlite` files whose names are not the
  deterministic name of any registered Google workspace (nor a recorded
  `db_file_name`) are renamed to `.quarantine` — never exposed, never
  deleted. (Recognition uses the deterministic S3 mapping because
  `db_file_name` is NULL for shared workspaces until migration.)
- **R-09 — CLOSED (D-D(ii)).** One canonicalisation
  (`WorkspaceCanonicalContent`, §7 scoped-export form) is used by
  migration, creation, and export paths; sync/revision counters are
  excluded from the hash and verified separately (migration compares
  the copied sync row field-by-field at commit). Adoption verification
  compares the owned-tables part of the same canonicalisation between
  source and target (scoped metadata in the target is provisioning
  state, verified directly; a recovery snapshot's payload is bound to
  its source workspace by construction). `workspace-content-v1` and
  `workspace-canonical-v1` are retired; design doc §7 updated.
- **R-10 — PARTIALLY CLOSED, remainder dispositioned.** Create/migrate
  journals reconcile at `initialize()` (unchanged). Adoption journals
  reconcile on retry at every phase (now implemented for the staging
  sequence and §8-tested). In addition, the §5.2 startup run never
  migrates a workspace with a non-terminal operation, so an interrupted
  adoption/restore is never compounded by a migration. Startup
  reconciliation of restore journals remains lazy-by-design (a restore
  journal's workspace is exposed only through its own flow); no §8 row
  requires more.
- **R-11 — unchanged** (conforms).
- **R-12 — CLOSED.** `apps/qaza_app_cloud/lib/main.dart` now routes its
  startup database step through `DatabaseManager` (initialize +
  startup migrations), matching the standalone app. The construction
  policy check (`tools/offline_architecture_check.py`) now also matches
  named constructors (`AppDatabase.control()`,
  `GoogleWorkspaceDatabase.forTesting`) and scans the `apps/` root;
  composition roots (manager, providers) and the class-definition file
  are allowlisted with reasons. Check passes.
- **R-13 — CLOSED (evidence discharged).** Realistic schema 25 → 26
  upgrade test built and passing
  (`test/data/local/database/schema_upgrade_25_26_test.dart`); decision
  record updated to link it.
- **R-14 — CLOSED, re-verified against retention.** Full export now
  filters separate workspaces' retained superseded rows out of the
  control leg (the registry decides authority), so each workspace's
  rows appear exactly once; tested across Guest + 2 separate + 1
  shared, before and after the shared workspace migrates. Explicit
  failure when a separate workspace cannot open is preserved and tested.
- **R-15 — CLOSED.** Scoped snapshot selection lives in
  `WorkspaceCanonicalContent.scopedRecoverySnapshot`: newest snapshot
  *for this workspace* (payload-validated), used by migration and the
  canonical hash. Tested with a newer snapshot belonging to another
  workspace present.
- **R-16, R-17 — unchanged** (conforms-in-effect variances, recorded).
- **R-18 — NEW (Stage 4 find): onboarding row verification compared
  DateTimes exactly; drift stores whole seconds — CLOSED.** The
  branch's `_writeOnboardingWorkspaceData` replaced main's
  inserted-count verification with an exact field-by-field read-back
  including `createdAt`/`updatedAt` microseconds, which can never
  succeed against drift's second-precision DateTime storage. This was
  an original-branch regression masked in Stage 2 by the hanging
  suites (the app suite never completed, so this failure was never
  counted). Evidence: test passes at `efadadd`, fails at `ca26a9f9`;
  DAO round-trip probe shows identical second-truncation at both
  commits. Fix (production only): the verification compares DateTime
  fields at storage precision; every other field is still compared
  exactly. `profile_setup_screen_test.dart` passes unweakened.
- **R-19 — NEW (Stage 4 find): Qaza data providers threw when no
  active user was published — CLOSED.** The branch rewrote
  `qazaLocalStoreProvider` / `qazaAdditionRepositoryProvider` to throw
  `StateError` when `activeUserIdProvider` was null (main constructed
  the store over the app database unconditionally), breaking
  session-less explicit-user flows — the Qaza undo feedback helper,
  which deliberately carries an explicit user ID and reads the service
  through the container after its sheet closes. Fix (production only):
  with no active user, the providers keep the pre-split construction
  contract (store over the manager's control database, per-query user
  scoping); with an active user they resolve the manager-published
  active handle as before. `qaza_undo_feedback_widget_test.dart` passes
  unweakened.

## Part D (updated) — §8 requirement mapping at Stage 4 head

| §8 item | Status | Evidence |
|---|---|---|
| 1. Per-account files, on-disk assertions, no PII in paths | **Passing** | Manager tests (filename/PII, born-separate, isolation) + Stage 4 manager tests (file assertions throughout) |
| 2. Switch/restart isolation; worker file-access | **Passing** | Chained journeys scenarios 6/9; local_session suite; adapter worker suites (133/133) |
| 3. Guest hash invariance; adoption parity | **Passing** | Canonical-hash mapping-invariance test; adoption owned-content hash verification in every cross-file adoption test |
| 4. Retry seeded at every journal phase (incl. `finalizing`) | **Passing** | Adoption journal suites (pre-existing) + Stage 4 service tests: fresh, `copied`, `finalizing` pre-publish (staging lost → redo), `finalizing` post-publish/pre-commit, committed |
| 5. Crash recovery per §6 case | **Passing** | Migration reconciliation (pre-existing) + Stage 4: staging-only, final-without-commit, committed-with-missing/invalid file, registry/file disagreement, unknown file → quarantine, mid-operation skips |
| 6. Missing/corrupt/wrong-key/schema failure isolation | **Passing** (wrong-key by substitute, see report; substitute accepted as exception E-1 — see gate note below) | Stage 4 isolation tests: corrupt file → account-specific `StateError`, no fallback, registry unchanged, other workspaces usable; wrong-owner swap rejected per workspace; missing file (pre-existing + export test) |
| 7. Hash correctness with triggers/metadata | **Passing** | Unified canonicalisation (R-09); hash invariance + content-sensitivity tests; sync-row field-by-field verification at migration commit |
| 8. No silent overwrite/merge; §7 cases | **Passing** | Keep Both + scoped restore suites (pre-existing, green); collision files never overwritten (migration + adoption publish tests) |
| 9. Export completeness across layouts | **Passing** | Stage 4 export test: Guest + 2 separate + 1 shared, exactly-once, before/after migration retention; explicit failure on unopenable workspace |
| 10. Safety-copy consistency under journaling mode | **Passing with one device-only exception (E-1, accepted)** | Safety copy created/verified/never-refreshed tests under the plaintext test executor; the encrypted (SQLCipher) verification path is implemented but exercisable only under the real encrypted setup — see the Stage 4 report's exception list (E-1) and the gate note below |
| 11. Insufficient-storage pre-check | **Passing** | Pre-check blocks before any file is modified (injected free-space provider); fault legs at copy/verify/publish covered by migration failure + adoption publish rollback tests |
| 12. Pre-existing suites pass unweakened | **Passing** | App 800/800, adapter 133/133 at the Stage 4 head; the only pre-existing-test change is the D-B rewrite (R-03), listed with its approved reason |

### Stage 4 gate status — exception E-1 accepted (2026-10-23)

**E-1 ACCEPTED by Abdul, 2026-10-23 — Stage 5 device cases (on-device safety-copy verification + corrupt-file case) will cover the real-encryption behaviours.**

E-1 is the device-only exception recorded in the Stage 4 report (§9): the real-SQLCipher behaviours — verification of the encrypted migration safety copy under the app key and the literal wrong-key open of a separate workspace file — cannot execute in the host plaintext test harness, so §8 items 6 and 10 carry automated substitutes (full safety-copy lifecycle under the plaintext executor; the §6 block path exercised via the corrupt/wrong-owner cases). With Abdul's written acceptance of E-1 on 2026-10-23, and every other §8 row passing at the Stage 4 head (`88332966`), **the Stage 4 gate is PASS**. The Stage 5 device checklist discharges E-1's mitigation: on-device safety-copy existence + migrated-workspace-open verification, and the device corrupt-file case.
