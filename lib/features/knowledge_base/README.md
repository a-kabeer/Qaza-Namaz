# Knowledge Base Feature

This directory is the dedicated feature boundary for the app's offline Knowledge Base.

## Scope

The module will provide bilingual reference content for:

- Masail
- Mugalat

The feature is intentionally isolated from the Qaza ledger, calculator, calendar, authentication, synchronization, and notification flows.

## Architecture boundary

Content must remain outside Flutter widgets:

`Content files → Parser/Validator → Models → Repository → Riverpod → UI`

Widgets must render data supplied by the data layer. Article text, titles, categories, references, and related-article relationships must not be embedded directly in UI code.

## Content authoring

Non-programmer content authors will work with structured content files under `assets/knowledge_base/content/`. The content format will be finalized in Part 2 and kept stable so content can be edited without changing Dart UI code.

## UI constraints

- Existing navigation structure must not be reordered, removed, or redesigned as part of this module.
- Urdu content is rendered RTL and English content LTR.
- Urdu typography will use the app's approved Noto Nastaliq font integration where appropriate.
- Existing light/dark/system theme behavior remains the source of truth.

## Offline requirement

Knowledge Base content is bundled with the application. Normal article browsing and search must not require network access.

## Current implementation status

Part 1 establishes the feature boundary and authoring/documentation structure only. Data contracts, models, parsing, repositories, state, UI, tests, and CI are implemented in later parts.
