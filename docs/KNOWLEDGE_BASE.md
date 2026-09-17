# Knowledge Base — Architecture & Implementation Plan

## Purpose

The Knowledge Base is an offline, bilingual reference module for the Qaza Namaz app. It contains two content categories:

- Masail
- Mugalat

The module is content-driven and must remain independent from the existing Qaza business logic and persistence flows.

## Non-negotiable requirements

1. Content must not be hardcoded inside Flutter widgets.
2. Article content must come from the data layer.
3. Content must be bundled with the application and remain usable without network access.
4. Urdu and English content must be represented explicitly so the UI can select and render the correct language direction.
5. Urdu content must render RTL; English content must render LTR.
6. Existing light/dark/system theme behavior remains unchanged.
7. Existing navigation must not be reordered, removed, or redesigned for this feature.
8. The module must not change Qaza records, calculator behavior, calendar behavior, authentication, synchronization, or notifications.
9. Content authors who do not know programming must be able to edit the structured content files without changing Dart UI code.

## Target architecture

`assets/knowledge_base/content/* → parser/validator → domain models → repository → Riverpod providers → feature UI`

### Content layer

Human-editable structured files under `assets/knowledge_base/content/` are the single source for published article content. The format will be versioned and documented before the dataset is added.

### Parser and validation layer

The parser will convert bundled source files into strongly typed models and reject malformed content deterministically. Validation will cover IDs, categories, bilingual fields, references, and relationship integrity.

### Domain model layer

The domain model will represent articles without coupling the UI to the storage format. UI code will consume typed models rather than raw JSON maps.

### Repository layer

The repository will expose read-only Knowledge Base operations such as listing articles, filtering by category, searching, loading a single article, and resolving related articles. It will not depend on Firestore or the Qaza database.

### State layer

Riverpod providers will own loading, filtering, searching, and selected-article state. Providers will not contain article content.

### UI layer

The feature will provide article browsing, category filtering, search, article detail, references, and related-article navigation. UI widgets will be reusable and data-driven.

## Content author workflow

The content author only needs to edit the structured content files. A typical workflow will be:

1. Add or edit an article record.
2. Keep the stable article ID unchanged when editing existing content.
3. Provide Urdu and English title/body fields as required by the schema.
4. Set the category to `masail` or `mugalat`.
5. Add references and related-article IDs using the documented format.
6. Run the provided validation/test workflow before publishing.

No Flutter widget code should need to change when article wording changes.

## Planned implementation parts

### Part 1 — Module Foundation

Status: COMPLETE

Established the dedicated feature boundary, offline content-authoring location, and architecture guardrails. No production UI or business behavior was changed.

### Part 2 — Data Contract & Models

Status: PENDING

Define the versioned structured content schema, validation rules, and strongly typed domain models.

### Part 3 — Content Dataset Foundation

Status: PENDING

Add initial valid Masail/Mugalat content files using the approved schema and reference structure.

### Part 4 — Parser & Validator

Status: PENDING

Implement parsing, schema validation, relationship validation, and deterministic error handling.

### Part 5 — Repository & Data Layer

Status: PENDING

Implement a read-only repository over bundled content with efficient indexed access.

### Part 6 — Riverpod State Layer

Status: PENDING

Add providers for loading, categories, search, filters, article selection, and related content.

### Part 7 — Article List & Search UI

Status: PENDING

Implement data-driven article listing, category filtering, search, loading, empty, and error states.

### Part 8 — Article Detail & References UI

Status: PENDING

Implement bilingual article detail, references, related articles, RTL/LTR direction handling, and approved Urdu typography.

### Part 9 — Integration & Regression Protection

Status: PENDING

Integrate the feature without changing existing navigation order/design and verify that existing Qaza workflows remain unaffected.

### Part 10 — Performance & Accessibility

Status: PENDING

Audit large datasets, lazy rendering, search efficiency, rebuild scope, semantics, text scaling, RTL behavior, and theme contrast.

### Part 11 — Content QA & Tests

Status: PENDING

Add parser, repository, provider, widget, localization-direction, relationship, and regression tests. Validate representative and edge-case datasets.

### Part 12 — Documentation & Release Readiness

Status: PENDING

Finalize authoring documentation, update project status, review generated assets/packaging, and prepare the final PR state.

### Part 13 — Full CI

Status: PENDING

Run the complete GitHub CI/build/test matrix only after Parts 1–12 are complete. Fix CI-discovered regressions before marking the Knowledge Base task complete.

## Current Part 1 decision record

Part 1 intentionally does not add article content, a Dart parser, Riverpod providers, UI screens, or navigation changes. Keeping those concerns separate prevents the initial foundation commit from becoming coupled to an unfinished content schema.
