# Knowledge Base Content Contract

This directory contains the human-editable source for the bundled Masā'il and
Mugalāṭāt content.

## Source format

The Knowledge Base ships four UTF-8 JSON files, one per supported reading
language:

- `qaza_masail_mugalat_en.json`
- `qaza_masail_mugalat_ur.json`
- `qaza_masail_mugalat_ar.json`
- `qaza_masail_mugalat_ur_Latn.json`

Each file is a JSON **array** of entries. The four files describe the same
articles and are joined on `id` at load time. Every article ID must occur in
all four files. The machine-readable contract is `content.schema.json`.

## Entry fields

Shared by all three files and required to be identical:

- `id`: stable identifier (for example `masala_001`); never change it when
  editing an existing entry.
- `type`: `masala` (a ruling) or `mugalata` (a misconception being corrected).
- `categoryId`: topic within the section, for example `sleep_forgetfulness`.
- `sortOrder`: display order within its section.
- `isPublished`: `false` keeps an entry out of the app.
- `references`: bibliographic metadata (`sourceName`, `bookName`, `author`).
  Preserve it byte for byte across all language files to keep citations traceable.

Language-specific fields use these suffixes:

- English: `titleEn`, `questionEn`, `summaryEn`, `contentEn`, `keywordsEn`
- Urdu: `titleUr`, `questionUr`, `summaryUr`, `contentUr`, `keywordsUr`
- Arabic: `titleAr`, `questionAr`, `summaryAr`, `contentAr`, `keywordsAr`
- Roman Urdu: `titleUrLatn`, `questionUrLatn`, `summaryUrLatn`, `contentUrLatn`, `keywordsUrLatn`

Search keywords should use the words a reader of that language is likely to
enter; literal word-for-word keyword translations are not required.

## Authoring and religious review

Edit JSON content only. Do not embed article prose in Dart widgets, providers,
repositories, or other application code. Keep article IDs and shared metadata
in sync across all three files.

Arabic article text is bundled for offline use. Translation drafts must retain
the meaning and qualifications of the source text and be reviewed by a
qualified Arabic-speaking Islamic reviewer before being treated as an
authoritatively reviewed religious translation. The app must not silently
substitute English or Urdu text when Arabic content is missing.

Use `sortOrder` for presentation order rather than relying on array order.
Adding an entry to only one file, changing shared metadata in only one file,
or omitting a required translated field is a load-time validation error.

## Data-model mapping

| JSON | Model |
| --- | --- |
| entry | `KnowledgeArticle` |
| `type` | `KnowledgeCategory` (`masail` / `mugalat`) |
| `categoryId` | `KnowledgeArticle.topicId` |
| title/question/summary/content with En, Ur and Ar suffixes | `KnowledgeLocalizedText` |
| `keywordsEn` / `keywordsUr` / `keywordsAr` | `KnowledgeLocalizedKeywords` |
| `references[]` | `KnowledgeReference` |

`KnowledgeBaseParser.parseQuadruple` validates and joins all four language
files. `BundledKnowledgeBaseRepository` loads the bundled files, filters
unpublished entries, orders articles by section and `sortOrder`, and answers
queries. Search only matches article text and keywords in the selected reading
language; bibliographic citations remain in their authored form for traceability.

## Compatibility

Any incompatible schema change must update all three files, the schema and
parser together. Do not silently change the meaning of an existing field.
