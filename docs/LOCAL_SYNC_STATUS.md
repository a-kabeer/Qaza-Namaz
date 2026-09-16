# Local Sync Status

The app exposes a simple, user-facing sync lifecycle without showing Firebase, Firestore, SharedPreferences, outbox, or other implementation details.

| Internal condition | User-facing status | Meaning |
| --- | --- | --- |
| Local change waiting to sync | **Saved** | The change is safely stored on the device and will sync automatically. |
| Device temporarily offline | **Saved** | The change remains safely stored locally and will sync when connectivity returns. |
| Synchronization running | **Syncing** | The app is currently sending and reconciling saved changes. |
| Synchronization confirmed | **Synced** | The latest changes have been confirmed successfully. |
| Unexpected synchronization failure | **Sync Error** | The change is still saved locally; the app will retry automatically. A manual Retry action is available. |

Technical error strings are intentionally not rendered in the normal user interface. They remain internal to the synchronization layer for diagnostics.
