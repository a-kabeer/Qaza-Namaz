# Qaza-Namaz — Master Project Status

> **Fresh tracker generated from the Complete Project Improvement & Hardening Plan shared on 2026-09-20.**
>
> **Important:** This file intentionally does **not** inherit status values from any previous `PROJECT_STATUS.md`, V2 tracker, or point-in-time task status document. Previous documents are not used as the source of truth for the status below.
>
> Updated: **2026-09-20**
> Baseline: `main` at `99f8c29762764d8ae05307bebc5fc01885525212`
> Current working branch: `hardening/security-release-baseline-20260920`
> Current branch head: `5ef351b64293cb1bafbabccbd98e785f88121aed`
> Current PR: **#45 — security: harden production release baseline**

## 1. Status rules

A task is **Complete** only when it satisfies the plan's Definition of Done:

```
Implementation
    ↓
Unit/widget tests
    ↓
Regression tests
    ↓
Analyze
    ↓
CI
    ↓
Device QA where required
    ↓
UX review
    ↓
Documentation
    ↓
Merge
```

Status meanings:

- **Complete** — all required gates satisfied.
- **Implemented** — implementation exists, but one or more completion gates remain.
- **In Progress** — actively being worked on.
- **Not started** — no work has been counted for this fresh plan.
- **Blocked** — cannot complete until an external prerequisite or failing gate is resolved.
- **Deferred** — intentionally excluded from the current implementation scope.
- **Preserved baseline** — existing architecture is retained; this is not counted as completion of the improvement task.

## 2. Fresh scope and guardrails

The master plan requires the existing strengths to be preserved unless a specific defect requires redesign:

- Drift / SQLite database
- Offline-first repository
- Sync outbox
- Sync engine
- Guest migration
- Qaza availability service
- Calculator state architecture
- Determinate bulk insertion
- Keyset pagination
- Skeleton / shimmer system
- Knowledge Base parser
- Existing accessibility foundation

Global implementation rules:

- Offline-first behavior must remain intact.
- User data must never be silently deleted.
- Destructive actions require explicit confirmation.
- Large operations require determinate progress.
- User-facing technical failures must use plain-language messages.
- New user-facing strings must be localized.
- Gregorian dates remain authoritative; Hijri is secondary.
- New UI must support light/dark/RTL/accessibility.
- Changes require regression coverage.
- Production builds must be validated, not only debug builds.

**Home scope:** the Home page is explicitly treated as an accepted baseline for this execution stream. No Home UI redesign is to be introduced unless separately requested.

---

# 3. Master plan tracker

## Phase 0 — Baseline & Audit Lock

| Task | Status | Tests | CI | Device QA | Notes |
|---|---|---|---|---|---|
| Freeze current main baseline | **Complete** | — | — | — | Baseline SHA recorded |
| Record Flutter / Dart / Android toolchain | **In Progress** | — | — | — | Remaining baseline documentation |
| Record package + Firebase configuration | **In Progress** | — | — | — | Configuration inventory still to be finalized |
| Record test counts + CI state | **In Progress** | Current CI snapshot recorded | **Mixed** | — | Linux/Windows currently failing |
| Establish canonical project status | **Complete** | — | — | — | This file is the fresh tracker |
| Archive obsolete status documents | **Not started** | — | — | — | Separate documentation task |
| Document physical-device limitations | **In Progress** | — | — | **Required** | Release/App Check/notification/auth/backup QA needs physical Android |
| Phase 0 exit criteria | **Blocked** | — | **Blocked by Linux/Windows failures** | — | Cannot claim complete yet |

## Phase 1 — Production Security & Release Hardening (P0)

