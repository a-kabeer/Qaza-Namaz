# Qaza Namaz — Task 1 Flutter Project

Task 1 implements the core product/domain workflow for a Qaza Namaz ledger.

## Included
- Exactly six independent prayer types: Fajr, Zuhr, Asr, Maghrib, Isha, Witr.
- Individual date-based Qaza records.
- Pending/completed state.
- Completion date/time while preserving the original Qaza date.
- Prayer-wise bulk completion.
- Pending counts calculated from records.
- Duplicate protection in the in-memory repository.
- Basic history/progress calculations.
- Minimal placeholder UI only. Replace visual UI with Google Stitch output.

## Intentionally not included
Task 2 Firebase Authentication + Firestore cloud persistence is not implemented here.

## Run
Install Flutter, then from this folder:

```bash
flutter pub get
flutter test
flutter run
```

The project is structured so Firebase/Firestore can be added later behind the repository layer without changing the core Qaza business rules.
