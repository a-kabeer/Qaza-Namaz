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
7. Existing primary navigation must not be reordered, removed, or redesigned for this feature.
8. The module must not change Qaza records, calculator behavior, calendar behavior, authentication, synchronization, or notifications.
9. Content authors who do not know programming must be able to edit the structured content files without changing Dart UI code.

## Target architecture

`assets/knowledge_base/content/* → parser/validator → domain models → repository → Riverpod providers → feature UI`

### Content layer

Human-editable structured files under `assets/knowledge_base/content/` are the single source for published article content. The format is versioned by `schemaVersion` and documented in the content README and `content.schema.json`.

### Parser and validation layer

The parser converts bundled source files into strongly typed models and rejects malformed content deterministically. Validation covers IDs, categories, bilingual fields, references, and relationship integrity.

### Domain model layer

The domain model represents articles without coupling the UI to the storage format. UI code will consume typed models rather than raw JSON maps.

### Repository layer

The repository exposes read-only Knowledge Base operations such as listing articles, filtering by category, and loading a single article by stable ID. It owns the bundled asset boundary, deterministic ordering, and in-memory caching. It does not depend on Firestore or the Qaza database.

### State layer

Riverpod providers own loading, filtering, searching, selected-article state, and related-content resolution. Providers do not contain article content.

### UI layer

The feature provides article browsing, category filtering, search, article detail, references, and related-article navigation. UI widgets are reusable and data-driven.

## Content author workflow

The content author only needs to edit the structured content files. A typical workflow will be:

1. Add or edit an article record.
2. Keep the stable article ID unchanged when editing an existing article.
3. Provide Urdu and English title, summary, and body fields.
4. Set the category to `masail` or `mugalat`.
5. Add references and related-article IDs using the documented format.
6. Run the provided validation/test workflow before publishing.

No Flutter widget code should need to change when article wording changes.

## Part 2 — Data Contract & Models

### Schema version

The first content contract is `schemaVersion: 1`. The top-level document contains an `articles` array. The machine-readable contract is stored at `assets/knowledge_base/content/content.schema.json`.

### Article contract

Every article contains:

- `id` — stable kebab-case identifier.
- `slug` — stable kebab-case navigation identifier.
- `category` — `masail` or `mugalat`.
- `sortOrder` — non-negative integer for deterministic presentation order.
- `title` — required Urdu + English text pair.
- `summary` — required Urdu + English text pair.
- `body` — required Urdu + English text pair.
- `tags` — unique search tags.
- `references` — structured source records.
- `relatedArticleIds` — unique IDs resolved during later relationship validation.

### Domain models added

The application now has typed models for:

- `KnowledgeCategory`
- `KnowledgeLocalizedText`
- `KnowledgeReference`
- `KnowledgeArticle`

The models intentionally do not parse JSON. Raw-content parsing and validation remain a separate concern.

## Planned implementation parts

### Part 1 — Module Foundation

Status: COMPLETE

Established the dedicated feature boundary, offline content-authoring location, and architecture guardrails. No production UI or business behavior was changed.

### Part 2 — Data Contract & Models

Status: COMPLETE

Defined schema version 1, machine-readable JSON contract, bilingual text contract, category contract, structured references, relationship fields, stable IDs, deterministic sort order, and strongly typed domain models.

### Part 3 — Content Dataset Foundation

Status: COMPLETE

Added the bundled `assets/knowledge_base/content/articles.json` entry point with an initially empty, valid version-1 dataset. Religious article wording is intentionally left for the verified content author rather than being invented in the implementation.

### Part 4 — Parser & Validator

Status: COMPLETE

Implemented deterministic JSON parsing and validation for schema version, article structure, bilingual fields, categories, IDs/slugs, ordering, tags, references, and relationship fields. Added focused parser tests.

### Part 5 — Repository & Data Layer

Status: COMPLETE

Implemented a read-only repository contract and bundled-content repository. The repository loads the packaged dataset through Flutter assets, parses it through the dedicated parser, applies deterministic ordering, caches the parsed dataset in memory, and exposes category and stable-ID lookups without coupling to Firestore or Qaza persistence.

### Part 6 — Riverpod State Layer

Status: COMPLETE

Added providers for repository access, article loading, categories, search, category filters, selected article, and related articles. Added bilingual search across article metadata and content fields, with focused Riverpod coverage.

### Part 7 — Article List & Search UI

Status: COMPLETE

Implemented the data-driven article list, All/Masail/Mugalat category filters, bilingual search, clear action, loading/empty/error/retry states, and theme-aware article cards. Article content remains sourced from the data layer.

### Part 8 — Article Detail & References UI

Status: COMPLETE

Implemented the real article detail page with English/Urdu switching, explicit LTR/RTL direction, title/summary/body rendering, structured references, related-article navigation, missing/loading/error states, and focused widget coverage. Existing theme architecture remains the source of truth.

### Part 9 — Integration & Regression Protection

Status: COMPLETE

Integrated the Knowledge Base into the existing Settings → Prayer area without changing the primary bottom-navigation structure. Added a regression contract covering the existing Dashboard, Calculator, Logs, Settings navigation order and kept the feature isolated from Qaza data and business-state providers.

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

## Part 5 decision record

The repository is deliberately read-only because the Knowledge Base is bundled reference content, not user-generated Qaza data. Runtime access is isolated behind a repository contract so the Riverpod and UI layers do not know where content is stored. The bundled dataset is cached after the first load to avoid repeated asset parsing, while callers receive unmodifiable collections.
