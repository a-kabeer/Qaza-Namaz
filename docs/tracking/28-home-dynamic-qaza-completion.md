# Task 28 — Home Dynamic Qaza Completion Experience

**Status:** In progress  
**Branch:** `task/home-dynamic-qaza`  
**Started:** 2026-09-21  
**Scope:** Home Screen only, using the existing Qaza completion and Prayer Time architecture.

## Tracking Rules

- This is a new tracking document.
- Existing files in `docs/tracking/` are not deleted, replaced, or rewritten.
- Older task history remains unchanged.
- User-facing strings must use the existing localization architecture.
- Existing Prayer Time calculation and oldest-pending repository flows must remain the source of truth.

## Home Screen Structure

- [ ] Overall Progress is first.
- [ ] Today's Progress is second.
- [ ] Qaza Plan action is inside Today's Progress.
- [ ] No separate Qaza Plan section remains.
- [ ] Complete Oldest Qaza follows Today's Progress.

## Qaza Plan

- [ ] Qaza Plan opens a popup.
- [ ] Popup allows daily target selection.
- [ ] Target persists per active user/ledger.
- [ ] Today's Progress reflects target and completed count.
- [ ] Target completion triggers one congratulation popup.
- [ ] Congratulation includes “Alhamdulillah”.
- [ ] Congratulation auto-closes after 5 seconds.
- [ ] Close button works.
- [ ] Tap outside closes the popup.
- [ ] Duplicate popup triggers are prevented.

## Complete Oldest Qaza

- [ ] Existing “Next Qaza” Home experience is replaced.
- [ ] Section is labeled “Complete Oldest Qaza”.
- [ ] Oldest pending lookup uses existing `oldestPending()` flow.
- [ ] Ordering is `originalDate ASC`, then `id ASC`.
- [ ] Completion advances to the next oldest record for the same selected prayer.
- [ ] Empty state is shown when that prayer has no pending Qaza.

## Prayer Selection

- [ ] Six prayer chips exist: Fajr, Zuhr, Asr, Maghrib, Isha, Witr.
- [ ] No “All” chip is present.
- [ ] Automatic mode follows the current Prayer Time period.
- [ ] Fajr → oldest pending Fajr.
- [ ] Zuhr → oldest pending Zuhr.
- [ ] Asr → oldest pending Asr.
- [ ] Maghrib → oldest pending Maghrib.
- [ ] Isha → oldest pending Isha.
- [ ] Witr remains manually selectable.
- [ ] Manual chip selection immediately changes the displayed prayer.
- [ ] User can return to automatic mode.
- [ ] Automatic mode works while Home remains open.
- [ ] App resume recalculates the current prayer.

## Quality

- [ ] Light theme verified.
- [ ] Dark theme verified.
- [ ] RTL verified.
- [ ] Localization verified.
- [ ] No hardcoded theme colors.
- [ ] Relevant tests updated/added.
- [ ] Flutter analyzer passes.
- [ ] Linux tests pass.
- [ ] Windows tests pass.
- [ ] Android build checks remain healthy.

## Implementation Notes

The Home Screen should consume the existing Prayer Time module rather than calculating prayer times itself. Current-prayer state must be time-aware so the Home Screen changes at prayer boundaries even when the app remains open.

The manual prayer chips are an explicit user preference. Automatic mode is the default and can be restored with a clearly discoverable Auto control; “All” is intentionally not offered.

## Completion Record

| Item | Status | Notes |
| --- | --- | --- |
| Code implementation | ⏳ | In progress |
| Tests | ⏳ | In progress |
| CI | ⏳ | Pending |
| Tracking document | ✅ | New standalone task document |
| Older tracking documents preserved | ✅ | No older tracking file is modified |
