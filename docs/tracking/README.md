# Qaza-Namaz — Task Tracking

This directory contains the **separate tracking documents** for the Complete Project Improvement & Hardening Plan.

**Master plan:** docs/MASTER_PROJECT_IMPROVEMENT_AND_HARDENING_PLAN.md

The master plan is the specification. These tracking files are the execution records. Do not update the master plan just to record status.

## Definition of Done

Implementation → Unit/widget tests → Regression tests → Analyze → CI → Device QA where required → UX review → Documentation → Merge

Security-sensitive tasks additionally require positive and negative/security coverage plus production configuration verification.

## Tracking files

- [Firestore rules hardening](./01-firestore-hardening.md) — P0 — **Merged**
- [Firebase App Check](./02-app-check.md) — P0 — **Merged — Firebase Console / Device QA Pending**
- [Production release signing](./03-production-signing.md) — P0 — **Merged — Production Signing Secrets Pending**
- [Android target / SDK verification](./04-android-sdk.md) — P0 — **Merged**
- [Android backup/privacy hardening](./05-backup-privacy.md) — P0 — **Merged — Device Restore QA Pending**
- [Local data protection](./06-local-data-protection.md) — P0/P1 — **Merged — Device QA Pending**
- [App Lock](./07-app-lock.md) — P0/P1 — **Implemented — Device QA Pending**
- [Account data transparency](./08-account-data-transparency.md) — P0/P1 — **In Progress — Active Task**
- [Qaza navigation & information architecture](./09-qaza-navigation.md) — P1 — **Not started**
- [Home experience](./10-home-experience.md) — P1 — **Not started**
- [Qaza tracker record actions](./11-tracker-record-actions.md) — P1 — **Not started**
- [Undo completion](./12-undo-completion.md) — P1 — **Not started**
- [Tracker selection improvements](./13-selection.md) — P1 — **Not started**
- [Tracker sorting](./14-sorting.md) — P1 — **Not started**
- [Tracker filter and empty-state UX](./15-filter-empty.md) — P1 — **Not started**
- [Add Qaza flow](./16-add-qaza-flow.md) — P1 — **Not started**
- [Calculator UX & trust](./17-calculator-ux.md) — P1 — **Not started**
- [Notification rework & device QA](./18-notifications.md) — P1 — **Not started**
- [Knowledge Base improvements](./19-knowledge-base.md) — P1/P2 — **Not started**
- [Import/export & backup UX](./20-import-export.md) — P1 — **Not started**
- [Accessibility & localization certification](./21-accessibility-localization.md) — P1 — **Not started**
- [UX error & recovery system](./22-error-recovery.md) — P1 — **Not started**
- [Production observability](./23-observability.md) — P1 — **Not started**
- [Automated quality gates](./24-quality-gates.md) — P1 — **In Progress**
- [Performance certification](./25-performance.md) — P1 — **Not started**
- [UX acceptance journeys](./26-ux-acceptance.md) — P1 — **Not started**
- [Final release gate](./27-final-release-gate.md) — P0 — **Blocked**
