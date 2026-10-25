# Run A PoC Runbook — Windows PowerShell

**Status:** Runbook only; experiments have not run.  
**Last updated:** 2026-10-25 (Asia/Karachi)  
**Scope:** Disposable PowerSync + Supabase + SQLite encryption + Drift proof of concept.  
**Main repo baseline:** 4e9747ed2005806ae81ede78ef2448af9b483aa7.  
**Verified reference starter commit:** `eb149604014f243c6379f50c99bfdc9fa086abf6` (`powersync-community/flutter-powersync-supabase`).

**PowerShell session rule:** use one interactive PowerShell window for all phases, including the key generation in Phase 5 and the tests/builds in Phase 7. `flutter run` occupies the foreground; press `Ctrl+C` to stop it and return to the same prompt. Do not close that window before the encrypted database tests are complete. If a new window is unavoidable, re-create the path variables from the existing folders, but do not invent/regenerate a key for an existing encrypted database; see the recovery note after Phase 0.

## Safety rules

- Do all work under a new sibling scratch directory, not inside the Qaza Namaz repository.
- Do not add PoC packages to the app's root pubspec, change app code, use current Qaza test databases/keys, or connect this experiment to any real/remote Supabase project.
- Use local Supabase and the PowerSync community starter only. Its demo signing keys/users/data are disposable and are not safe for production.
- Never commit .env.local, signing_keys.json, app_config.dart, generated test keys, APKs or local database files.
- Do not copy the sample app's logout implementation into Qaza Namaz without changing it: the current demo calls disconnectAndClear(), which clears local data. Qaza's intended sign-out must retain the encrypted local workspace and pending queue.
- The reference template uses anonymous authentication and a demo counters table. That validates basic connectivity only; it does not satisfy Qaza's final Google/Supabase Auth, account ownership, guest adoption or two-user security requirements.
- Stop on a failing step and preserve logs. Do not reset, clean or delete anything in the real repository to fix a scratch-project issue.

## Phase 0 — Verify required tools

From the existing Qaza Namaz repository root, run:

    $ErrorActionPreference = 'Stop'
    $RepoRoot = (git rev-parse --show-toplevel).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $RepoRoot) { throw 'Not inside the Qaza Namaz Git repository.' }

    '--- Tool availability ---'
    foreach ($Name in @('git', 'flutter', 'dart', 'node', 'npm', 'docker', 'wsl')) {
        $Command = Get-Command $Name -ErrorAction SilentlyContinue
        if ($Command) { '{0}: {1}' -f $Name, $Command.Source }
        else { '{0}: MISSING' -f $Name }
    }

    '--- Versions and Android diagnostics ---'
    git status -sb
    flutter --version
    dart --version
    node --version
    npm --version
    docker version
    docker compose version
    wsl --version
    flutter doctor -v
    flutter devices

Requirements:
- Node.js 20 or later for the Supabase CLI via npm. If missing, one supported Windows install command is `winget install -e --id OpenJS.NodeJS.LTS`; close and reopen PowerShell after installation, then verify `node --version` and `npm --version`.
- Docker Desktop installed and running with the **WSL 2 backend enabled** for this runbook; verify with `wsl --version`, `docker version` and `docker compose version`. Current Docker Desktop documentation lists WSL 2.1.5 or later for its WSL 2 backend. Installation may require an administrator prompt and a Windows restart. Official guidance: https://docs.docker.com/desktop/setup/install/windows-install/ and https://docs.docker.com/desktop/features/wsl/.
- Flutter/Dart and an Android emulator or test device that your current project toolchain can build for.
- Adequate disk space for the local Supabase stack, Docker images and Android build.

If any tool is missing, stop and install/configure it first. Do not install tools or restart Windows mid-run without saving your current notes. Official references:
- https://supabase.com/docs/guides/local-development/cli/getting-started
- https://supabase.com/docs/guides/local-development

## Phase 1 — Create an isolated scratch folder and clone the official starter

