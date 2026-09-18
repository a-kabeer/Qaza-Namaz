# Task 1 — Product Workflow Contract

## Six prayers
Fajr, Zuhr, Asr, Maghrib, Isha, Witr.

Witr is independent and must never be merged into Isha.

## Qaza record
Each missed prayer/date is one independent record.

Required concepts:
- userId
- prayerType
- originalDate
- status
- completedAt
- createdAt
- updatedAt

## Completion
Normal flow:
1. User chooses the prayer.
2. System finds the oldest pending original Qaza date.
3. User completes it.
4. Original Qaza date stays unchanged.
5. Completion timestamp is stored.
6. Pending count is derived from records.

Prayer-wise flow:
1. User chooses one prayer.
2. Pending original dates are displayed.
3. User may select multiple records.
4. Selected records can be completed together.

## Data integrity
- No duplicate user + prayer + original date.
- No completion of nonexistent records.
- No negative counters.
- Counters are derived, not authoritative.
