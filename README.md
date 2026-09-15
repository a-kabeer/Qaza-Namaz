# Qaza Namaz — Flutter Project

This repository contains the Qaza Namaz Android app and its domain workflow.

## Current architecture
Riverpod composition root, QazaService over repositories, offline-first local cache with durable sync outbox, centralized Gregorian/Hijri calendar, and shared UI components.

## Status
Task 3H and the Architecture Refactor / Cleanup / Performance Optimization pass are complete on `main`. Task 3G is intentionally frozen and preserved.

## Validation
GitHub Actions validates Flutter dependency resolution, analysis, tests, and Android release APK builds. Physical-device verification remains environment-dependent.
