# Qaza Namaz — Page Audit Tracker

**Purpose:** Master checklist for auditing the app one page at a time.

**Tracking rule:** A page is marked **Completed** only when Abdul explicitly confirms that the audit/task for that page is complete. Do not mark a page completed based on an implementation being merged or tests passing alone.

**Current audit sequence:** Start with **Home**, then move to the next page only when the user decides.

## Page Status

| # | Page / Screen | Code Reference | Status | Notes |
|---:|---|---|---|---|
| 1 | **Home** | `HomeScreen` | ⬜ Not Started | First audit target |
| 2 | **Qaza Tracker** | `QazaTrackerScreen` | ⬜ Not Started | Pending + History tabs |
| 3 | **Calculator** | `CalculatorScreen` | ⬜ Not Started | Multi-step calculator flow |
| 4 | **Add Qaza** | `AddQazaScreen` | ⬜ Not Started | Qaza entry/date selection flow |
| 5 | **Qaza History** | `QazaHistoryScreen` | ⬜ Not Started | Embedded History tab |
| 6 | **Qaza Operation Detail** | `QazaOperationDetailScreen` | ⬜ Not Started | Opens from History |
| 7 | **Prayer Times** | `PrayerTimesScreen` | ⬜ Not Started | Prayer schedule/location |
| 8 | **Knowledge Base** | `KnowledgeBasePage` | ⬜ Not Started | Knowledge articles |
| 9 | **Knowledge Article Detail** | `KnowledgeArticleDetailPage` | ⬜ Not Started | Individual article |
| 10 | **Settings** | `SettingsScreen` | ⬜ Not Started | Main settings page |
| 11 | **Account** | `AccountScreen` | ⬜ Not Started | Account management |
| 12 | **Notifications** | `NotificationsScreen` | ⬜ Not Started | Reminder settings |
| 13 | **App Lock Settings** | `AppLockSettingsScreen` | ⬜ Not Started | App lock configuration |
| 14 | **Data & Cloud** | `DataCloudScreen` | ⬜ Not Started | Backup/sync/cloud data |
| 15 | **Qaza Data Management** | `QazaDataManagementScreen` | ⬜ Not Started | Import/export/data management |
| 16 | **About** | `AboutScreen` | ⬜ Not Started | App information/version |
| 17 | **Welcome / Authentication / Startup Flow** | `WelcomeScreen`, `AuthenticationScreen`, `SplashScreen`, `AuthGate` | ⬜ Not Started | Startup and sign-in flow |

## Completion Convention

When the user says a page/task is complete:

1. Change its **Status** from `⬜ Not Started` to `✅ Completed`.
2. Add a brief completion note when useful.
3. Do not change the status of any other page.
4. Keep the original audit order unless the user explicitly changes it.

## Non-Page UI Surfaces

These are tracked as part of their parent page rather than separate pages:

- Qaza record editor bottom sheet
- Prayer location edit sheet
- Country picker sheet
- Qaza filter sheet
- Confirmation dialogs
- Backup/sign-in prompt
- Calculator preflight dialog
- Loading, empty, and error states
- App lock gate / guest upgrade states

## Current State

**Active page:** Home  
**Completed pages:** 0 / 17