This command refuses to overwrite an existing scratch folder.

    $ScratchParent = Split-Path $RepoRoot -Parent
    $PocRoot = Join-Path $ScratchParent 'qaza-powersync-poc-20261025'
    if (Test-Path $PocRoot) {
        throw "Scratch path already exists. Choose a new dated folder; do not delete it: $PocRoot"
    }
    New-Item -ItemType Directory -Path $PocRoot | Out-Null
    $ReferenceRoot = Join-Path $PocRoot 'reference'
    git clone https://github.com/powersync-community/flutter-powersync-supabase.git $ReferenceRoot
    if ($LASTEXITCODE -ne 0) { throw 'The official starter clone failed.' }
    git -C $ReferenceRoot checkout eb149604014f243c6379f50c99bfdc9fa086abf6
    if ($LASTEXITCODE -ne 0) { throw 'Could not check out the reviewed reference starter commit.' }
    $StarterSha = (git -C $ReferenceRoot rev-parse HEAD).Trim()
    if ($StarterSha -ne 'eb149604014f243c6379f50c99bfdc9fa086abf6') { throw "Unexpected starter SHA: $StarterSha" }

    $RequiredStarterPaths = @(
        'README.md',
        '.env.local.template',
        'docker/compose.yaml',
        'docker/powersync.yaml',
        'supabase/config.toml',
        'supabase/migrations/20250819090132_counters.sql',
        'flutter_counter/pubspec.yaml',
        'flutter_counter/lib/app_config_template.dart',
        'flutter_counter/lib/powersync.dart',
        'flutter_counter/lib/models/schema.dart'
    )
    $MissingStarterPaths = @($RequiredStarterPaths | Where-Object { -not (Test-Path (Join-Path $ReferenceRoot $_)) })
    if ($MissingStarterPaths.Count -gt 0) { throw "Starter layout differs; inspect upstream before proceeding: $($MissingStarterPaths -join ', ')" }
    $ComposeText = Get-Content (Join-Path $ReferenceRoot 'docker/compose.yaml') -Raw
    if ($ComposeText -notmatch '(?m)^\s*container_name:\s*powersync_demo\s* = Join-Path $PocRoot 'qaza_poc_client'
    Copy-Item -Path (Join-Path $ReferenceRoot 'flutter_counter') -Destination $ClientRoot -Recurse

    Get-ChildItem $PocRoot
    git -C $ReferenceRoot rev-parse HEAD

The starter file names and `powersync_demo` container name above were verified against upstream commit `eb149604014f243c6379f50c99bfdc9fa086abf6`. The validation block intentionally stops if the checkout no longer matches the expected shape. Record this starter SHA in the experiment notes. Do not run this command against the actual Qaza Namaz repository.

## Phase 2 — Install and start local Supabase

Continue in the same PowerShell window. `Set-Location` changes folders without discarding `$RepoRoot`, `$PocRoot`, `$ReferenceRoot` or `$ClientRoot`:

    Set-Location $ReferenceRoot
    npm install --save-dev supabase
    npx supabase --version

The starter already includes its Supabase directory and migrations, so do not run supabase init again. Create a local-only environment file and signing key:

    Copy-Item .env.local.template .env.local
    npx supabase gen signing-key

Open the local configuration:

    notepad .\supabase\config.toml

Find the line under the Auth section that reads:

    #signing_keys_path = "./signing_keys.json"

Uncomment it so it reads:

    signing_keys_path = "./signing_keys.json"

Save the file. Keep signing_keys.json local and never commit it.

Start the local Supabase stack:

    npx supabase start
    npx supabase status

Expected: local API/Auth/Postgres services report running. If Docker is not running, fix Docker Desktop before retrying. Do not run supabase link, db push to a hosted project, or any command that targets a remote project.

Official Windows install instructions for a global CLI are also available via Scoop; this runbook uses the project-local npm CLI so the version is recorded in the scratch package lockfile.

## Phase 3 — Start the sample PowerSync service on loopback only

The community starter includes docker/compose.yaml and docker/powersync.yaml. It uses a demo .env.local with local development values. Do not replace these with real credentials.

For a safer local-only host binding, edit the scratch file:

    notepad .\docker\compose.yaml

Change the port mapping line from the broad host mapping to:

    - "127.0.0.1:8080:8080"

The sample .env.local sets PS_PORT=8080. Keep the container's internal port at 8080. Save.

Start the service:

    docker compose --file .\docker\compose.yaml --env-file .\.env.local up -d
    docker compose --file .\docker\compose.yaml --env-file .\.env.local ps
    docker logs powersync_demo --tail 100
    Test-NetConnection 127.0.0.1 -Port 8080

Expected: the PowerSync container is running and the TCP check succeeds. If the container exits, save its logs and stop; do not change production app configuration to work around it. Keep the entire development stack local and do not expose it publicly.

The sample Supabase stack exposes its own local ports. Run it only on a trusted development machine/network and follow Supabase's current local network-security guidance.

## Phase 4 — Run the unmodified reference demo first

Continue in the same PowerShell session and use the copied client, not the official reference source. (PowerShell variables such as $ClientRoot are session-scoped.)

    Set-Location $ClientRoot
    if (Test-Path .\lib\app_config.dart) { throw 'app_config.dart already exists. Inspect it and do not overwrite it automatically.' }
    Copy-Item .\lib\app_config_template.dart .\lib\app_config.dart
    flutter pub get
    flutter pub deps --style=compact
    flutter devices

The template already selects the Android emulator host as 10.0.2.2 for local service ports. For a physical Android phone, the emulator host address is not correct; configure a trusted LAN address and local firewall rules only if testing on a physical device.

If using an Android emulator, replace DEVICE_ID with the exact emulator ID listed by flutter devices:

    flutter run -d DEVICE_ID

Expected: the reference counter demo opens and can read/modify its counters with the local Supabase + PowerSync service running. Important: the starter's counters stream is deliberately an unfiltered demo stream, so all demo users can see the synthetic counters. Never use that stream with Qaza data; POC-5 must replace it with strict owner-filtered streams and prove cross-user isolation. Verify:
1. Add a counter while online and confirm it appears.
2. Stop the emulator's network or stop the PowerSync container, add a local counter, and confirm the UI still operates offline.
3. Force-stop and reopen the demo while disconnected and verify local changes remain.
4. Restore network/PowerSync and verify the local change eventually syncs.

This is only a backend-connectivity baseline, not proof of database encryption or Qaza account safety. Record the app logs, docker logs and exact starter SHA.

## Phase 5 — Pin packages and prepare the encrypted/Drift spike

Work only in qaza_poc_client.

Record the resolved versions before adding dependencies:

    flutter pub deps --style=compact | Out-File -Encoding utf8 .\deps-before-drift.txt
    Select-String -Path .\pubspec.lock -Pattern 'powersync:|supabase_flutter:|sqlite_async:|drift_sqlite_async:|version:'

Add the following versions to this scratch client only, using exact version constraints so Pub does not silently float them during this experiment:

    flutter pub add 'powersync:=2.5.0' 'supabase_flutter:=2.18.3'
    flutter pub add 'drift:=2.35.0' 'drift_sqlite_async:=0.3.1' 'sqlite_async:=0.14.6' 'flutter_secure_storage:=10.3.4'
    flutter pub add --dev 'build_runner:=2.16.1' 'drift_dev:=2.35.0'
    flutter pub get

The official pub.dev version pages currently list these versions individually: `powersync 2.5.0` (Dart >=3.10), `supabase_flutter 2.18.3` (Dart >=3.9), `drift 2.35.0` (Dart >=3.10), `drift_sqlite_async 0.3.1` (Dart >=3.5), `sqlite_async 0.14.6` (Dart >=3.6), `flutter_secure_storage 10.3.4` (Dart >=3.3), `build_runner 2.16.1` (Dart >=3.11), and `drift_dev 2.35.0` (Dart >=3.10). See the package links below. Individual publication is not proof of joint compatibility; only a successful local dependency resolution proves that this pinned set resolves together.

If dependency resolution fails, preserve the full resolver output and stop. Do not override constraints, loosen the exact pins or force versions with `dependency_overrides` merely to obtain a green solve. Record the full resolver output and actual resolved versions in `pubspec.lock`; if any lockfile version differs from the requested exact version, stop and inspect before continuing. Review the license files for direct and transitive packages and the terms for the exact PowerSync deployment edition before recommending any hosted use; record the result without assuming a feature/pricing entitlement.

Open the scratch client's pubspec.yaml and add this top-level build-hook configuration if it is absent:

    hooks:
      user_defines:
        sqlite3:
          source: sqlite3mc

This is the documented native encryption setup for PowerSync with SQLite3MultipleCiphers. Keep the hook in the scratch client manifest; do not copy it into the Qaza app during Run A.

Confirm package resolution, then check for the encryption pragma only in the disposable PoC code. Official EncryptionOptions takes a key and supports SQLite3MultipleCiphers/SQLCipher; use the documented PowerSync constructor argument rather than manually issuing PRAGMA key on a connection owned by PowerSync:
- https://pub.dev/documentation/powersync/latest/powersync/EncryptionOptions-class.html
- https://pub.dev/documentation/powersync/latest/powersync/PowerSyncDatabase-class.html

### Separate Google provider experiment

The local starter's anonymous sign-in does not test the intended Google sign-in path. Keep POC-GOOGLE separate from the email/password or local anonymous account-isolation tests. It must verify Google provider linking/sign-in through Supabase Auth, stable Supabase user UUID behavior, cancellation during pending reconciliation, and same-owner session recovery. This experiment remains NOT RUN until the owner explicitly approves creation/configuration of a throwaway OAuth client. Do not use a production OAuth client or personal user data.

### Required test harness to implement in the scratch client

### Generate an ephemeral PoC key

Use a fresh random 32-byte key encoded as unpadded Base64URL, matching the current local key format. This key is for this scratch app only. Do not print it, write it into a source file or use the Qaza app's key.

    $Rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $KeyBytes = New-Object byte[] 32
    $Rng.GetBytes($KeyBytes)
    $Rng.Dispose()
    $CorrectPocKey = [Convert]::ToBase64String($KeyBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $env:POC_DB_KEY = $CorrectPocKey
    "PoC key length (not the key): $($env:POC_DB_KEY.Length)"

Keep this PowerShell session open while testing; the environment variable will be lost in a new session. Pass it only to the scratch app launch:

    flutter run -d DEVICE_ID "--dart-define=POC_DB_KEY=$env:POC_DB_KEY"

In the Dart harness, load it with String.fromEnvironment('POC_DB_KEY') and fail closed if empty. The environment define is acceptable only for this disposable experiment, because build defines are embedded in the scratch binary; production key storage must use platform-secured storage. Within the test harness, generate a separate random wrong key in memory for the wrong-key test, and never print either key.

Do not simply point Drift at the existing Qaza database. In qaza_poc_client, build a minimal purpose-specific harness that:

1. Creates one small synced table (for example, poc_records with id, owner_id, value and updated_at) in the PowerSync Schema.
2. Opens a disposable PowerSyncDatabase at the app support directory with EncryptionOptions and a fresh 32-byte random test key. Obtain the key from a scratch-only launch define or another ephemeral test secret mechanism; never hard-code it in committed code, source control or the real app.
3. Inserts and reads a row using PowerSync's own SQL API. Closes and reopens the same path with the same key and verifies the row survives.
4. Attempts to open that file with a wrong test key and verifies that it fails to read the schema/data; then confirms the correct key can reopen the database again.
5. Uses the PowerSyncDatabase as the SqliteConnection supplied to SqliteAsyncDriftConnection and proves a Drift DAO can read/write the same table. Query watch notifications, transactions and nested transactions need specific tests.
6. Defines migrations carefully. PowerSync owns the schema for synced tables, while Drift schema verification/migrations may try to create tables that already exist. Do not accept a test that disables migrations without documenting why or that tests a separate SQLite connection/file.
7. Tests local-only tables separately and explains whether they belong in PowerSync Schema or RawTable.
8. Uses the same disposable database file for PowerSync and Drift so that writes made through either API are immediately visible through the other.

The official drift_sqlite_async package documents query CRUD, transactions, nested transactions, update propagation and optional Drift migrations, and its connection accepts a SqliteConnection. PowerSyncDatabase implements SqliteConnection. This makes the bridge plausible but not yet proven for the chosen schema/migration arrangement:
- https://pub.dev/packages/powersync/versions
- https://pub.dev/packages/supabase_flutter/versions
- https://pub.dev/packages/drift/versions
- https://pub.dev/packages/drift_sqlite_async/versions
- https://pub.dev/packages/sqlite_async/versions
- https://pub.dev/packages/flutter_secure_storage/versions
- https://pub.dev/packages/build_runner/versions
- https://pub.dev/packages/drift_dev/versions
- https://pub.dev/documentation/powersync/latest/sqlite_async/SqliteConnection-class.html

## Phase 6 — End-to-end two-user and offline safety tests

Only after the encrypted local integration tests pass should the backend experiment continue. Use two disposable local Supabase Auth users; never use personal or production identities.

1. Require an owner_id column for synced app rows. Configure the sample's Sync Stream to filter by authenticated user UUID, not email and not an unfiltered catch-all stream.
2. Test that user A never receives user B rows and vice versa.
3. Test that RLS rejects forged owner_id values for insert and update, not merely hides rows in select queries.
4. Test the actual Sync Stream boundary as well as RLS, because the PowerSync replication role can have broader database read privileges.
5. Write offline, kill/restart the client, reconnect, then verify idempotent upload and convergence.
6. Retry a failed upload and verify the transaction is not marked complete before server acceptance. Handle permanent authorization/schema failures visibly; don't silently discard data.
7. Switch from user A to user B while A has pending writes. Verify A's queue cannot be sent with B's JWT and B cannot view A's local data.
8. Test deletion tombstones, delayed old writes and account-deletion behavior so offline updates cannot resurrect deleted rows.
9. Test Guest adoption and cancel when the cloud account is empty and when it already has data. Cancel must sign out the pending account and expose/sync no local Guest data.
10. Test sign-out preserving the local encrypted database and queue. Test local wipe separately with crash injection between each stage, verifying that the recovery marker is processed before any workspace opens and that local wipe never deletes cloud data.

Use pgTAP and supabase test db for database authorization checks. Do not declare the ADR accepted until the test reports/logs and the exact package lockfile are attached.

## Phase 7 — Android verification and evidence collection

Before any database-backed test or build, verify that the same PowerShell session still contains the key generated in Phase 5. Do not print the key:

    if ([string]::IsNullOrWhiteSpace($env:POC_DB_KEY)) { throw 'POC_DB_KEY is missing in this PowerShell session. Return to the session that created it, or use a new database path and new scratch key; do not regenerate a key for an existing encrypted database.' }
    "PoC key present; length only: $($env:POC_DB_KEY.Length)"

For each meaningful change in the scratch client. `flutter analyze` does not execute the database and does not require the define. Tests and both APK builds must receive the define because the scratch harness reads it using `String.fromEnvironment('POC_DB_KEY')`:

    flutter analyze
    flutter test "--dart-define=POC_DB_KEY=$env:POC_DB_KEY"
    flutter build apk --debug "--dart-define=POC_DB_KEY=$env:POC_DB_KEY"
    flutter build apk --release "--dart-define=POC_DB_KEY=$env:POC_DB_KEY"

Save outputs and logs in the scratch folder. Verify that both debug and release artifacts open the encrypted file, wrong-key attempts fail, correct-key reopen works and no plaintext database is created unexpectedly. Run the full root-app tests only if there has been a separate approved app change; the Run A PoC itself should not touch the app repo.

Create a report, for example:

    New-Item -ItemType Directory -Force -Path (Join-Path $PocRoot 'evidence') | Out-Null
    flutter --version | Out-File -Encoding utf8 (Join-Path $PocRoot 'evidence\tool-versions.txt')
    docker compose --file (Join-Path $ReferenceRoot 'docker\compose.yaml') --env-file (Join-Path $ReferenceRoot '.env.local') ps | Out-File -Encoding utf8 (Join-Path $PocRoot 'evidence\docker-ps.txt')

Also record:
- starter git SHA, all resolved package versions and Flutter/Dart/Android SDK versions;
- encryption mode and key handling (never the actual key);
- database reopen and wrong-key result;
- test list/results for Drift, offline replay, retries, two-user isolation and account lifecycle;
- device/emulator and Android debug/release results;
- unresolved errors, reproduction commands and log excerpts with secrets removed.

Keep this PowerShell session open while these commands run. If you open a second window only for Docker log monitoring, reinitialize the path variables from the existing folders; never assume `$env:POC_DB_KEY` transferred. If the original key-bearing session is gone and the test key was not preserved through a deliberate secure local mechanism, use a fresh disposable database path with a new random key rather than reusing the old encrypted file.

Before attaching the report to the repository, review every output for credentials, tokens, full device paths or personal data. Do not include .env.local, signing_keys.json, app_config.dart, app databases, keys or signing material.

## Stop conditions

- Any package resolution conflict: stop and document it; do not force a dependency override.
- Encryption option or Android native build failure: test the other officially documented cipher option in the disposable client before deciding PowerSync is a no-go.
- Drift only works against a separate database: record as a failed integration gate, not a successful PoC.
- Any cross-user data leakage, queue reassignment, silent cloud overwrite, unrecoverable wipe or silent data-discard behavior: immediate no-go until fixed and retested.
- No Run B or backend implementation until runtime evidence is recorded, the ADR is revised to Accepted/Rejected and the owner explicitly approves.

## Official references

- PowerSync Flutter SDK: https://pub.dev/packages/powersync
- PowerSync database API: https://pub.dev/documentation/powersync/latest/powersync/PowerSyncDatabase-class.html
- PowerSync EncryptionOptions: https://pub.dev/documentation/powersync/latest/powersync/EncryptionOptions-class.html
- PowerSync + Supabase example template: https://github.com/powersync-community/flutter-powersync-supabase
- Supabase local development and CLI: https://supabase.com/docs/guides/local-development/cli/getting-started
- Drift + sqlite_async: https://pub.dev/packages/drift_sqlite_async
- RLS testing: https://supabase.com/docs/guides/database/postgres/row-level-security
) { throw 'The expected powersync_demo container name was not found; inspect the Compose file before proceeding.' }
    $EnvTemplateText = Get-Content (Join-Path $ReferenceRoot '.env.local.template') -Raw
    if ($EnvTemplateText -notmatch '(?m)^PS_PORT=8080\s* = Join-Path $PocRoot 'qaza_poc_client'
    Copy-Item -Path (Join-Path $ReferenceRoot 'flutter_counter') -Destination $ClientRoot -Recurse

    Get-ChildItem $PocRoot
    git -C $ReferenceRoot rev-parse HEAD

Record the starter commit SHA in the experiment notes. Do not run this command against the actual Qaza Namaz repository.

## Phase 2 — Install and start local Supabase

Open a PowerShell session for the reference folder:

    Set-Location $ReferenceRoot
    npm install --save-dev supabase
    npx supabase --version

The starter already includes its Supabase directory and migrations, so do not run supabase init again. Create a local-only environment file and signing key:

    Copy-Item .env.local.template .env.local
    npx supabase gen signing-key

Open the local configuration:

    notepad .\supabase\config.toml

Find the line under the Auth section that reads:

    #signing_keys_path = "./signing_keys.json"

Uncomment it so it reads:

    signing_keys_path = "./signing_keys.json"

Save the file. Keep signing_keys.json local and never commit it.

Start the local Supabase stack:

    npx supabase start
    npx supabase status

Expected: local API/Auth/Postgres services report running. If Docker is not running, fix Docker Desktop before retrying. Do not run supabase link, db push to a hosted project, or any command that targets a remote project.

Official Windows install instructions for a global CLI are also available via Scoop; this runbook uses the project-local npm CLI so the version is recorded in the scratch package lockfile.

## Phase 3 — Start the sample PowerSync service on loopback only

The community starter includes docker/compose.yaml and docker/powersync.yaml. It uses a demo .env.local with local development values. Do not replace these with real credentials.

For a safer local-only host binding, edit the scratch file:

    notepad .\docker\compose.yaml

Change the port mapping line from the broad host mapping to:

    - "127.0.0.1:8080:8080"

The sample .env.local sets PS_PORT=8080. Keep the container's internal port at 8080. Save.

Start the service:

    docker compose --file .\docker\compose.yaml --env-file .\.env.local up -d
    docker compose --file .\docker\compose.yaml --env-file .\.env.local ps
    docker logs powersync_demo --tail 100
    Test-NetConnection 127.0.0.1 -Port 8080

Expected: the PowerSync container is running and the TCP check succeeds. If the container exits, save its logs and stop; do not change production app configuration to work around it. Keep the entire development stack local and do not expose it publicly.

The sample Supabase stack exposes its own local ports. Run it only on a trusted development machine/network and follow Supabase's current local network-security guidance.

## Phase 4 — Run the unmodified reference demo first

Continue in the same PowerShell session and use the copied client, not the official reference source. (PowerShell variables such as $ClientRoot are session-scoped.)

    Set-Location $ClientRoot
    Copy-Item .\lib\app_config_template.dart .\lib\app_config.dart
    flutter pub get
    flutter pub deps --style=compact
    flutter devices

The template already selects the Android emulator host as 10.0.2.2 for local service ports. For a physical Android phone, the emulator host address is not correct; configure a trusted LAN address and local firewall rules only if testing on a physical device.

If using an Android emulator, replace DEVICE_ID with the exact emulator ID listed by flutter devices:

    flutter run -d DEVICE_ID

Expected: the reference counter demo opens and can read/modify its counters with the local Supabase + PowerSync service running. Important: the starter's counters stream is deliberately an unfiltered demo stream, so all demo users can see the synthetic counters. Never use that stream with Qaza data; POC-5 must replace it with strict owner-filtered streams and prove cross-user isolation. Verify:
1. Add a counter while online and confirm it appears.
2. Stop the emulator's network or stop the PowerSync container, add a local counter, and confirm the UI still operates offline.
3. Force-stop and reopen the demo while disconnected and verify local changes remain.
4. Restore network/PowerSync and verify the local change eventually syncs.

This is only a backend-connectivity baseline, not proof of database encryption or Qaza account safety. Record the app logs, docker logs and exact starter SHA.

## Phase 5 — Pin packages and prepare the encrypted/Drift spike

Work only in qaza_poc_client.

Record the resolved versions before adding dependencies:

    flutter pub deps --style=compact | Out-File -Encoding utf8 .\deps-before-drift.txt
    Select-String -Path .\pubspec.lock -Pattern 'powersync:|supabase_flutter:|sqlite_async:|drift_sqlite_async:|version:'

Add the following packages to this scratch client only, using the exact versions first evaluated in the ADR:

    flutter pub add powersync:2.5.0 supabase_flutter:2.18.3
    flutter pub add drift:2.35.0 drift_sqlite_async:0.3.1 sqlite_async:0.14.6 flutter_secure_storage:10.3.4
    flutter pub add --dev build_runner:2.16.1 drift_dev:2.35.0
    flutter pub get

If dependency resolution fails, preserve the full resolver output and stop. Do not override constraints or force versions with dependency_overrides merely to obtain a green solve. Record actual resolved versions in pubspec.lock. Review the license files for direct and transitive packages and the terms for the exact PowerSync deployment edition before recommending any hosted use; record the result without assuming a feature/pricing entitlement.

Open the scratch client's pubspec.yaml and add this top-level build-hook configuration if it is absent:

    hooks:
      user_defines:
        sqlite3:
          source: sqlite3mc

This is the documented native encryption setup for PowerSync with SQLite3MultipleCiphers. Keep the hook in the scratch client manifest; do not copy it into the Qaza app during Run A.

Confirm package resolution, then check for the encryption pragma only in the disposable PoC code. Official EncryptionOptions takes a key and supports SQLite3MultipleCiphers/SQLCipher; use the documented PowerSync constructor argument rather than manually issuing PRAGMA key on a connection owned by PowerSync:
- https://pub.dev/documentation/powersync/latest/powersync/EncryptionOptions-class.html
- https://pub.dev/documentation/powersync/latest/powersync/PowerSyncDatabase-class.html

### Separate Google provider experiment

The local starter's anonymous sign-in does not test the intended Google sign-in path. Keep POC-GOOGLE separate from the email/password or local anonymous account-isolation tests. It must verify Google provider linking/sign-in through Supabase Auth, stable Supabase user UUID behavior, cancellation during pending reconciliation, and same-owner session recovery. This experiment remains NOT RUN until the owner explicitly approves creation/configuration of a throwaway OAuth client. Do not use a production OAuth client or personal user data.

### Required test harness to implement in the scratch client

### Generate an ephemeral PoC key

Use a fresh random 32-byte key encoded as unpadded Base64URL, matching the current local key format. This key is for this scratch app only. Do not print it, write it into a source file or use the Qaza app's key.

    $Rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $KeyBytes = New-Object byte[] 32
    $Rng.GetBytes($KeyBytes)
    $Rng.Dispose()
    $CorrectPocKey = [Convert]::ToBase64String($KeyBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $env:POC_DB_KEY = $CorrectPocKey
    "PoC key length (not the key): $($env:POC_DB_KEY.Length)"

Keep this PowerShell session open while testing; the environment variable will be lost in a new session. Pass it only to the scratch app launch:

    flutter run -d DEVICE_ID "--dart-define=POC_DB_KEY=$env:POC_DB_KEY"

In the Dart harness, load it with String.fromEnvironment('POC_DB_KEY') and fail closed if empty. The environment define is acceptable only for this disposable experiment, because build defines are embedded in the scratch binary; production key storage must use platform-secured storage. Within the test harness, generate a separate random wrong key in memory for the wrong-key test, and never print either key.

Do not simply point Drift at the existing Qaza database. In qaza_poc_client, build a minimal purpose-specific harness that:

1. Creates one small synced table (for example, poc_records with id, owner_id, value and updated_at) in the PowerSync Schema.
2. Opens a disposable PowerSyncDatabase at the app support directory with EncryptionOptions and a fresh 32-byte random test key. Obtain the key from a scratch-only launch define or another ephemeral test secret mechanism; never hard-code it in committed code, source control or the real app.
3. Inserts and reads a row using PowerSync's own SQL API. Closes and reopens the same path with the same key and verifies the row survives.
4. Attempts to open that file with a wrong test key and verifies that it fails to read the schema/data; then confirms the correct key can reopen the database again.
5. Uses the PowerSyncDatabase as the SqliteConnection supplied to SqliteAsyncDriftConnection and proves a Drift DAO can read/write the same table. Query watch notifications, transactions and nested transactions need specific tests.
6. Defines migrations carefully. PowerSync owns the schema for synced tables, while Drift schema verification/migrations may try to create tables that already exist. Do not accept a test that disables migrations without documenting why or that tests a separate SQLite connection/file.
7. Tests local-only tables separately and explains whether they belong in PowerSync Schema or RawTable.
8. Uses the same disposable database file for PowerSync and Drift so that writes made through either API are immediately visible through the other.

The official drift_sqlite_async package documents query CRUD, transactions, nested transactions, update propagation and optional Drift migrations, and its connection accepts a SqliteConnection. PowerSyncDatabase implements SqliteConnection. This makes the bridge plausible but not yet proven for the chosen schema/migration arrangement:
- https://pub.dev/packages/drift_sqlite_async
- https://pub.dev/documentation/powersync/latest/sqlite_async/SqliteConnection-class.html

## Phase 6 — End-to-end two-user and offline safety tests

Only after the encrypted local integration tests pass should the backend experiment continue. Use two disposable local Supabase Auth users; never use personal or production identities.

1. Require an owner_id column for synced app rows. Configure the sample's Sync Stream to filter by authenticated user UUID, not email and not an unfiltered catch-all stream.
2. Test that user A never receives user B rows and vice versa.
3. Test that RLS rejects forged owner_id values for insert and update, not merely hides rows in select queries.
4. Test the actual Sync Stream boundary as well as RLS, because the PowerSync replication role can have broader database read privileges.
5. Write offline, kill/restart the client, reconnect, then verify idempotent upload and convergence.
6. Retry a failed upload and verify the transaction is not marked complete before server acceptance. Handle permanent authorization/schema failures visibly; don't silently discard data.
7. Switch from user A to user B while A has pending writes. Verify A's queue cannot be sent with B's JWT and B cannot view A's local data.
8. Test deletion tombstones, delayed old writes and account-deletion behavior so offline updates cannot resurrect deleted rows.
9. Test Guest adoption and cancel when the cloud account is empty and when it already has data. Cancel must sign out the pending account and expose/sync no local Guest data.
10. Test sign-out preserving the local encrypted database and queue. Test local wipe separately with crash injection between each stage, verifying that the recovery marker is processed before any workspace opens and that local wipe never deletes cloud data.

Use pgTAP and supabase test db for database authorization checks. Do not declare the ADR accepted until the test reports/logs and the exact package lockfile are attached.

## Phase 7 — Android verification and evidence collection

For each meaningful change in the scratch client:

    flutter analyze
    flutter test
    flutter build apk --debug
    flutter build apk --release

Save outputs and logs in the scratch folder. Verify that both debug and release artifacts open the encrypted file, wrong-key attempts fail, correct-key reopen works and no plaintext database is created unexpectedly. Run the full root-app tests only if there has been a separate approved app change; the Run A PoC itself should not touch the app repo.

Create a report, for example:

    New-Item -ItemType Directory -Force -Path (Join-Path $PocRoot 'evidence') | Out-Null
    flutter --version | Out-File -Encoding utf8 (Join-Path $PocRoot 'evidence\tool-versions.txt')
    docker compose --file (Join-Path $ReferenceRoot 'docker\compose.yaml') --env-file (Join-Path $ReferenceRoot '.env.local') ps | Out-File -Encoding utf8 (Join-Path $PocRoot 'evidence\docker-ps.txt')

Also record:
- starter git SHA, all resolved package versions and Flutter/Dart/Android SDK versions;
- encryption mode and key handling (never the actual key);
- database reopen and wrong-key result;
- test list/results for Drift, offline replay, retries, two-user isolation and account lifecycle;
- device/emulator and Android debug/release results;
- unresolved errors, reproduction commands and log excerpts with secrets removed.

Before attaching the report to the repository, review every output for credentials, tokens, full device paths or personal data. Do not include .env.local, signing_keys.json, app_config.dart, app databases, keys or signing material.

## Stop conditions

- Any package resolution conflict: stop and document it; do not force a dependency override.
- Encryption option or Android native build failure: test the other officially documented cipher option in the disposable client before deciding PowerSync is a no-go.
- Drift only works against a separate database: record as a failed integration gate, not a successful PoC.
- Any cross-user data leakage, queue reassignment, silent cloud overwrite, unrecoverable wipe or silent data-discard behavior: immediate no-go until fixed and retested.
- No Run B or backend implementation until runtime evidence is recorded, the ADR is revised to Accepted/Rejected and the owner explicitly approves.

## Official references

- PowerSync Flutter SDK: https://pub.dev/packages/powersync
- PowerSync database API: https://pub.dev/documentation/powersync/latest/powersync/PowerSyncDatabase-class.html
- PowerSync EncryptionOptions: https://pub.dev/documentation/powersync/latest/powersync/EncryptionOptions-class.html
- PowerSync + Supabase example template: https://github.com/powersync-community/flutter-powersync-supabase
- Supabase local development and CLI: https://supabase.com/docs/guides/local-development/cli/getting-started
- Drift + sqlite_async: https://pub.dev/packages/drift_sqlite_async
- RLS testing: https://supabase.com/docs/guides/database/postgres/row-level-security
) { throw 'The expected PS_PORT=8080 setting was not found; inspect the template before proceeding.' }

    $ClientRoot = Join-Path $PocRoot 'qaza_poc_client'
    Copy-Item -Path (Join-Path $ReferenceRoot 'flutter_counter') -Destination $ClientRoot -Recurse

    Get-ChildItem $PocRoot
    git -C $ReferenceRoot rev-parse HEAD

Record the starter commit SHA in the experiment notes. Do not run this command against the actual Qaza Namaz repository.

## Phase 2 — Install and start local Supabase

Open a PowerShell session for the reference folder:

    Set-Location $ReferenceRoot
    npm install --save-dev supabase
    npx supabase --version

The starter already includes its Supabase directory and migrations, so do not run supabase init again. Create a local-only environment file and signing key:

    Copy-Item .env.local.template .env.local
    npx supabase gen signing-key

Open the local configuration:

    notepad .\supabase\config.toml

Find the line under the Auth section that reads:

    #signing_keys_path = "./signing_keys.json"

Uncomment it so it reads:

    signing_keys_path = "./signing_keys.json"

Save the file. Keep signing_keys.json local and never commit it.

Start the local Supabase stack:

    npx supabase start
    npx supabase status

Expected: local API/Auth/Postgres services report running. If Docker is not running, fix Docker Desktop before retrying. Do not run supabase link, db push to a hosted project, or any command that targets a remote project.

Official Windows install instructions for a global CLI are also available via Scoop; this runbook uses the project-local npm CLI so the version is recorded in the scratch package lockfile.

## Phase 3 — Start the sample PowerSync service on loopback only

The community starter includes docker/compose.yaml and docker/powersync.yaml. It uses a demo .env.local with local development values. Do not replace these with real credentials.

For a safer local-only host binding, edit the scratch file:

    notepad .\docker\compose.yaml

Change the port mapping line from the broad host mapping to:

    - "127.0.0.1:8080:8080"

The sample .env.local sets PS_PORT=8080. Keep the container's internal port at 8080. Save.

Start the service:

    docker compose --file .\docker\compose.yaml --env-file .\.env.local up -d
    docker compose --file .\docker\compose.yaml --env-file .\.env.local ps
    docker logs powersync_demo --tail 100
    Test-NetConnection 127.0.0.1 -Port 8080

Expected: the PowerSync container is running and the TCP check succeeds. If the container exits, save its logs and stop; do not change production app configuration to work around it. Keep the entire development stack local and do not expose it publicly.

The sample Supabase stack exposes its own local ports. Run it only on a trusted development machine/network and follow Supabase's current local network-security guidance.

## Phase 4 — Run the unmodified reference demo first

Continue in the same PowerShell session and use the copied client, not the official reference source. (PowerShell variables such as $ClientRoot are session-scoped.)

    Set-Location $ClientRoot
    Copy-Item .\lib\app_config_template.dart .\lib\app_config.dart
    flutter pub get
    flutter pub deps --style=compact
    flutter devices

The template already selects the Android emulator host as 10.0.2.2 for local service ports. For a physical Android phone, the emulator host address is not correct; configure a trusted LAN address and local firewall rules only if testing on a physical device.

If using an Android emulator, replace DEVICE_ID with the exact emulator ID listed by flutter devices:

    flutter run -d DEVICE_ID

Expected: the reference counter demo opens and can read/modify its counters with the local Supabase + PowerSync service running. Important: the starter's counters stream is deliberately an unfiltered demo stream, so all demo users can see the synthetic counters. Never use that stream with Qaza data; POC-5 must replace it with strict owner-filtered streams and prove cross-user isolation. Verify:
1. Add a counter while online and confirm it appears.
2. Stop the emulator's network or stop the PowerSync container, add a local counter, and confirm the UI still operates offline.
3. Force-stop and reopen the demo while disconnected and verify local changes remain.
4. Restore network/PowerSync and verify the local change eventually syncs.

This is only a backend-connectivity baseline, not proof of database encryption or Qaza account safety. Record the app logs, docker logs and exact starter SHA.

## Phase 5 — Pin packages and prepare the encrypted/Drift spike

Work only in qaza_poc_client.

Record the resolved versions before adding dependencies:

    flutter pub deps --style=compact | Out-File -Encoding utf8 .\deps-before-drift.txt
    Select-String -Path .\pubspec.lock -Pattern 'powersync:|supabase_flutter:|sqlite_async:|drift_sqlite_async:|version:'

Add the following packages to this scratch client only, using the exact versions first evaluated in the ADR:

    flutter pub add powersync:2.5.0 supabase_flutter:2.18.3
    flutter pub add drift:2.35.0 drift_sqlite_async:0.3.1 sqlite_async:0.14.6 flutter_secure_storage:10.3.4
    flutter pub add --dev build_runner:2.16.1 drift_dev:2.35.0
    flutter pub get

If dependency resolution fails, preserve the full resolver output and stop. Do not override constraints or force versions with dependency_overrides merely to obtain a green solve. Record actual resolved versions in pubspec.lock. Review the license files for direct and transitive packages and the terms for the exact PowerSync deployment edition before recommending any hosted use; record the result without assuming a feature/pricing entitlement.

Open the scratch client's pubspec.yaml and add this top-level build-hook configuration if it is absent:

    hooks:
      user_defines:
        sqlite3:
          source: sqlite3mc

This is the documented native encryption setup for PowerSync with SQLite3MultipleCiphers. Keep the hook in the scratch client manifest; do not copy it into the Qaza app during Run A.

Confirm package resolution, then check for the encryption pragma only in the disposable PoC code. Official EncryptionOptions takes a key and supports SQLite3MultipleCiphers/SQLCipher; use the documented PowerSync constructor argument rather than manually issuing PRAGMA key on a connection owned by PowerSync:
- https://pub.dev/documentation/powersync/latest/powersync/EncryptionOptions-class.html
- https://pub.dev/documentation/powersync/latest/powersync/PowerSyncDatabase-class.html

### Separate Google provider experiment

The local starter's anonymous sign-in does not test the intended Google sign-in path. Keep POC-GOOGLE separate from the email/password or local anonymous account-isolation tests. It must verify Google provider linking/sign-in through Supabase Auth, stable Supabase user UUID behavior, cancellation during pending reconciliation, and same-owner session recovery. This experiment remains NOT RUN until the owner explicitly approves creation/configuration of a throwaway OAuth client. Do not use a production OAuth client or personal user data.

### Required test harness to implement in the scratch client

### Generate an ephemeral PoC key

Use a fresh random 32-byte key encoded as unpadded Base64URL, matching the current local key format. This key is for this scratch app only. Do not print it, write it into a source file or use the Qaza app's key.

    $Rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $KeyBytes = New-Object byte[] 32
    $Rng.GetBytes($KeyBytes)
    $Rng.Dispose()
    $CorrectPocKey = [Convert]::ToBase64String($KeyBytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
    $env:POC_DB_KEY = $CorrectPocKey
    "PoC key length (not the key): $($env:POC_DB_KEY.Length)"

Keep this PowerShell session open while testing; the environment variable will be lost in a new session. Pass it only to the scratch app launch:

    flutter run -d DEVICE_ID "--dart-define=POC_DB_KEY=$env:POC_DB_KEY"

In the Dart harness, load it with String.fromEnvironment('POC_DB_KEY') and fail closed if empty. The environment define is acceptable only for this disposable experiment, because build defines are embedded in the scratch binary; production key storage must use platform-secured storage. Within the test harness, generate a separate random wrong key in memory for the wrong-key test, and never print either key.

Do not simply point Drift at the existing Qaza database. In qaza_poc_client, build a minimal purpose-specific harness that:

1. Creates one small synced table (for example, poc_records with id, owner_id, value and updated_at) in the PowerSync Schema.
2. Opens a disposable PowerSyncDatabase at the app support directory with EncryptionOptions and a fresh 32-byte random test key. Obtain the key from a scratch-only launch define or another ephemeral test secret mechanism; never hard-code it in committed code, source control or the real app.
3. Inserts and reads a row using PowerSync's own SQL API. Closes and reopens the same path with the same key and verifies the row survives.
4. Attempts to open that file with a wrong test key and verifies that it fails to read the schema/data; then confirms the correct key can reopen the database again.
5. Uses the PowerSyncDatabase as the SqliteConnection supplied to SqliteAsyncDriftConnection and proves a Drift DAO can read/write the same table. Query watch notifications, transactions and nested transactions need specific tests.
6. Defines migrations carefully. PowerSync owns the schema for synced tables, while Drift schema verification/migrations may try to create tables that already exist. Do not accept a test that disables migrations without documenting why or that tests a separate SQLite connection/file.
7. Tests local-only tables separately and explains whether they belong in PowerSync Schema or RawTable.
8. Uses the same disposable database file for PowerSync and Drift so that writes made through either API are immediately visible through the other.

The official drift_sqlite_async package documents query CRUD, transactions, nested transactions, update propagation and optional Drift migrations, and its connection accepts a SqliteConnection. PowerSyncDatabase implements SqliteConnection. This makes the bridge plausible but not yet proven for the chosen schema/migration arrangement:
- https://pub.dev/packages/drift_sqlite_async
- https://pub.dev/documentation/powersync/latest/sqlite_async/SqliteConnection-class.html

## Phase 6 — End-to-end two-user and offline safety tests

Only after the encrypted local integration tests pass should the backend experiment continue. Use two disposable local Supabase Auth users; never use personal or production identities.

1. Require an owner_id column for synced app rows. Configure the sample's Sync Stream to filter by authenticated user UUID, not email and not an unfiltered catch-all stream.
2. Test that user A never receives user B rows and vice versa.
3. Test that RLS rejects forged owner_id values for insert and update, not merely hides rows in select queries.
4. Test the actual Sync Stream boundary as well as RLS, because the PowerSync replication role can have broader database read privileges.
5. Write offline, kill/restart the client, reconnect, then verify idempotent upload and convergence.
6. Retry a failed upload and verify the transaction is not marked complete before server acceptance. Handle permanent authorization/schema failures visibly; don't silently discard data.
7. Switch from user A to user B while A has pending writes. Verify A's queue cannot be sent with B's JWT and B cannot view A's local data.
8. Test deletion tombstones, delayed old writes and account-deletion behavior so offline updates cannot resurrect deleted rows.
9. Test Guest adoption and cancel when the cloud account is empty and when it already has data. Cancel must sign out the pending account and expose/sync no local Guest data.
10. Test sign-out preserving the local encrypted database and queue. Test local wipe separately with crash injection between each stage, verifying that the recovery marker is processed before any workspace opens and that local wipe never deletes cloud data.

Use pgTAP and supabase test db for database authorization checks. Do not declare the ADR accepted until the test reports/logs and the exact package lockfile are attached.

## Phase 7 — Android verification and evidence collection

For each meaningful change in the scratch client:

    flutter analyze
    flutter test
    flutter build apk --debug
    flutter build apk --release

Save outputs and logs in the scratch folder. Verify that both debug and release artifacts open the encrypted file, wrong-key attempts fail, correct-key reopen works and no plaintext database is created unexpectedly. Run the full root-app tests only if there has been a separate approved app change; the Run A PoC itself should not touch the app repo.

Create a report, for example:

    New-Item -ItemType Directory -Force -Path (Join-Path $PocRoot 'evidence') | Out-Null
    flutter --version | Out-File -Encoding utf8 (Join-Path $PocRoot 'evidence\tool-versions.txt')
    docker compose --file (Join-Path $ReferenceRoot 'docker\compose.yaml') --env-file (Join-Path $ReferenceRoot '.env.local') ps | Out-File -Encoding utf8 (Join-Path $PocRoot 'evidence\docker-ps.txt')

Also record:
- starter git SHA, all resolved package versions and Flutter/Dart/Android SDK versions;
- encryption mode and key handling (never the actual key);
- database reopen and wrong-key result;
- test list/results for Drift, offline replay, retries, two-user isolation and account lifecycle;
- device/emulator and Android debug/release results;
- unresolved errors, reproduction commands and log excerpts with secrets removed.

Before attaching the report to the repository, review every output for credentials, tokens, full device paths or personal data. Do not include .env.local, signing_keys.json, app_config.dart, app databases, keys or signing material.

## Stop conditions

- Any package resolution conflict: stop and document it; do not force a dependency override.
- Encryption option or Android native build failure: test the other officially documented cipher option in the disposable client before deciding PowerSync is a no-go.
- Drift only works against a separate database: record as a failed integration gate, not a successful PoC.
- Any cross-user data leakage, queue reassignment, silent cloud overwrite, unrecoverable wipe or silent data-discard behavior: immediate no-go until fixed and retested.
- No Run B or backend implementation until runtime evidence is recorded, the ADR is revised to Accepted/Rejected and the owner explicitly approves.

## Official references

- PowerSync Flutter SDK: https://pub.dev/packages/powersync
- PowerSync database API: https://pub.dev/documentation/powersync/latest/powersync/PowerSyncDatabase-class.html
- PowerSync EncryptionOptions: https://pub.dev/documentation/powersync/latest/powersync/EncryptionOptions-class.html
- PowerSync + Supabase example template: https://github.com/powersync-community/flutter-powersync-supabase
- Supabase local development and CLI: https://supabase.com/docs/guides/local-development/cli/getting-started
- Drift + sqlite_async: https://pub.dev/packages/drift_sqlite_async
- RLS testing: https://supabase.com/docs/guides/database/postgres/row-level-security
