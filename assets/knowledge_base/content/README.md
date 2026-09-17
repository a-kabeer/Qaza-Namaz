# Knowledge Base Content Contract

This directory contains the human-editable source for bundled Knowledge Base articles.

## Source format

The published dataset uses a single UTF-8 JSON document with this top-level shape:

```json
{
  "schemaVersion": 1,
  "articles": []
}
```

The machine-readable contract is `content.schema.json`.

## Article fields

Each article must provide:

- `id`: stable kebab-case identifier; do not change it when editing an existing article.
- `slug`: stable kebab-case URL/navigation identifier.
- `category`: `masail` or `mugalat`.
- `sortOrder`: non-negative display order within the category.
- `title`: object containing non-empty `ur` and `en` strings.
- `summary`: object containing non-empty `ur` and `en` strings.
- `body`: object containing non-empty `ur` and `en` strings.
- `tags`: unique plain-text search tags.
- `references`: structured source entries with a required `source` and optional `citation`/`url`.
- `relatedArticleIds`: unique article IDs; all IDs must resolve to published articles during validation.

## Authoring rules

Content authors should edit JSON content only. Do not add article text to Dart widgets, providers, repositories, or other application code.

Keep IDs stable. Keep both Urdu and English fields populated. Use `sortOrder` for presentation order instead of relying on JSON file order.

References should identify the source clearly. URLs are optional and should only be used when a stable public URL is available.

## Data-model mapping

The application maps the JSON contract into these typed models:

`KnowledgeArticle` → article record

`KnowledgeLocalizedText` → Urdu/English text pair

`KnowledgeReference` → structured source reference

`KnowledgeCategory` → `masail` / `mugalat`

The parser and validator are responsible for converting raw JSON into these models in a later implementation part. This Part 2 change defines the contract only; it does not embed content or parsing logic.

## Compatibility

`schemaVersion` is mandatory and currently fixed at `1`. Future incompatible changes must introduce a new schema version and an explicit migration/compatibility decision rather than silently changing the meaning of existing fields.
