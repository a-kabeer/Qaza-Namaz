# qaza_cloud_adapter

Optional Phase 2 cloud adapter for Qaza Namaz.

## Dependency direction

This package is the only cloud layer. Its dependency direction is:

qaza_cloud_adapter → qaza_namaz (Phase 1)

The root application never imports this package. Removing packages/qaza_cloud_adapter therefore removes cloud/authentication/WorkManager without changing the Phase 1 runtime.

The package consumes the existing Phase 1 LocalBackupService JSON export/import contract and does not alter that contract.

## Authentication

GoogleSignInGateway.authenticate() uses the current google_sign_in API. On Android, the supported interactive authentication path is provided through the Google Sign-In Android integration backed by Credential Manager.

Authentication is separate from Drive scope authorization. Drive authorization requests exactly:

https://www.googleapis.com/auth/drive.appdata

The adapter never requests drive.file, drive, or a Drive-wide readonly scope.

## Drive storage

Backups are stored as JSON files in Drive's appDataFolder. Each backup is immutable and receives a unique filename containing its backup_id. The latest file is selected using Drive modified time and filename ordering.

Each cloud envelope contains:

- device_id
- backup_id
- base_backup_id
- db_revision
- created_at
- the unchanged Phase 1 backup as phase1_backup

db_revision is a local logical revision. It is never used as a globally unique cloud version identifier.

## Conflict model

The sync engine treats a conflict as:

local has unsynced changes AND remote backup changed since last sync

Device IDs alone never create conflicts.

Automatic synchronization is allowed for linear local-only or remote-only progression. Divergence is returned as a CloudConflict containing local/remote timestamps, originating devices, revisions, backup IDs, and the previous sync point.

Destructive conflict resolution requires confirmed: true. The two supported explicit actions are:

- CloudConflictDecision.keepLocal: upload a new cloud version whose base_backup_id is the current remote backup.
- CloudConflictDecision.useRemote: import the current remote Phase 1 payload.

The adapter never silently overwrites unsynced local data.

## Background synchronization

CloudSyncScheduler.initializeAndSchedule() registers one periodic task with ExistingPeriodicWorkPolicy.keep and enforces Android's 15-minute minimum interval.

The worker performs non-interactive authorization only. A no-op returns success and does not cancel or replace periodic work.

Phase 1 does not initialize WorkManager, Google Sign-In, Drive, or any cloud service. A Phase 2-enabled host opts in by importing this package and calling the scheduler from a separate composition root.
