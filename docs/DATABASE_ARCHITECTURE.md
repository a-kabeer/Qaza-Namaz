# Qaza Namaz — Database Architecture

## Current production architecture

The production Qaza persistence path is:

`UI → Riverpod Provider/Controller → QazaService → QazaRepository → Drift/SQLite DAO`

Drift/SQLite is the local runtime source of truth for Qaza records and the sync outbox. Firebase/Firestore remains the cloud synchronization boundary where applicable; it is not the production local ledger store.

## Local Qaza schema

Qaza records contain:

- `userId`
- `prayerType`
- `originalDate`
- `status`
- `completedAt` (nullable)
- `createdAt`
- `updatedAt`

The stable record identity is based on user + normalized calendar date + prayer, preventing duplicate Qaza creation across repeated requests and offline retries.

## Query architecture

Production screens use bounded database operations:

- keyset-paginated Qaza pages
- filtered/paginated history
- direct oldest-pending lookup
- database-backed progress aggregation
- bounded date/prayer availability queries

The UI must not materialize the complete ledger for summary, pagination, history, completion, or availability rendering.

## Legacy compatibility boundary

The repository retains a full-ledger compatibility API where required by migration/data-transfer compatibility. It is not the production source for the large-data UI paths audited in Tasks 7–8.

SharedPreferences is retained only as a one-time migration source for existing installations. It is not a runtime Qaza persistence layer.

## Integrity

- Adds are idempotent by user/date/prayer identity.
- Pending and completed records remain protected from duplicate creation.
- Completion is forward-only from pending to completed.
- User scoping is enforced at repository/DAO boundaries.
- Mutations are transaction-safe where multiple local tables must change together.

## Scalability rules

Database filtering, aggregation, and pagination are preferred over Dart-side full-ledger iteration. New production features must follow the same repository/DAO boundary and must not introduce a second persistence architecture.
