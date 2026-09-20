# Prayer Times V1.1 — Hardening & QA Tracking

Status: **Implementation in progress — automated QA being verified**
Branch: `feature/prayer-times-v1-1-hardening-qa`
Started: 2026-09-21
Scope: Prayer Times V1.1 hardening only. This tracker is intentionally separate from the V1 tracker.

## Purpose

Harden the shipped Prayer Times V1 without adding V2 features. Focus on date/time correctness, global edge cases, failure handling, UI-state coverage, and a repeatable real-device QA checklist.

## Why each hardening area matters

### DST / timezone edge cases

Prayer times are tied to the selected location's civil date and timezone, not the phone's current timezone.

A bug here can make the app request yesterday/tomorrow's prayer times when the phone and selected location are on different dates, or produce an incorrect countdown around daylight-saving transitions.

Implemented:
- Full IANA timezone database loading.
- Explicit local-date conversion from an instant.
- DST countdown tests for America/New_York.
- London DST boundary date tests.
- Unknown-timezone rejection instead of silently falling back to UTC.

### High latitude coverage

At high latitudes, sunrise/sunset-related events can behave differently and some methods may require a latitude-adjustment strategy.

V1 does not expose astronomical adjustment controls, so the API request now explicitly uses AlAdhan's angle-based latitude adjustment setting and the provider tests verify that parameter.

Real-world high-latitude verification remains part of device/API QA.

### Widget / loading / error integration tests

Unit tests can prove state transitions but cannot prove that the actual Flutter screen renders those states correctly.

V1.1 adds widget coverage for:
- Skeleton loading.
- API error state with retry/manual-location actions.
- Urdu rendering.
- Dark theme rendering.
- Narrow 320dp layout smoke coverage.

### Real-device location QA

OS location behavior cannot be fully reproduced with fakes.

Manual Android QA must verify:
- Location services disabled.
- Permission denied.
- Permission permanently denied.
- Approximate location.
- Precise location.
- GPS position unavailable/slow.
- Manual city fallback.
- Manual coordinates fallback.
- Re-opening settings and retrying.

### Manual-coordinate timezone handling

Manual coordinates initially have no timezone metadata.

Before hardening, the app could use the phone's calendar date for the first request even when the selected coordinates were in another timezone.

V1.1 now:
1. Performs the initial coordinate request.
2. Reads the timezone returned by AlAdhan.
3. Calculates the selected location's actual local date.
4. Re-requests the correct local date when it differs from the first request.
5. Avoids presenting a potentially wrong cached day as today's result after correction is required.

### "Recommended" calculation-method semantics

The previous label "Recommended for your location" could imply that the app itself had a country-specific recommendation engine.

V1.1 labels this preset as **Automatic (AlAdhan)**. The API request intentionally omits an explicit method, allowing the provider to resolve its automatic/default method, and the response's resolved method name is displayed when available.

## Automated hardening checklist

- [x] Use the published timezone 0.10.1 line compatible with the existing notification plugin and load its full IANA database variant.
- [x] Add deterministic injectable clock for controller QA.
- [x] Correct manual-coordinate date after timezone discovery.
- [x] Reject invalid/missing API timezone metadata.
- [x] Add explicit AlAdhan latitude-adjustment request parameter.
- [x] Map provider timeout/network failures to app-level API errors.
- [x] Add DST and timezone tests.
- [x] Add high-latitude request tests.
- [x] Add manual-coordinate timezone correction tests.
- [x] Add location permission/service state tests.
- [x] Add loading/error widget tests.
- [x] Add Urdu + dark-theme + narrow-screen smoke test.
- [x] Clarify Automatic (AlAdhan) calculation-method wording.

## Real-device QA checklist

### Location permissions
- [ ] Location services disabled → clear explanation + location settings action.
- [ ] Permission denied → clear retry/manual fallback.
- [ ] Permission permanently denied → app settings action.
- [ ] Approximate location → prayer times still calculate and metadata remains usable.
- [ ] Precise location → coordinates and metadata resolve normally.
- [ ] Slow/unavailable GPS → understandable error, no infinite spinner.

### Manual location
- [ ] City search works for Pakistan.
- [ ] City search works for Saudi Arabia.
- [ ] City search works for UK.
- [ ] City search works for USA.
- [ ] City search works for Malaysia.
- [ ] City search works for Turkey.
- [ ] Manual coordinate entry accepts valid signed decimals.
- [ ] Invalid coordinates are rejected.
- [ ] Coordinates near an international date boundary resolve today's local date correctly.

### Prayer calculation
- [ ] Pakistan: Karachi method + Hanafi.
- [ ] Saudi Arabia: Makkah method + Standard.
- [ ] UK: MWL/appropriate method + Standard.
- [ ] USA: ISNA/appropriate method + Standard.
- [ ] Malaysia: JAKIM + Standard.
- [ ] Turkey: Turkey + Standard.
- [ ] Standard/Hanafi changes update Asr.
- [ ] Changing calculation method refreshes today's times.
- [ ] Automatic method displays the provider-resolved method name when returned.

### Offline / API behavior
- [ ] Cached day appears immediately when available.
- [ ] Background refresh indicator appears.
- [ ] API failure with cache keeps today's cached times.
- [ ] API failure without cache shows retry/manual fallback.
- [ ] Timeout shows an actionable error rather than a blank state.

### High latitude
- [ ] Tromsø / northern Norway around summer solstice.
- [ ] Tromsø / northern Norway around winter solstice.
- [ ] Verify no crash or malformed prayer-time row.
- [ ] Verify the selected calculation method remains visible.

### UI
- [ ] English.
- [ ] Urdu / RTL.
- [ ] Light theme.
- [ ] Dark theme.
- [ ] Small Android screen.
- [ ] Long city names.
- [ ] Refresh and Change Location actions.
- [ ] No visible layout overflow.

## External-service assumptions

- AlAdhan remains the prayer calculation provider.
- Open-Meteo remains the city-search provider.
- Native geocoding remains metadata enrichment only.
- Precise coordinates are not sent to analytics/Firebase by the Prayer Times module.

## Definition of done

V1.1 is done when the automated hardening suite is green, the normal repository CI is green, and the real-device checklist has been manually executed on at least one modern Android device with both English and Urdu/RTL coverage.
