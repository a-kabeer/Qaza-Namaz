# Qaza Business Logic — Audit

## Scope

Task 7 audits the existing Qaza service/repository behavior without replacing the current architecture.

## Verified Rules

- Exactly six prayer types are supported: Fajr, Zuhr, Asr, Maghrib, Isha, and Witr.
- Qaza dates are calendar dates, normalized to year/month/day components.
- The lower and upper bounds of a selected date range are both included.
- Duplicate Qaza records are prevented by the deterministic `{userId}_{prayerType}_{YYYY-MM-DD}` identifier.
- Pending/completed state transitions remain forward-only and idempotent.
- Oldest-pending-first completion is preserved.
- Progress is derived from individual records and cannot report a negative pending count.

## Date Boundary Finding

A real cross-device timezone weakness was identified in the Firestore representation of `originalDate`: it was stored as a `Timestamp`. A timestamp represents an instant, so a local midnight could appear as the previous or next calendar date when read in another timezone.

### Hardening

- New Firestore records now store `originalDate` as the timezone-neutral `YYYY-MM-DD` string.
- The shared `QazaDate` utility provides canonical normalization, formatting, parsing, and validation.
- Legacy records that still contain a timestamp are reconstructed from the deterministic record ID's `YYYY-MM-DD` suffix, which preserves the original intended date without relying on the device timezone.
- Completion timestamps remain `Timestamp` values because they represent real instants in time.

## Range Verification

Range expansion uses canonical date components and an inclusive `start <= date <= end` loop. Regression coverage includes month boundaries and leap day handling.

## Result

The existing Qaza business architecture remains intact. The only production hardening identified by this audit was replacing timezone-sensitive persistence for the Qaza calendar date and adding compatibility for legacy records.
