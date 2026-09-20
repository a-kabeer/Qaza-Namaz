# Local data protection

**Priority:** P0/P1  
**Status:** **Merged — Device QA Pending**

## Task checklist

- [x] Evaluate database encryption
- [x] Protect encryption key using Android secure storage/Keystore-backed secure storage
- [x] Encrypt sensitive local data
- [x] Protect backup files
- [x] Avoid storing unnecessary sensitive diagnostics
- [x] Review sync outbox error persistence

## Current implementation

- SQLite3MultipleCiphers is enabled through the sqlite3 build hook.
- Drift opens the production database through encrypted NativeDatabase.
- A 256-bit random key is created once and stored with flutter_secure_storage.
- Existing plaintext qaza_namaz.sqlite files are migrated before Drift opens them.
- Existing Android backup rules remain encryption-gated and device transfer excludes the local ledger.
- Durable sync outbox errors are reduced to non-sensitive categories instead of raw exception strings.

## Verification status

- [x] Implementation
- [x] Unit tests added
- [x] Full regression tests
- [x] Analyze
- [x] CI
- [ ] Device QA where required
- [x] UX/security review of failure behavior
- [x] Documentation
- [x] Merge

## Evidence log

| Date | Status | Evidence |
|---|---|---|
| 2026-09-20 | In Progress | Encrypted SQLite/key storage/migration and outbox error classification implemented on branch hardening/local-data-protection-20260920. |
| 2026-09-20 | Merged | PR #46 merged to `main` as `1144e651e034c25d14cb726462af371d14ece452`. CI run #1463 passed: Android, Firestore rules, Analyze, Linux tests, and Windows tests. |

**Rule:** update this tracking file, not the master plan, when status changes.

## Remaining verification

- Android physical-device QA remains recommended/required for final release certification: verify first-run key creation, upgrade from a plaintext database, restart persistence, wrong/corrupt key handling, backup/restore behavior, and device-to-device transfer exclusion.

**Rule:** update this tracking file, not the master plan, when status changes.
