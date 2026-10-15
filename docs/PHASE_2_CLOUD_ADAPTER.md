# Phase 2 — Isolated Cloud Adapter

Implementation status: 2026-10-09.

## Architecture audit

Phase 1 is the root qaza_namaz application. Its pubspec.yaml contains no Firebase, Google Sign-In, Google Drive, googleapis, or WorkManager dependency.

Phase 2 lives in packages/qaza_cloud_adapter and depends on Phase 1 through the existing LocalBackupService and AppDatabase APIs. The root application does not depend on Phase 2.

The phase boundary is enforced by tools/phase_boundary_check.py.

## Phase 1 contracts preserved

The cloud adapter treats the existing Phase 1 JSON export as the payload. It wraps that payload with cloud-only envelope metadata but does not modify the Phase 1 metadata/data contract.

The local db_revision remains a monotonic local logical revision. Cloud lineage uses backup_id for cloud identity and base_backup_id for branch ancestry.

## Modules

| Module | Implementation |
| --- | --- |
| 19 Standalone package | packages/qaza_cloud_adapter |
| 20 Google authentication | GoogleSignInGateway, isolated to Phase 2 |
| 21 Drive authorization/storage | GoogleSignInGateway + GoogleDriveAppDataStore |
| 22 Cloud backup lineage | CloudLineage + cloud envelope |
| 23 Conflict resolution | CloudSyncEngine |
| 24 Background synchronization | CloudSyncScheduler + background dispatcher |
| 25 Definition of Done | package boundary, regression tests, CI, documentation |

## Dependency and removal rule

Phase 1 must remain buildable and runnable when packages/qaza_cloud_adapter is removed. The Phase 2 workflow is a separate workflow file and can be removed with the package.

No Phase 1 file imports qaza_cloud_adapter, and no Phase 1 dependency is added for cloud/authentication functionality.

## Background host integration

Phase 1 must not initialize WorkManager or Google services.

A future Phase 2-enabled host should initialize the scheduler from its own composition root:

    final scheduler = CloudSyncScheduler();
    await scheduler.initializeAndSchedule(
      serverClientId: '<web-client-id>.apps.googleusercontent.com',
    );

The Phase 2 background dispatcher opens the existing Phase 1 AppDatabase only inside the Phase 2 worker isolate. It does not add any startup dependency to Phase 1.

## Device QA gate

Real Google authentication, OAuth consent, Drive upload/download, and Android background execution require a configured Google Cloud OAuth client and an Android device/emulator with the Phase 2 package intentionally enabled.

Those production credentials and the Phase 2 host wiring do not belong in Phase 1 and are not present in this repository branch.


## Optional cloud application host

The cloud-enabled target lives in `apps/qaza_app_cloud`. It depends on both
`qaza_namaz` and `qaza_cloud_adapter`; the offline root target does not depend
on the adapter. The host injects `CloudAccountProvider` and `CloudSyncProvider`
through Riverpod. Default offline implementations report cloud support as
unavailable, so the offline Account Page does not expose cloud controls.

Build the cloud-enabled Android target from its own directory:

```bash
cd apps/qaza_app_cloud
flutter pub get
dart analyze
flutter build apk --release --dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>.apps.googleusercontent.com
```

Configure the server client ID with a local build define or protected CI
secret. Never commit OAuth secrets, signing keys, or access tokens. The cloud
host manifest grants INTERNET; the offline application manifest does not.

### Worker safety and destructive-restore recovery

Cloud enabled state and the daily automatic-sync preference are persisted
separately. The worker reads both before constructing the encrypted database
or initializing Google authorization. Disconnect writes the cloud-disabled
guard and disables the automatic preference before cancelling unique periodic
work or signing out. The sync engine rechecks the cloud flag before remote reads,
uploads and data replacement because WorkManager cancellation cannot guarantee
that an already-running task is interrupted immediately. The cadence is fixed
to one day even if a caller supplies a shorter interval; Android may defer the
work beyond the requested interval.

Detected conflicts are persisted in adapter state and are exposed by the cloud
sync provider after app relaunch. The Account Page presents an explicit action
to reopen the conflict decision. Both automatic remote-only restores and
user-confirmed remote restores save and read back a local recovery snapshot
before import. If that snapshot cannot be verified, the restore is cancelled.
The latest remote backup/version is rechecked immediately before replacing local
data or publishing a keep-local conflict resolution.

A first connection that discovers an existing Drive backup is always surfaced as
a conflict, even if the local database revision is still at its initial value.
A confirmed `useRemote` decision first stores the current Phase 1 backup in the
encrypted local SQLite database. The Account Page offers an explicit recovery
action to restore that snapshot. The recovery table is excluded from ordinary
backup payloads to avoid recursive snapshots.

