# Authentication Lifecycle

## Scope

Task 6 audits the existing Firebase Authentication + Google Sign-In lifecycle without replacing the authentication architecture.

## Authentication Flow

- Firebase is initialized before the Flutter application starts.
- `FirebaseAuthRepository` exposes the current user and Firebase `authStateChanges()` through the domain authentication interface.
- Google Sign-In obtains the Google ID token and exchanges it for a Firebase credential.
- `AuthGate` derives the signed-in/signed-out UI state from the Firebase authentication stream.
- Existing Firebase sessions are restored through Firebase Auth rather than a separately persisted client session.
- Sign-out signs out of Firebase Auth and Google Sign-In.

## Account Isolation

Application records are already namespaced by Firebase UID in the offline-first repository. Task 6 also verified that first-time setup state must follow the same account boundary.

### Fix applied

The first-time setup completion flag was previously stored under one global SharedPreferences key. That allowed one account's completed setup state to affect another account on the same device.

The flag is now stored as:

`qaza_first_time_setup_complete_{firebaseUid}`

`AuthGate` reloads this state when the authenticated UID changes and resets its in-memory setup state on sign-out.

## Firestore Server-Side Ownership

The checked-in Firestore rules enforce ownership using the authenticated Firebase UID:

```text
match /users/{userId}/{document=**} {
  allow read, write: if request.auth != null
    && request.auth.uid == userId;
}
```

Therefore client-side UID selection is not the security boundary. Firestore itself rejects reads and writes addressed to another user's `users/{userId}` path.

## Error / Lifecycle Behavior

- Google sign-in cancellation or authentication failure is surfaced by the existing authentication screen without exposing application data.
- Firebase authentication state changes drive the application gate.
- Signed-out state prevents authenticated workspace access.
- Account-specific setup state is not reused across different authenticated UIDs.
- Existing offline-first repository account switching remains responsible for clearing the in-memory namespace before loading the next user's local data.

## Validation

Task 6 adds regression coverage for:

- signed-out authentication entry;
- account-specific setup isolation across sign-out and account switch;
- the checked-in Firestore rule requiring authentication and matching `request.auth.uid == userId`.

Full GitHub CI is the completion gate for the task. Task 6 is not marked complete until the final status-update commit passes the complete repository CI matrix.