| Task | Status | Tests | CI | Device QA | Notes |
|---|---|---|---|---|---|
| 4.1 Firestore rules hardening | **Implemented** | Positive + negative smoke tests added | **Passed** | — | Ownership, schema, immutable fields, status, prayer, timestamps, sync generation/change state |
| 4.2 Firebase App Check | **Implemented** | Startup activation added | **Passed in Analyze** | **Required** | Play Integrity registration/enforcement still external |
| 4.3 Production release signing | **Implemented** | Release-policy assertion added | **AAB skipped** | Required for release smoke test | Production keystore / GitHub secrets still required |
| 4.4 Android target / SDK verification | **Implemented** | CI assertion added | **Passed in Android job** | — | API 36 compile/target policy |
| 4.5 Android backup / privacy hardening | **Implemented** | Configuration/build validation pending | **Android job passed** | **Required** | Fresh-install + restore/device-transfer verification required |
| Phase 1 completion gate | **Blocked** | Security suite exists | **Blocked by Linux/Windows; release AAB skipped** | **Required** | Cannot claim P0 complete yet |

## Phase 2 — Privacy & Account Safety (P0/P1)

| Task | Status | Tests | CI | Device QA | Notes |
|---|---|---|---|---|---|
| 5.1 Local database encryption / key protection | **Not started** | — | — | Required | Android Keystore / secure key design |
| 5.1 Sensitive diagnostics / outbox error review | **Not started** | — | — | — | Minimize sensitive persistence |
| 5.2 App Lock | **Not started** | — | — | Required | Device authentication, timeout, resume, locked-data visibility |
| 5.3 Account / data transparency | **Not started** | — | — | Required | Local vs cloud, sync state, export, delete cloud data, sign out |
| 5.3 Cloud-delete confirmation | **Not started** | — | — | Required | Explicit destructive confirmation |

## Phase 3 — Navigation & Information Architecture (P1)

| Task | Status | Tests | CI | Device QA | Notes |
|---|---|---|---|---|---|
| Primary navigation: Home / Qaza / Knowledge / Settings | **Not started** | — | — | Required | Must be freshly verified against this plan |
| Calculator contextual access | **Not started** | — | — | Recommended | Home + Qaza entry points |
| Preserve tab/workspace state | **Not started** | — | — | Required | Scroll/state retention |
| Prevent duplicate workspace routes | **Not started** | — | — | Required | Navigation stack behavior |
| Android Back | **Not started** | — | — | Required | Physical / system back |
| Gesture Back | **Not started** | — | — | Required | Edge-swipe navigation |
| Predictive Back | **Not started** | — | — | Required | Supported Android versions |
| Nested-flow Back | **Not started** | — | — | Required | Add Qaza / Calculator / settings subflows |

## Phase 4 — Home Experience (P1)

| Task | Status | Tests | CI | Device QA | Notes |
|---|---|---|---|---|---|
| Today's progress | **Deferred** | — | — | — | Home is explicitly accepted and protected from redesign |
| Next Qaza | **Deferred** | — | — | — | Home UI changes intentionally excluded |
| Qaza plan / completion estimate | **Deferred** | — | — | — | Home UI changes intentionally excluded |
| Home progress persistence / states | **Deferred** | — | — | — | Revisit only by explicit request |

## Phase 5 — Qaza Tracker UX (P1)

| Task | Status | Tests | CI | Device QA | Notes |
|---|---|---|---|---|---|
| Mark complete | **Not started** | — | — | Required | Fresh end-to-end verification |
| Edit original date | **Not started** | — | — | Required | Must preserve identity/duplicate rules |
| Edit prayer type | **Not started** | — | — | Required | Must prevent invalid duplicates |
| Delete record | **Not started** | — | — | Required | Explicit confirmation |
| Offline edit/delete | **Not started** | — | — | Required | Outbox + reconciliation |
| Conflict-safe edit/delete | **Not started** | — | — | Required | Multi-device behavior |
| Undo single completion | **Not started** | — | — | Required | Reversible completion window |
| Undo bulk completion | **Not started** | — | — | Required | Safe bulk reversal |
| Select all visible | **Not started** | — | — | Recommended | Bounded selection |
| Select all matching | **Not started** | — | — | Required | Explicit confirmation for very large operations |
| Clear selection | **Not started** | — | — | Recommended | Immediate action |
| Oldest / newest sorting | **Not started** | — | — | Recommended | Deterministic: originalDate then id |
| Active-filter summary | **Not started** | — | — | Recommended | Clear filter state |
| One-tap filter reset | **Not started** | — | — | Recommended | Compact reset UX |

