# Prayer Times — Release QA

Status: **Offline implementation; automated CI validation pending**

## Release rule

Do not mark the offline Prayer Times migration release-ready until automated CI is green and the P0/P1 real-device cases below have recorded results. Record device model, Android version, app build, locale and connection state for each manual result.

| ID | Area | Test | Expected result |
| --- | --- | --- | --- |
| PT-001 | Location | Use My Location | Foreground location permission works; coordinates, nearby city and timezone resolve locally |
| PT-002 | Permission | Deny location | Clear retry/manual-location recovery |
| PT-003 | Permission | Deny permanently | App-settings recovery |
| PT-004 | Location | Service disabled | Clear message and location-settings action |
| PT-005 | Location | Approximate location | Usable schedule remains available |
| PT-006 | Manual city | Pakistan | Offline city search and local calculation |
| PT-007 | Manual city | Saudi Arabia | Offline city search and local calculation |
| PT-008 | Manual city | United Kingdom | Offline city search and local calculation |
| PT-009 | Manual city | United States | Offline city search and local calculation |
| PT-010 | Manual city | Malaysia | Offline city search and local calculation |
| PT-011 | Manual city | Turkey | Offline city search and local calculation |
| PT-012 | Coordinates | Valid signed coordinates | Local timezone resolution and prayer calculation |
| PT-013 | Coordinates | Invalid/boundary values | Input rejected safely |
| PT-014 | Timezone | Phone timezone differs from selected location | Selected location civil date and countdown remain correct |
| PT-015 | DST | DST transition location/date | Local date and countdown remain correct |
| PT-016 | Midnight | Date rollover | No wrong-day schedule |
| PT-017 | Calculation | Standard Asr | Correct local calculation |
| PT-018 | Calculation | Hanafi Asr | Asr changes appropriately |
| PT-019 | Calculation | All supported calculation methods | Calculation succeeds for supported presets |
| PT-020 | Solar | Sunrise/Zawal/Sunset | Restriction windows are derived from local solar results |
| PT-021 | Restriction | During restriction | Remaining duration and next allowed time are shown; completion disabled |
| PT-022 | Restriction | After restriction | Completion becomes available without restart |
| PT-023 | Offline | Airplane mode | Prayer times and city lookup work with no network |
| PT-024 | Offline | Fresh install, no cache | Prayer calculation still works after local location selection |
| PT-025 | UI | English light/dark | No overflow/unreadable controls |
| PT-026 | UI | Urdu/RTL | Correct direction and readable text |
| PT-027 | Regression | Qaza completion/undo | Existing completion and undo behavior remains intact |
| PT-028 | Regression | Full CI + Android build | All automated checks pass |

## Accuracy procedure

For a representative set of cities/dates, compare the offline calculation against a trusted reference before release. Record the selected calculation method, Asr method, location timezone and observed minute differences.

A numerical match is a validation target, not an assumption; supported methods may differ when providers use different adjustments or defaults.

## Network-independence evidence

The final device run must verify:

`Wi-Fi off → mobile data off → airplane mode → Prayer Times opens/calculates → city search works → Qaza restriction logic works.`

