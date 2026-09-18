# Documentation index

`PROJECT_STATUS.md` in the repository root is the single canonical status
document. Everything here supports it.

## Canonical

| Document | Covers |
| --- | --- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Layering, dependency boundary, controllers, single sources of truth |
| [DATABASE_ARCHITECTURE.md](DATABASE_ARCHITECTURE.md) | Drift schema, indexes, identity and integrity guarantees |
| [OFFLINE_FIRST_ARCHITECTURE.md](OFFLINE_FIRST_ARCHITECTURE.md) | Local-first reads/writes, outbox sync, bootstrap and hydration |
| [NAVIGATION_FLOW.md](NAVIGATION_FLOW.md) | Destination set, Back behaviour, startup path |
| [QAZA_BUSINESS_LOGIC.md](QAZA_BUSINESS_LOGIC.md) | Qaza identity, eligibility and completion rules |
| [GREGORIAN_HIJRI_CALENDAR.md](GREGORIAN_HIJRI_CALENDAR.md) | Gregorian as source of truth, Hijri as derived display |
| [AUTHENTICATION_LIFECYCLE.md](AUTHENTICATION_LIFECYCLE.md) | Google sign-in, UID scoping, account switching |
| [SETTINGS_ORGANIZATION.md](SETTINGS_ORGANIZATION.md) | Settings sections and what each owns |
| [KNOWLEDGE_BASE.md](KNOWLEDGE_BASE.md) | Content pipeline, authoring format, rendering |
| [KNOWLEDGE_BASE_RELEASE_CHECKLIST.md](KNOWLEDGE_BASE_RELEASE_CHECKLIST.md) | Pre-release content checks |

## V2 working records

| Document | Covers |
| --- | --- |
| [V2_PART1_ARCHITECTURE_AUDIT.md](V2_PART1_ARCHITECTURE_AUDIT.md) | The baseline audit and defect list the V2 stream works against |
| [ADD_QAZA_3_STEP_FLOW_STATUS.md](ADD_QAZA_3_STEP_FLOW_STATUS.md) | The three-step Add Qaza flow as built |

## Archive

`archive/` holds point-in-time task and part status records from the
pre-V2 migration and reconciliation streams. They are kept for history only.
Where they disagree with the canonical documents above or with
`PROJECT_STATUS.md`, the canonical documents are correct — in particular, any
archived statement that describes SharedPreferences as production storage,
Firestore as the local source of truth, Hijri as an independent navigation
calendar, or the Dashboard as canonical is obsolete.