## Phase 6 — Add Qaza Flow (P1)

| Task | Status | Tests | CI | Device QA | Notes |
|---|---|---|---|---|---|
| Step 1 date-range inclusivity explanation | **Not started** | — | — | Required | Gregorian primary |
| Selected-date summary | **Not started** | — | — | Required | Clear date/range feedback |
| Availability visual language | **Not started** | — | — | Required | Avoid ambiguous states |
| Cross-month / cross-year selection | **Not started** | — | — | Required | Calendar acceptance test |
| Step 2 unavailable-prayer explanation | **Not started** | — | — | Required | Explain why a prayer is unavailable |
| Per-prayer available-date counts | **Not started** | — | — | Required | Partial availability must be obvious |
| Select all available | **Not started** | — | — | Required | Per-prayer availability aware |
| Clear all | **Not started** | — | — | Recommended | |
| Step 3 confirmation summary | **Not started** | — | — | Required | Existing vs new |
| Large-insert progress | **Not started** | — | — | Required | Determinate progress |
| Duplicate-submission protection | **Not started** | — | — | Required | Disable repeat submit |
| Recoverable error UX | **Not started** | — | — | Required | Retry/recovery |

## Phase 7 — Calculator UX & Trust (P1)

| Task | Status | Tests | CI | Device QA | Notes |
|---|---|---|---|---|---|
| Full user-facing localization audit | **Not started** | — | — | Required | Buttons, errors, dialogs, helper text, semantics, tooltips, validation |
| “How was this calculated?” | **Not started** | — | — | Required | Transparent result explanation |
| Calculation details | **Not started** | — | — | Required | DOB, Baligh, prayer start, period, days, prayer count, Witr, totals, existing/new |
| Methodology page | **Not started** | — | — | Recommended | Boundaries, assumptions, Witr, duplicates, jurisprudential differences |
| Result-card readability | **Not started** | — | — | Recommended | Clear hierarchy |
| Preflight explanation | **Not started** | — | — | Required | Explain before bulk insertion |
| Empty / zero-result state | **Not started** | — | — | Recommended | Clear no-op behavior |
| Cancel-safe bulk flow | **Not started** | — | — | Required | No partial silent loss |
| Retry behavior | **Not started** | — | — | Required | Recoverable failures |
| Determinate progress state | **Not started** | — | — | Required | Persistent while insertion runs |

## Phase 8 — Notification Rework & Device QA (P1)

| Task | Status | Tests | CI | Device QA | Notes |
|---|---|---|---|---|---|
| Reminder settings UX | **Not started** | — | — | Required | On/off, time, only-when-pending, repeat |
| Test notification action | **Not started** | — | — | Required | User-visible confirmation |
| Notification content | **Not started** | — | — | Required | Pending count + Open Qaza |
| Android 13 QA | **Not started** | — | — | Required | |
| Android 14 QA | **Not started** | — | — | Required | |
| Android 15 QA | **Not started** | — | — | Required | |
| Android 16 QA | **Not started** | — | — | Required | |
| Pixel QA | **Not started** | — | — | Required | |
| Samsung QA | **Not started** | — | — | Required | |
| Permission denied / later granted | **Not started** | — | — | Required | |
| Channel blocked / app notifications disabled | **Not started** | — | — | Required | |
| Reboot / battery saver / Doze | **Not started** | — | — | Required | |
| Timezone change | **Not started** | — | — | Required | |
| Notification tap / cold start | **Not started** | — | — | Required | |
| App update behavior | **Not started** | — | — | Required | |

## Phase 9 — Knowledge Base (P1/P2)

| Task | Status | Tests | CI | Device QA | Notes |
|---|---|---|---|---|---|
| Save / bookmark | **Not started** | — | — | Recommended | |
| Recently viewed | **Not started** | — | — | Recommended | |
| Share article | **Not started** | — | — | Recommended | |
| Copy article text | **Not started** | — | — | Recommended | |
| Source metadata | **Not started** | — | — | Recommended | |
| Last reviewed date | **Not started** | — | — | Recommended | |
| Authority / methodology indicator | **Not started** | — | — | Recommended | Must avoid presenting disputed details as universal fact |
| Search result highlighting | **Not started** | — | — | Recommended | |
| Better empty/search states | **Not started** | — | — | Recommended | |
| Content source / reference governance | **Not started** | — | — | Recommended | Source, book, reference, reviewed, last updated |

