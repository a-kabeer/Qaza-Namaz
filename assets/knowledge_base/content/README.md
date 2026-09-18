# Knowledge Base Content Contract

This directory contains the human-editable source for the bundled Masā'il and
Mugalāṭāt content.

## Source format

The content ships as **two UTF-8 JSON files, one per language**:

- `qaza_masail_mugalat_en.json`
- `qaza_masail_mugalat_ur.json`

Each file is a JSON **array** of entries. The two files describe the same
entries: they are joined on `id` at load time, so every `id` must appear in
both. The machine-readable contract is `content.schema.json`.

## Entry fields

Shared by both files, and required to be identical in both:

- `id`: stable identifier (for example `masala_001`); never change it when
  editing an existing entry.
- `type`: `masala` (a ruling) or `mugalata` (a misconception being corrected).
  This is the section the entry appears under.
- `categoryId`: topic within the section, for example `sleep_forgetfulness`.
  New topics may be added; an unknown topic renders with a label derived from
  the id rather than failing to load.
- `sortOrder`: display order **within its `type`**. Each section numbers from
  1, so the same number appears once per section and never twice.
- `isPublished`: `false` keeps an entry in the file and out of the app.
- `references`: array of `{sourceName, bookName, author}`, all required. These
  are bibliographic, not prose, so they must match byte for byte across the two
  files.

Language-specific, suffixed by language:

- `titleEn` / `titleUr`
- `questionEn` / `questionUr`
- `summaryEn` / `summaryUr`
- `contentEn` / `contentUr`
- `keywordsEn` / `keywordsUr`: search vocabulary for that language. These are
  not translations of each other; each language gets the terms its readers
  would actually type.

## Authoring rules

Edit JSON content only. Do not put article text in Dart widgets, providers,
repositories, or any other application code.

Keep ids stable. Keep both files in step: adding an entry to one file without
the other is a load-time error, and so is changing `type`, `categoryId`,
`sortOrder`, `isPublished` or `references` in one file only. Use `sortOrder`
for presentation order rather than relying on the order of the array.

## Data-model mapping

| JSON | Model |
| --- | --- |
| entry | `KnowledgeArticle` |
| `type` | `KnowledgeCategory` (`masail` / `mugalat`) |
| `categoryId` | `KnowledgeArticle.topicId`, kept verbatim |
| `titleEn` + `titleUr` (and question/summary/content) | `KnowledgeLocalizedText` |
| `keywordsEn` + `keywordsUr` | `KnowledgeLocalizedKeywords` |
| `references[]` | `KnowledgeReference` |

`KnowledgeBaseParser` joins the two files and validates them;
`BundledKnowledgeBaseRepository` loads, filters unpublished entries, orders by
section then `sortOrder`, and answers queries. Searching and filtering go
through `KnowledgeQuery`, so the presentation layer never restates the rules.

## Compatibility

The schema is defined by the field set above. A future incompatible change
must be an explicit migration — both files and the parser together — rather
than a silent change to the meaning of an existing field.
