# Navigation Flow

Task 13 standardizes the root navigation behavior without replacing the existing `NavigationBar` + `IndexedStack` architecture.

## Root destinations

Dashboard, Calculator, Logs, and Settings are the four primary destinations. Selecting a different destination switches directly without an extra intermediate screen. Re-selecting the active destination does not create unnecessary state changes.

## Back behavior

- From Account, Notifications, Data & Cloud, or other pushed screens, Back pops exactly that screen.
- From Calculator, Logs, or Settings at the workspace root, Back returns to Dashboard instead of immediately leaving the app.
- From Dashboard at the workspace root, normal platform Back remains available to leave the workspace.

This keeps the navigation hierarchy predictable while preserving the existing screen transitions and bottom-navigation state model.
