# Instructions for AI Coding Agents

## Release status and test-data policy

**Current project status: PRE-RELEASE / NOT PUBLISHED.** Qaza Namaz has not been released to production users. The Google accounts and app data currently used for testing are test-only.

Until the owner explicitly confirms that the app has been published or is handling real users' data, apply this policy:

- **Do not treat existing test data as production data.** It is disposable. There is no requirement to preserve the current local databases, Guest or Google workspace records, test migration state, or Qaza Namaz backup artifacts created during testing.
- **Data resets are authorized for development work.** When needed to simplify or rebuild the storage architecture, it is acceptable to clear or recreate the app's local databases, remove obsolete test-only database files, reset test workspace state, and delete or replace Qaza Namaz's own test backups in Google Drive. Do not ask for confirmation solely to preserve these test records.
- **Do not add complexity solely to preserve disposable pre-release data.** Backward migrations, legacy compatibility paths, data-retention layers, and recovery mechanisms should be kept only when they are needed for the intended architecture, meaningful tests, or another explicit requirement—not merely to keep old test data.
- **Keep the implementation correct.** Disposable test data is not a reason to weaken encryption, Google-account isolation, backup/restore correctness, error handling, or the tests that verify those behaviours. Prefer the simplest sound implementation over preserving the current implementation for its own sake.
- **Keep destructive actions scoped to this app's test data.** Do not delete the actual Google accounts, unrelated Google Drive files, credentials, release-signing material, source code, or unrelated project data. Only reset/delete backup files that can be identified as Qaza Namaz app-owned test artifacts.
- **Do not infer that the release status has changed.** This pre-release policy remains active until the owner confirms publication or real-user data is in use.

## When the app is published

When the owner confirms that Qaza Namaz has been published or is handling real users' data, update this instruction and switch to production data-safety practices. Treat real user data as valuable: avoid destructive changes without explicit approval, plan and validate required migrations, and provide appropriate backups and recovery paths.

Until then, prioritize a clean, maintainable rebuild of Google authentication, per-account encrypted local databases, and Google Drive backup without carrying unnecessary legacy complexity forward.
