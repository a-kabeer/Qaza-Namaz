# Qaza-Namaz — Task Tracking

This directory contains the **separate tracking documents** for the Complete Project Improvement & Hardening Plan.

**Master plan:** docs/MASTER_PROJECT_IMPROVEMENT_AND_HARDENING_PLAN.md

The master plan is the specification. These tracking files are the execution records. Do not update the master plan just to record status.

**Last reconciled:** 2026-09-22 against `main` @ `505a828`, covering merged PRs up to #76.

## Definition of Done

Implementation → Unit/widget tests → Regression tests → Analyze → CI → Device QA where required → UX review → Documentation → Merge

Security-sensitive tasks additionally require positive and negative/security coverage plus production configuration verification.

## Status vocabulary

| Status | Means |
| --- | --- |
| `Merged` | On `main`, covered by tests, CI green. Nothing outstanding. |
| `Merged — Device QA Pending` | Code and automated coverage are complete. A hardware pass is still owed. |
| `Partially Implemented — Remaining Scope` | Real work landed, but named scope remains. The remainder is stated in the file. |
| `Blocked — External Configuration` | Repository work is done; something outside the repository is required. |
| `Not Started` | No implementation exists. |
| `Superseded — See PR #XX` | Replaced by later work. Kept for history. |

These three are deliberately different things and are not collapsed into one another: **automated completion** (code + tests + CI), **device QA** (a human or an instrumented run on hardware), and **external configuration** (Firebase console, store credentials).

## Tracking files

- [Firestore rules hardening](./01-firestore-hardening.md) — P0 — **Merged**
- [Firebase App Check](./02-app-check.md) — P0 — **Blocked — External Configuration**
- [Production release signing](./03-production-signing.md) — P0 — **Merged**
- [Android target / SDK verification](./04-android-sdk.md) — P0 — **Merged**
- [Android backup/privacy hardening](./05-backup-privacy.md) — P0 — **Merged — Device QA Pending**
- [Local data protection](./06-local-data-protection.md) — P0/P1 — **Merged — Device QA Pending**
- [App Lock](./07-app-lock.md) — P0/P1 — **Merged — Device QA Pending**
- [Account data transparency](./08-account-data-transparency.md) — P0/P1 — **Merged**
- [Qaza navigation & information architecture](./09-qaza-navigation.md) — P1 — **Merged**
- [Home experience](./10-home-experience.md) — P1 — **Merged — Device QA Pending**
- [Qaza tracker record actions](./11-tracker-record-actions.md) — P1 — **Merged**
- [Undo completion](./12-undo-completion.md) — P1 — **Merged**
- [Tracker selection improvements](./13-selection.md) — P1 — **Merged**
- [Tracker sorting](./14-sorting.md) — P1 — **Merged**
- [Tracker filter and empty-state UX](./15-filter-empty.md) — P1 — **Merged**
- [Add Qaza flow](./16-add-qaza-flow.md) — P1 — **Merged**
- [Calculator UX & trust](./17-calculator-ux.md) — P1 — **Partially Implemented — Remaining Scope**
- [Notification rework & device QA](./18-notifications.md) — P1 — **Merged — Device QA Pending**
- [Knowledge Base improvements](./19-knowledge-base.md) — P1/P2 — **Partially Implemented — Remaining Scope**
- [Import/export & backup UX](./20-import-export.md) — P1 — **Partially Implemented — Remaining Scope**
- [Accessibility & localization certification](./21-accessibility-localization.md) — P1 — **Partially Implemented — Remaining Scope**
- [UX error & recovery system](./22-error-recovery.md) — P1 — **Merged**
- [Production observability](./23-observability.md) — P1 — **Partially Implemented — Remaining Scope**
- [Automated quality gates](./24-quality-gates.md) — P1 — **Partially Implemented — Remaining Scope**
- [Performance certification](./25-performance.md) — P1 — **Partially Implemented — Remaining Scope**
- [UX acceptance journeys](./26-ux-acceptance.md) — P1 — **Merged — Device QA Pending**
- [Final release gate](./27-final-release-gate.md) — P0 — **Blocked — External Configuration**
- [Home dynamic Qaza completion](./28-home-dynamic-qaza-completion.md) — P1 — **Superseded — See PR #71/#72/#73/#74**
- [Professional colour theme](./29-professional-color-theme.md) — P1 — **Superseded — See PR #66**

## Prayer Times

- [Global Prayer Times V1](./global-prayer-times-v1.md) — **Superseded — See PR #75**
- [Prayer Times V1 release QA](./PRAYER_TIMES_V1_RELEASE_QA.md) — **Merged — Device QA Pending**
- [Prayer Times V1.1 hardening QA](./prayer-times-v1-1-hardening-qa.md) — **Merged — Device QA Pending**

**Current architecture:** AlAdhan online as the source, with a local `adhan_dart` calculation as the fallback (PR #75). Earlier documents in this directory describe a migration to offline-only calculation (PR #68); that claim is stale and has been corrected in place. The files are kept rather than deleted, because they are the record of how the feature got here.

## What changed in this reconciliation

Statuses in this index had drifted badly from `main`. Tasks 13, 15, 16, 17, 18, 19 and 20 were all recorded as "Not started" while substantial work for each had merged. Task 09 was "In Progress — PR pending CI" after PR #60 merged. Tasks 28 and 29 were absent from the index entirely. Of those seven, three are fully merged (15, 16, 18 software), and four turned out to be partial once their checklists were read — see below.

Three tasks had no implementation at reconciliation time and have since been started:

- **Task 14 (Tracker sorting)** — **now Merged.** `QazaSortOrder` routes to the two keyset directions the DAO already ordered deterministically.
- **Task 23 (Production observability)** — **now Partially Implemented.** A vendor-neutral diagnostics port is wired at every failure site the task names, with structural redaction; only the vendor adapter remains, and it needs console configuration.
- **Task 26 (UX acceptance journeys)** — **now Merged — Device QA Pending.** All eight journeys run end to end through the real widget tree.

Four more were **demoted from Merged** once their checklists were read item by item, rather than judged by "the feature exists and has tests":

- **Task 13** — select-all-matching and size-gated confirmation are absent; selection is deliberately bounded to loaded records.
- **Task 17** — the flow is merged, but the *trust* half is not: no "How was this calculated?", no methodology page, and `_StepActions` is still hardcoded English.
- **Task 19** — zero hits in the feature for bookmark, recently-viewed, highlighting, last-reviewed, methodology and source metadata.
- **Task 20** — no encryption, no partial-failure recovery, no invalid-file explanation, no Urdu round-trip regression.

## Device QA

No task in this directory may be moved from `Merged — Device QA Pending` to `Merged` without a recorded hardware pass against a build of current `main`. Where a status says device QA is pending, no such pass has been recorded.
