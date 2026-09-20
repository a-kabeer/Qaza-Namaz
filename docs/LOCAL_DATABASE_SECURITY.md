# Local database security

The Qaza-Namaz local ledger is stored in SQLite through Drift and is encrypted
using SQLite3MultipleCiphers.

## Key handling

A random 256-bit key is generated once and stored with flutter_secure_storage.
The database key is not stored in SharedPreferences, the SQLite file, the sync
outbox, logs, or application exports.

## Database opening

The database is opened only through an encrypted NativeDatabase. The
application verifies that the bundled SQLite build exposes the cipher pragma,
then applies the key before Drift is allowed to issue queries.

## Existing installations

A pre-existing plaintext qaza_namaz.sqlite is migrated before Drift opens it:
the plaintext database is copied with SQLite VACUUM INTO, the temporary copy is
re-keyed, the encrypted copy is validated, and only then is the original file
replaced. A temporary recovery backup is used during the rename.

This preserves the existing Drift schema and does not discard Qaza records.

## Backup and restore

Android backup rules require client-side encryption for the local database and
exclude SharedPreferences. Device-to-device transfer excludes the local
database. Because the encryption key is device-secured, account sync or
explicit import/export remains the recovery path for a new device rather than
transferring the local encryption key.

## Sync outbox diagnostics

Durable outbox rows store only short error categories such as
firebase:permission-denied, network, timeout, permission, or unknown. Raw
exception strings are not persisted. This reduces the amount of diagnostic
information retained in the local ledger.

## Security boundary

Database encryption protects data at rest if the database file is copied. It
does not replace Android device security, app lock, account authorization,
Firestore rules, or App Check.
