# Navigation Flow

The final V2 navigation contract. It keeps the existing `NavigationBar` +
`IndexedStack` architecture rather than replacing it.

## Root destinations

```text
Home · Qaza · Calculator · Settings
```

| Destination | Purpose |
| --- | --- |
| **Home** | Status and next action. Aggregate progress and a state-dependent primary CTA. |
| **Qaza** | The canonical tracking workspace: bounded pages, status/prayer/date filters, bulk completion. |
| **Calculator** | The three-step estimate: About You → Prayer History → Result. |
| **Settings** | Appearance, Language, Account, Prayer Rules, Notifications, Data & Cloud, Knowledge Base, About. |

There is no generic `More` tab and no Dashboard destination — Home is the single
canonical entry point, and `lib/features/dashboard/` has been removed.

Logs is **not** a root destination. It opens from the Qaza workspace's app bar,
so history no longer competes with the tracker for the same conceptual space.

## Rules

- Selecting a different destination switches directly, with no intermediate
  screen.
- Re-selecting the active destination is a no-op.
- Destinations mount lazily and keep their state once mounted.
- From a pushed screen (Account, Notifications, Data & Cloud, Add Qaza, Logs,
  Complete Qaza), Back pops exactly that screen.
- From Qaza, Calculator or Settings at the workspace root, Back returns to Home
  rather than leaving the app.
- From Home at the workspace root, normal platform Back leaves the workspace.
- There are no redundant root routes.

## Startup

```text
Splash -> Google authentication -> Home
```

No configuration screen sits in this path. Theme defaults to System and
language to English; both are persisted and both are changed from Settings, so
a newly signed-in account lands on Home immediately.

While an account's local database is being prepared, the sync indicator reports
`Setting up` and then `Restoring` before the app settles into its normal state —
see `OFFLINE_FIRST_ARCHITECTURE.md`.

## Coverage

`test/features/shell/workspace_shell_navigation_test.dart` pins the destination
list and labels; `test/workspace_test.dart` covers destination switching, state
preservation and Back-returns-to-Home; `test/task6_auth_lifecycle_test.dart`
covers the startup path including sign-out.
