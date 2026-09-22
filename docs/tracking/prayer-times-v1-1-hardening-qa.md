# Prayer Times — Offline Hardening QA

Status: **Migrated to offline calculation**

This document supersedes the earlier network/API hardening checklist. Prayer calculation, city search and restriction evaluation are now local.

## Hardening scope

- IANA timezone loading and selected-location civil dates.
- DST-aware current/next prayer and countdown.
- Offline city search and nearest-city metadata.
- Manual-coordinate timezone resolution.
- Calculation-method and Asr-method mapping.
- High-latitude behavior using the selected local calculation parameters.
- Sunrise, solar-noon and sunset restriction anchors.
- Bulk Qaza completion gate during configured restrictions.
- English/Urdu and RTL UI behavior.
- No prayer-time HTTP dependency.

## Automated coverage

- Prayer calculator for Karachi.
- Standard/Hanafi Asr difference.
- Local timezone resolution.
- Solar restriction service.
- Controller state flow.
- Offline city-search provider.
- Prayer model serialization.
- Prayer widget smoke test.
- Existing schedule/DST tests.

## Manual device checks

- Location permission/service states.
- Approximate and precise location.
- Multiple countries/cities.
- Manual coordinates.
- DST and midnight boundaries.
- High latitude.
- Airplane mode with no cached prayer result.
- English/Urdu, light/dark and narrow screens.
- Restricted Qaza completion before and after the configured window.

## Cleanup requirement

Before merge, search the repository and confirm there are no active Prayer Times references to removed network providers, HTTP prayer requests, Open-Meteo city search, API-only cache states or API-specific tests.
