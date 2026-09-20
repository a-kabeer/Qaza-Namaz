# Prayer Times V1 — Release QA

Status: **Automated hardening implemented; real-device sign-off pending**

## Release rule

Do not mark Prayer Times V1 release-ready until every P0 and P1 case below
has a recorded result on a real Android device. Record the device model,
Android version, app build, locale, connection state, and any defect link in
the Notes column. A failed test stays open until it is retested successfully.

| ID | Area | Test | Environment | Expected result | Result | Severity | Status | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| PT-001 | Location | Use My Location, first permission request | Android device, location on | Precise/approximate position, country, city/region, coordinates and timezone resolve; times load | — | P0 | ⬜ | — |
| PT-002 | Permission | Deny location once | Android device | Clear retry and manual-location recovery are available | — | P1 | ⬜ | — |
| PT-003 | Permission | Deny location permanently | Android device | App-settings recovery action is offered; app is not stuck | — | P1 | ⬜ | — |
| PT-004 | Location | Location service disabled | Android device | Clear explanation and location-settings action are offered | — | P1 | ⬜ | — |
| PT-005 | Location | Approximate location | Android device | A usable location and schedule are shown | — | P1 | ⬜ | — |
| PT-006 | Location | Slow/unavailable GPS | Android device | Friendly error; no infinite loading state | — | P1 | ⬜ | — |
| PT-007 | Manual city | Pakistan | Android device | Search, selection, coordinates, timezone and schedule are correct | — | P0 | ⬜ | — |
| PT-008 | Manual city | Saudi Arabia | Android device | Search, selection, coordinates, timezone and schedule are correct | — | P0 | ⬜ | — |
| PT-009 | Manual city | United Kingdom | Android device | Search, selection, coordinates, timezone and schedule are correct | — | P0 | ⬜ | — |
| PT-010 | Manual city | United States | Android device | Search, selection, coordinates, timezone and schedule are correct | — | P0 | ⬜ | — |
| PT-011 | Manual city | Malaysia | Android device | Search, selection, coordinates, timezone and schedule are correct | — | P0 | ⬜ | — |
| PT-012 | Manual city | Turkey | Android device | Search, selection, coordinates, timezone and schedule are correct | — | P0 | ⬜ | — |
| PT-013 | Coordinates | Signed decimal and hemisphere values | Android device | Valid north/south/east/west coordinates resolve a timezone and schedule | — | P0 | ⬜ | — |
| PT-014 | Coordinates | Invalid and boundary values | Android device | Invalid latitude/longitude is rejected with useful guidance | — | P1 | ⬜ | — |
| PT-015 | Date/timezone | Device timezone differs from selected location | Android device | Prayer date, API date, cache date, Hijri/Gregorian date and countdown follow the selected location | — | P0 | ⬜ | — |
| PT-016 | DST | DST-observing location and transition date | Android device | Correct local civil date and current/next prayer across the transition | — | P0 | ⬜ | — |
| PT-017 | Date/timezone | Midnight and date rollover | Android device | No yesterday/tomorrow schedule is presented as today | — | P0 | ⬜ | — |
| PT-018 | Calculation | Standard Asr | Android device | Provider result matches the selected method/date/timezone | — | P0 | ⬜ | — |
| PT-019 | Calculation | Hanafi Asr | Android device | Asr updates correctly; other displayed metadata remains consistent | — | P0 | ⬜ | — |
| PT-020 | Calculation | Current, next and countdown | Android device | Values change correctly at prayer boundaries | — | P0 | ⬜ | — |
| PT-021 | High latitude | Tromsø near summer solstice | Android device | No crash, blank masquerading as valid time, or malformed row | — | P1 | ⬜ | — |
| PT-022 | High latitude | Tromsø near winter solstice | Android device | Provider adjustment/unavailability is communicated clearly | — | P1 | ⬜ | — |
| PT-023 | Cache | First launch online | Android device | Location → provider → cache → display works | — | P1 | ⬜ | — |
| PT-024 | Cache | Cached schedule offline | Android device, airplane mode | Compatible cached schedule displays | — | P1 | ⬜ | — |
| PT-025 | Cache | No cache offline | Android device, airplane mode | Clear offline state with recovery action | — | P1 | ⬜ | — |
| PT-026 | Cache | Provider failure or timeout | Android device | Compatible cache is retained; otherwise a friendly retry/manual fallback appears | — | P1 | ⬜ | — |
| PT-027 | Cache | Change location/date/calculation/Asr method | Android device | Incompatible cached schedules are never reused | — | P0 | ⬜ | — |
| PT-028 | UI | English light/dark, small/normal/large screens | Android devices | No overflow, clipping, unreadable text or inaccessible buttons | — | P1 | ⬜ | — |
| PT-029 | UI | Urdu/RTL and long place names | Android device | Correct directionality, readable layout and usable controls | — | P1 | ⬜ | — |
| PT-030 | Navigation | Change location, back, background/foreground, recreation | Android device | Selected location and settings persist; navigation remains coherent | — | P1 | ⬜ | — |
| PT-031 | Privacy | Location lifecycle | Android device | Permission is requested only on demand; no background tracking/polling/history or Firebase analytics storage of precise coordinates | — | P0 | ⬜ | — |
| PT-032 | Performance | Reopen Prayer Times and repeated location changes | Android device | Valid cache avoids unnecessary provider calls; transitions remain responsive | — | P2 | ⬜ | — |
| PT-033 | Regression | Full automated suite and Android builds | Local/CI | Analyze, tests, debug APK and signed release APK succeed | — | P0 | ⬜ | — |

## Accuracy procedure

For PT-018 through PT-020, do not hard-code clock values in this document.
Compare the displayed result with the configured calculation method, selected
location timezone, selected date and the provider response captured during the
same test run. Record the provider method and response date in Notes.

## Automated evidence already covered

The V1.1 hardening suite covers injectable-clock timezone/DST behavior,
manual-coordinate timezone correction, invalid timezone rejection,
high-latitude provider parameters, permission/service states, loading and
error rendering, Urdu/RTL, dark theme, and narrow-screen rendering. See
`docs/tracking/prayer-times-v1-1-hardening-qa.md` for the implemented scope.

## Final sign-off

Release-ready only when all P0/P1 rows are marked ✅, PT-033 has recorded
green evidence, and an Android release APK has been generated and installed
successfully on a test device.