The daily schedule is best-effort under Android WorkManager and is not an exact
24-hour execution guarantee. Device OAuth/Drive testing and consent/privacy
review remain release gates; CI cannot mark those manual checks as passed.


### Persistent Google session and non-interactive worker authorization

Startup and Account navigation must not initiate interactive sign-in or launch
Drive-consent UI. The Dart gateway uses Google Sign-In 7.x for explicit
foreground authentication and the selected account's authorization client for
foreground scope consent.

For Android background synchronization, the adapter's registered native plugin
uses Google Play services' Identity AuthorizationClient with the application
context. The worker requests the already-granted `drive.appdata` scope in each
new Flutter engine rather than depending on an in-memory Dart account. If the
authorization result requires a resolution, the plugin reports
`interactionRequired` and never launches the pending intent. No access or
refresh token is written to SharedPreferences; an access token exists only in
the active runtime's HTTP client. If Drive returns HTTP 401, the native token
cache is cleared so the next attempt can request a replacement.

Account restoration declares the connection ready only after Drive authorization
has been obtained non-interactively. On Android, the native request explicitly
targets the previously connected email using Android's account selector, then
validates the returned access token and exact Drive scope. The cached email is
only an account selector; cached name/email/photo never prove authorization by
themselves. Real-device testing must verify that the Google account selected
during initial sign-in is the one used by the background authorization request.

If the native authorization client reports that a resolution is needed, the
worker skips without opening UI and persists reconnect-required. It preserves
the user's cloud and automatic-backup preferences and keeps the periodic work
registered. The Account Page offers an explicit Connect/Reconnect action to
resolve missing consent. Successful restoration clears the reconnect-required
flag and retains the existing sync cursor and conflict safeguards.

This is a supported implementation path, not a substitute for release
validation: real Android device testing with the configured OAuth client must
prove that the previously selected default account and granted Drive scope can
be used after process recreation. WorkManager remains best-effort and does not
guarantee an exact daily execution time.

## Initial backup and fresh-install restore flow

When Google Drive discovery returns no backup during first-run cloud setup, the
app records a durable local `initial_cloud_backup_pending` marker before
routing to profile setup. After the profile and Qaza plan have been committed,
StartupGate routes to the initial-backup screen and invokes the existing sync
engine with its initial-backup path. Transfer progress is based on request-body
bytes; the UI caps this display at 99% until Drive confirms the write and the
sync cursor is persisted. If the upload fails, the local data and pending marker
remain, allowing a retry without repeating onboarding and another attempt on a
later app launch.

Automatic restore is limited to a verified fresh database: onboarding must be
incomplete, the logical database revision must still be at its initial value,
and no profile, Qaza record, plan revision, or mutation data may exist. The
existing sync engine still revalidates the local revision, cloud cursor, and
latest remote backup and persists a verified local recovery snapshot before
import. A non-fresh local database continues through the explicit conflict
resolution flow. The offline-only app remains independent of the cloud adapter.

## Owner setup checklist for Android OAuth and release

1. In Google Cloud Console, select the project for this app and enable the
   Google Drive API.
2. Configure the OAuth consent screen and add the intended test users while
   the app is in testing. Publish/review the consent screen before general
   release when Google requires it.
3. Create an OAuth client for the Android application using the cloud host's
   application ID (`com.qaza_namaz.com`) and the SHA-1 certificate fingerprint
   for the certificate that will sign the installed APK. Add the correct web
   OAuth client ID as `GOOGLE_SERVER_CLIENT_ID`; do not put a client secret in
   the app. If debug, CI, and production builds use different certificates,
   register the corresponding Android OAuth clients/fingerprints as needed.
4. Build the cloud host from `apps/qaza_app_cloud`. For local testing, supply
   the web client ID as a Dart define. For GitHub Actions, set the protected
   `GOOGLE_SERVER_CLIENT_ID` repository Actions secret. Provide the production
   signing configuration privately if an installable release APK is required;
   never commit `key.properties`, keystores, or passwords.
5. Install the resulting host on a real Android device. Verify sign-in,
   separate `drive.appdata` authorization, initial backup/restore, two-device
   divergence, disconnect, app force-stop/relaunch, and daily WorkManager
   execution. Capture results and logs with credentials/tokens redacted.
6. Review the user-facing consent/backup explanation and the published privacy
   policy. Confirm data purpose, retention/deletion expectations, account
   disconnect behavior, and how the user restores or recovers local progress.

These are release-gate actions, not assumptions: the repository cannot verify
OAuth consent, the selected signing certificate, physical device behavior, or
the privacy policy on the owner's behalf. Record each result as PASS, FAIL, or
PENDING and do not enable production rollout while a required check is pending.
