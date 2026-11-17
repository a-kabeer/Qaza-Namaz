# Instructions for AI Coding Agents

## Release status and test-data policy

**Current project status: PRE-RELEASE / NOT PUBLISHED.** Qaza Namaz has not been released to production users. The test accounts and app data currently used for development and testing are test-only.

Until the owner explicitly confirms that the app has been published or is handling real users' data, apply this policy:

- **Do not treat existing test data as production data.** It is disposable. There is no requirement to preserve the current local databases, Guest workspace records, test migration state, or test remote data created during testing.
- **Data resets are authorized for development work.** When needed to simplify or rebuild the storage architecture, it is acceptable to clear or recreate the app's local databases, remove obsolete test-only database files, reset test workspace state, and delete or replace Qaza Namaz's own test data in Supabase or local storage. Do not ask for confirmation solely to preserve these test records.
- **Do not add complexity solely to preserve disposable pre-release data.** Backward migrations, legacy compatibility paths, data-retention layers, and recovery mechanisms should be kept only when they are needed for the intended architecture, meaningful tests, or another explicit requirement—not merely to keep old test data.
- **Keep the implementation correct.** Disposable test data is not a reason to weaken encryption, account isolation, synchronization correctness, error handling, or the tests that verify those behaviours. Prefer the simplest sound implementation over preserving historical implementation details for their own sake.
- **Keep destructive actions scoped to this app's test data.** Do not delete credentials, release-signing material, source code, or unrelated project/cloud data. Only reset or delete data that can be identified as Qaza Namaz app-owned test artifacts.
- **Do not infer that the release status has changed.** This pre-release policy remains active until the owner confirms publication or real-user data is in use.

## Architecture and Cloud Target: Supabase (Offline-First)

- **Supabase is the active cloud architecture target.** Google Drive remote backup, sync, and WorkManager integrations have been decommissioned and removed.
- **Offline-first local storage:** The primary ledger remains local and encrypted (using SQLite3 Multiple Ciphers / Drift), capable of functioning completely offline.
- **Target cloud capabilities:** Supabase Auth, PostgreSQL with Row Level Security (RLS), and offline-first data synchronization (evaluating PowerSync or custom sync).
- **Guest and account adoption:** Local Guest usage remains first-class. Guest-to-authenticated cloud account adoption must be explicit, durable, and crash-safe without silent overwrites.

## When the app is published

When the owner confirms that Qaza Namaz has been published or is handling real users' data, update this instruction and switch to production data-safety practices. Treat real user data as valuable: avoid destructive changes without explicit approval, plan and validate required migrations, and provide appropriate backups and recovery paths.

Until then, prioritize a clean, maintainable rebuild with Supabase offline-first synchronization and encrypted local storage, without carrying unnecessary legacy Google Drive or backward-migration complexity forward.
