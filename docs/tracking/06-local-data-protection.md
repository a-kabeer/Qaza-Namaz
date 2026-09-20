# Local data protection

**Priority:** P0/P1  
**Status:** **In Progress**

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
- [ ] Full regression tests
- [ ] Analyze
- [ ] CI
- [ ] Device QA where required
- [x] UX/security review of failure behavior
- [x] Documentation
- [ ] Merge

## Evidence log

| Date | Status | Evidence |
|---|---|---|
| 2026-09-20 | In Progress | Encrypted SQLite/key storage/migration and outbox error classification implemented on branch hardening/local-data-protection-20260920. |
| 2026-09-20 | Pending verification | Full analyzer/CI/device verification and merge remain outstanding. |

**Rule:** update this tracking file, not the master plan, when status changes.