## Phase 10 — Import / Export & Backup UX (P1)

| Task | Status | Tests | CI | Device QA | Notes |
|---|---|---|---|---|---|
| Export backup summary | **Not started** | — | — | Required | Record count + format |
| Import: select file | **Not started** | — | — | Required | |
| Import: analyze | **Not started** | — | — | Required | |
| Import: preview | **Not started** | — | — | Required | New / existing / completion changes |
| Import: confirm | **Not started** | — | — | Required | Explicit action |
| Import: results | **Not started** | — | — | Required | Created / updated / skipped / failed |
| Large-file progress | **Not started** | — | — | Required | |
| Duplicate handling | **Not started** | — | — | Required | |
| Invalid-file explanation | **Not started** | — | — | Required | No stack traces |
| UTF-8 / Urdu regression | **Not started** | — | — | Required | |
| Import cancellation | **Not started** | — | — | Required | |
| Partial-failure recovery | **Not started** | — | — | Required | |
| Encrypted backup design | **Not started** | — | — | Required | Future-proof backup security |

## Phase 11 — Accessibility & Localization Certification (P1)

| Task | Status | Tests | CI | Device QA | Notes |
|---|---|---|---|---|---|
| English matrix | **Not started** | — | — | Required | |
| Urdu matrix | **Not started** | — | — | Required | |
| RTL matrix | **Not started** | — | — | Required | |
| Light theme matrix | **Not started** | — | — | Required | |
| Dark theme matrix | **Not started** | — | — | Required | |
| System theme matrix | **Not started** | — | — | Required | |
| 100% text scale | **Not started** | — | — | Required | |
| 130% text scale | **Not started** | — | — | Required | |
| 150% text scale | **Not started** | — | — | Required | |
| 200% text scale | **Not started** | — | — | Required | |
| TalkBack | **Not started** | — | — | Required | |
| Keyboard navigation | **Not started** | — | — | Required | |
| Reduced motion | **Not started** | — | — | Required | |
| High contrast | **Not started** | — | — | Required | |
| Minimum 48dp touch targets | **Not started** | — | — | Required | Calendar cells included |
| Focus order / semantics review | **Not started** | — | — | Required | |
| Urdu Nastaliq rendering | **Not started** | — | — | Required | Line height / clipping |
| RTL mirroring | **Not started** | — | — | Required | |
| Localized error messages | **Not started** | — | — | Required | |

## Phase 12 — UX Error & Recovery System (P1)

| Task | Status | Tests | CI | Device QA | Notes |
|---|---|---|---|---|---|
| Plain-language error model | **Not started** | — | — | Recommended | What happened / data safe? / what next? |
| Authentication errors | **Not started** | — | — | Required | |
| Google Sign-In errors | **Not started** | — | — | Required | |
| Notification errors | **Not started** | — | — | Required | |
| Sync errors | **Not started** | — | — | Required | |
| Import errors | **Not started** | — | — | Required | |
| Export errors | **Not started** | — | — | Required | |
| Calculator errors | **Not started** | — | — | Recommended | |
| Add Qaza errors | **Not started** | — | — | Required | |
| Database/migration errors | **Not started** | — | — | Required | |
| Permission failures | **Not started** | — | — | Required | |

## Phase 13 — Production Observability (P1)

| Task | Status | Tests | CI | Device QA | Notes |
|---|---|---|---|---|---|
| Crashlytics or equivalent | **Not started** | — | — | Required | Production diagnostics |
| Crash-rate monitoring | **Not started** | — | — | — | |
| Auth failure monitoring | **Not started** | — | — | — | Non-sensitive metadata only |
| Notification initialization monitoring | **Not started** | — | — | — | |
| Notification scheduling monitoring | **Not started** | — | — | — | |
| Sync failure monitoring | **Not started** | — | — | — | |
| Import failure monitoring | **Not started** | — | — | — | |
| Migration failure monitoring | **Not started** | — | — | — | |
| Sensitive-data logging audit | **Not started** | — | — | — | Never log full Qaza history, private content, credentials, or tokens |

