# Qaza Namaz — Database Architecture

## Task 4 scope

This document records the audited database design and the hardening decisions made for Task 4. The existing Firestore/offline architecture is preserved unless a concrete weakness requires a change.

## Firestore schema — current

Records are stored under:

`users/{uid}/qazaRecords/{recordId}`

Each Qaza record contains:

- `userId`
- `prayerType`
- `originalDate`
- `status`
- `completedAt` (nullable)
- `createdAt`
- `updatedAt`

Individual `QazaRecord` objects are the source of truth. Aggregate prayer counters are derived from records and are not stored as the primary data model.

The stable record ID is:

`{userId}_{prayerType}_{YYYY-MM-DD}`

This makes a user's prayer/date combination deterministic and prevents duplicate Qaza creation across repeated requests and offline retries.

## Integrity and completion rules

Adds are idempotent: an existing document ID is not overwritten by a duplicate add.

Completion is forward-only: `pending -> completed`. A completed record is not completed again, and its original Qaza date remains unchanged while `completedAt` records completion time.

Firestore ownership is enforced by the existing UID-scoped rules; protected user data requires authentication and the authenticated UID must match the `{uid}` path.

## Queries and indexing

The current repository queries one user's `qazaRecords` subcollection and optionally filters by `prayerType` and/or `status`, then sorts the returned records in application code by `originalDate`.

No checked-in composite Firestore index is currently required by these query shapes. If future server-side ordering/filter combinations introduce an index requirement, add the explicit index only with the corresponding query change.

## Local storage migration — separate strategy

Local offline data remains in the existing SharedPreferences JSON document:

`qaza_offline_cache_v1`

The payload now carries an explicit:

`schemaVersion: 1`

Backward compatibility is preserved: an older v1 payload without the field is interpreted as schema version 1. Future local schema changes must use an explicit migration path and must preserve records, pending outbox operations, and last-sync metadata.

Unsupported local schema versions are rejected rather than silently reset, preventing an incompatible future format from being mistaken for an empty cache.

This local migration strategy is independent from Firestore schema evolution.

## Future Firestore schema evolution — separate strategy

Firestore changes must be handled independently of the local cache format. Prefer additive, backward-compatible fields and tolerant reads first. Breaking changes require an explicit migration plan, compatibility window, and tests before removing old fields or changing their meaning.

A future Firestore migration must not rely on the local `schemaVersion`, and changing the local cache format must not imply a Firestore migration.

## Deletion and scalability

Task 4 introduces no destructive deletion behavior. Local-cache deletion and cloud/account deletion remain separate concerns in the existing application architecture.

The nested per-user collection scales naturally with individual Qaza records. The current sync layer reads the user's collection and merges individual records; this remains appropriate for the current product scope. Large-ledger pagination or incremental sync would be a separate optimization if actual usage demonstrates the need.
