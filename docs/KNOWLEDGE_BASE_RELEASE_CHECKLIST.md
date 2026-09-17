# Knowledge Base — Release Checklist

## Content

- [ ] Replace the empty bundled dataset with verified Masail and Mugalat articles.
- [ ] Provide complete Urdu and English title, summary, and body for every article.
- [ ] Verify every reference and citation before publication.
- [ ] Verify related-article IDs after the final dataset is assembled.
- [ ] Keep stable IDs/slugs unchanged when editing published articles.

## App integration

- [x] Knowledge Base is reachable from Settings → Prayer.
- [x] Primary bottom navigation remains Dashboard, Calculator, Logs, Settings.
- [x] Knowledge Base uses bundled offline content.
- [x] Existing Qaza data, calculator, calendar, authentication, sync, and notifications remain outside the Knowledge Base data flow.

## UX & accessibility

- [x] Search and category filtering are data-driven.
- [x] Loading, empty, error, retry, and not-found states are handled.
- [x] Urdu uses RTL and English uses LTR.
- [x] Article body supports text scaling and selection.
- [x] Article actions expose semantic labels.
- [x] Existing light/dark/system theme architecture is preserved.

## Validation before release

- [ ] Run `flutter analyze`.
- [ ] Run the complete Flutter test suite.
- [ ] Build the target release artifact.
- [ ] Test the final populated dataset on a clean install and offline.
- [ ] Review the final diff for accidental changes to existing Qaza functionality.

Full GitHub CI is intentionally the final implementation step (Part 13), after this release-readiness review is complete.