## Phase 14 — Automated Quality Gates

| Gate | Status | Current evidence |
|---|---|---|
| Formatting | **In Progress** | Included in Analyze workflow; final project gate depends on full CI |
| Static analysis | **Passed** | Current CI Analyze job passed |
| Unit tests | **Blocked** | Current Linux and Windows test jobs failed |
| Widget tests | **Blocked** | Part of affected test jobs |
| Accessibility tests | **Not started for final certification** | Dedicated certification matrix still pending |
| Database tests | **Blocked by CI test jobs** | Needs passing cross-platform test gate |
| Sync tests | **Blocked by CI test jobs** | Needs passing cross-platform test gate |
| Guest migration tests | **Not started for final master-plan gate** | Device + regression verification pending |
| Calculator tests | **Blocked by CI test jobs** | Needs passing final gate |
| Notification tests | **Not started for final master-plan gate** | Device validation remains |
| Linux tests | **Failed** | Current run #1444 |
| Windows tests | **Failed** | Current run #1444 |
| Android debug build | **Passed** | Current run #1444 |
| Android release AAB | **Skipped** | Production signing secrets not configured |
| Firestore security-rule tests | **Passed** | Current run #1444 |
| Release-only signing verification | **Not completed** | Requires production credentials |

## Phase 15 — Performance Certification (P1)

| Task | Status | Tests | CI | Device QA | Notes |
|---|---|---|---|---|---|
| 100-record dataset | **Not started** | — | — | Required | Fresh certification |
| 1,000-record dataset | **Not started** | — | — | Required | |
| 10,000-record dataset | **Not started** | — | — | Required | |
| 50,000-record dataset | **Not started** | — | — | Required | |
| 100,000-record dataset | **Not started** | — | — | Required | |
| Home load time | **Not started** | — | — | Required | Home itself remains unchanged |
| Qaza tracker load / scroll | **Not started** | — | — | Required | |
| Filtering / sorting | **Not started** | — | — | Required | |
| Availability analysis | **Not started** | — | — | Required | |
| Calculator preflight | **Not started** | — | — | Required | |
| Bulk add | **Not started** | — | — | Required | |
| Bulk completion | **Not started** | — | — | Required | |
| Sync batching | **Not started** | — | — | Required | |
| Restart recovery | **Not started** | — | — | Required | |
| No unnecessary full-ledger materialization | **Not started** | — | — | Required | Must be asserted by regression coverage |

## Phase 16 — UX Acceptance Journeys

| Journey | Status | Device QA | Notes |
|---|---|---|---|
| First-time user: Splash → Welcome → Google/Guest → Home | **Not started** | Required | |
| Manual Qaza: Home → Add → Dates → Prayer → Review → Add → Success | **Not started** | Required | |
| Calculator: DOB → Baligh → Prayer start → Result → Explain → Preflight → Confirm → Progress → Success | **Not started** | Required | |
| Daily completion: Home → Next Qaza → Complete → next oldest | **Not started** | Required | |
| Tracker: Filter → Select → Complete → Undo | **Not started** | Required | |
| Guest conversion: sign in → existing account → merge/use-account/keep-guest | **Not started** | Required | |
| Offline: add/complete → restart → reconnect → sync | **Not started** | Required | |
| Notification: enable → permission → schedule → test → receive → open Qaza | **Not started** | Required | |

---

# 4. Final Release Gate

The application must not be marked production-ready until every applicable item below is satisfied:

