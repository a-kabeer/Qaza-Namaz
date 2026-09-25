# Qaza Namaz — Flutter Project

This repository contains the Qaza Namaz Android app and its domain workflow.

## Current architecture
Riverpod composition root, QazaService over repositories, local Drift/SQLite persistence, centralized Gregorian/Hijri calendar, and shared UI components.

The app is local-only. It does not use Google Sign-In, Firebase Authentication, Firestore, cloud synchronization, guest account upgrade, or account-linked backup.

## Status
The authentication/cloud stack has been removed. Existing local Qaza data continues to use the stable internal local-ledger identifier so installed users retain their existing records.

## Validation
GitHub Actions validates Flutter dependency resolution, analysis, tests, and Android debug/release builds. Physical-device verification remains environment-dependent.
