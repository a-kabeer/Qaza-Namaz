# Gregorian + Hijri Calendar — Audit

## Scope

Task 8 audits the existing Gregorian/Hijri calendar implementation without replacing its Riverpod controller, calendar picker, or `hijri` package integration.

## Verified Behavior

- Gregorian month navigation uses calendar months and handles month/year boundaries.
- Gregorian month lengths use Dart `DateTime` calendar rules, including leap years.
- Future Gregorian and Hijri dates cannot be selected.
- Single, range, and multiple selection remain supported.
- Range storage is inclusive of both endpoints and uses canonical Gregorian calendar dates.
- Hijri display/conversion uses the existing `hijri` package and its Umm al-Qura calendar data.
- Gregorian dates remain the canonical dates used by the Qaza workflow.

## Independent Umm al-Qura Reference Validation

Known reference fixtures are checked directly rather than relying only on round-trip conversion:

- 29 Dhul-Hijjah 1447 AH → 15 June 2026
- 1 Muharram 1448 AH → 16 June 2026
- 10 Muharram 1448 AH → 25 June 2026
- 1 Ramadan 1448 AH → 8 February 2027
- 29 Ramadan 1448 AH → 8 March 2027
- 1 Shawwal 1448 AH → 9 March 2027

These fixtures cover two Hijri month boundaries and the Ramadan-to-Shawwal transition. The reference dates were independently checked against Umm al-Qura calendar sources. Countries using local moon sighting may announce a different date.

## Date Integrity

Calendar dates are treated as civil dates rather than timezone instants.

The canonical storage representation is `YYYY-MM-DD`. Regression coverage explicitly verifies:

`DateTime → stored date key → DateTime`

The restored value contains the original year/month/day and does not retain a UTC offset. This prevents a calendar date from moving to the previous or next day during serialization/deserialization.

## Boundary Coverage

Regression coverage includes:

- Gregorian December → January navigation.
- Gregorian leap-day rendering for 29 February 2024.
- Inclusive ranges crossing a Gregorian year boundary.
- Hijri Ramadan → Shawwal navigation.
- Known Hijri/Gregorian boundary dates.

## Result

No calendar architecture replacement is required. The existing implementation is retained and strengthened with independent reference-date validation and explicit date serialization/deserialization coverage.