| Release requirement | Status |
|---|---|
| Firestore rules hardened | **Implemented; final release gate blocked** |
| Security tests pass | **Passed for current rules smoke gate** |
| App Check configured and enforced | **Blocked — Firebase Console + validation required** |
| Production signing works | **Blocked — production secrets required** |
| Signed release AAB builds | **Blocked — signing secrets required** |
| Target SDK verified | **Implemented / CI assertion passed** |
| Backup strategy finalized | **Implemented policy / device validation pending** |
| Notification device QA | **Not started** |
| Google Sign-In device QA | **Not started** |
| Guest migration device QA | **Not started** |
| Import/export QA | **Not started** |
| English localization certified | **Not started** |
| Urdu localization certified | **Not started** |
| RTL QA passed | **Not started** |
| Accessibility QA passed | **Not started** |
| Large-dataset QA passed | **Not started** |
| Crash reporting enabled | **Not started** |
| Privacy policy available | **Not started for this fresh master-plan gate** |
| Terms available | **Not started for this fresh master-plan gate** |
| Account/data deletion process documented | **Not started** |
| Project documentation updated | **In Progress** |
| Release checklist signed off | **Not started** |
| Full CI green | **Blocked — Linux + Windows currently fail** |

## 5. Current CI snapshot

Current workflow: **Flutter CI #1444** on `5ef351b64293cb1bafbabccbd98e785f88121aed`

| Job | Result |
|---|---|
| Firestore security rules | ✅ Passed |
| Analyze | ✅ Passed |
| Android debug and release AAB | ✅ Job passed |
| Android debug APK | ✅ Built |
| Android release AAB | ⏭️ Skipped because production signing credentials are not configured |
| Tests (Linux) | ❌ Failed |
| Tests (Windows) | ❌ Failed |
| Overall workflow | ❌ Not green |

This CI snapshot is factual for the current run and is not treated as completion of the broader master plan.

## 6. External prerequisites

1. Firebase Console: configure/register Android Play Integrity for Firebase App Check and enable enforcement only after validation.
2. GitHub Actions: configure the production keystore and required signing secrets.
3. Physical Android devices: perform App Check, authentication, guest migration, notifications, backup/restore, reboot, release-AAB, accessibility, and performance QA.
4. Resolve the current Linux and Windows CI test failures before claiming the master-plan quality gate complete.

## 7. Implementation order from the shared plan

### Sprint 1 — Security & Release Foundation

Firestore hardening → App Check → production signing → target SDK → backup rules → security tests

### Sprint 2 — Navigation & Daily UX

Qaza navigation → Next Qaza → tracker completion UX → tracker actions / undo

**Home UI remains out of scope for this stream unless explicitly requested.**

### Sprint 3 — Calculator & Add Qaza

Localization cleanup → calculation explanation → methodology → large-operation UX → Add Qaza progress

### Sprint 4 — Notifications & Privacy

Notification UX → device QA → App Lock → account transparency → privacy controls

### Sprint 5 — Knowledge & Data Management

Knowledge enhancements → import preview → export improvements → encrypted backup design

### Sprint 6 — Certification

Accessibility → RTL → large text → performance → crash reporting → integration testing → release AAB → production smoke tests

## 8. Final target architecture

```
                   QAZA-NAMAZ
                       │
        ┌──────────────┼──────────────┐
        │              │              │
      Home           Qaza         Knowledge
        │              │              │
        │              │              ├─ Search
        │              │              ├─ Masail
        │              │              ├─ Mugalat
        │              │              └─ Sources
        │              │
        ├─ Today's     ├─ Pending
        │  progress     ├─ Completed
        ├─ Next Qaza    ├─ Filters
        ├─ Qaza plan    ├─ Edit
        └─ Calculator   └─ Complete
                       │
                    Settings
                       │
          ┌────────────┼─────────────┐
          │            │             │
       Account      Privacy       Backup
       Notifications Calculation   Help/About
```

Target product qualities:

- calm
- predictable
- private
- low-friction
- readable
- accessible
- localized
- offline-first
- technically maintainable

The technical complexity should remain underneath the user experience.

## 9. Next status update rule

When a task changes, update its row only after recording the concrete evidence:

```
Implementation → Tests → CI → Device QA → UX Review → Documentation → Merge
```

No task should be promoted to **Complete** merely because it compiles or because an older project status document said it was complete.
