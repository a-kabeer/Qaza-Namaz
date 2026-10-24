/// Provider-neutral Google identity contracts.
///
/// Authentication identifies a local workspace; it does not imply that any
/// remote storage, backup, or synchronization service is configured.
enum GoogleIdentityStatus {
  unavailable,
  signedOut,
  signedIn,
  failed,
  cancelled
}

class GoogleIdentitySnapshot {
  const GoogleIdentitySnapshot({
    required this.status,
    this.accountId,
    this.displayName,
    this.email,
    this.photoUrl,
    this.message,
  });

  const GoogleIdentitySnapshot.unavailable()
      : status = GoogleIdentityStatus.unavailable,
        accountId = null,
        displayName = null,
        email = null,
        photoUrl = null,
        message = null;

  const GoogleIdentitySnapshot.signedOut()
      : status = GoogleIdentityStatus.signedOut,
        accountId = null,
        displayName = null,
        email = null,
        photoUrl = null,
        message = null;

  const GoogleIdentitySnapshot.signedIn({
    required String accountId,
    this.displayName,
    this.email,
    this.photoUrl,
  })  : status = GoogleIdentityStatus.signedIn,
        accountId = accountId,
        message = null;

  const GoogleIdentitySnapshot.failed(String message)
      : status = GoogleIdentityStatus.failed,
        accountId = null,
        displayName = null,
        email = null,
        photoUrl = null,
        message = message;

  const GoogleIdentitySnapshot.cancelled()
      : status = GoogleIdentityStatus.cancelled,
        accountId = null,
        displayName = null,
        email = null,
        photoUrl = null,
        message = null;

  final GoogleIdentityStatus status;
  final String? accountId;
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final String? message;

  bool get isSignedIn =>
      status == GoogleIdentityStatus.signedIn &&
      (accountId?.trim().isNotEmpty ?? false);
}

abstract interface class GoogleIdentityProvider {
  bool get isSupported;

  /// Restores an already authenticated identity without deliberately opening
  /// the interactive sign-in flow.
  Future<GoogleIdentitySnapshot> restore();

  /// Starts sign-in following an explicit user action.
  Future<GoogleIdentitySnapshot> signIn();

  /// Signs out of this app's Google identity session without revoking account
  /// permissions at Google or changing/deleting the local workspace.
  Future<void> signOut();
}

class UnsupportedGoogleIdentityProvider implements GoogleIdentityProvider {
  const UnsupportedGoogleIdentityProvider();

  @override
  bool get isSupported => false;

  @override
  Future<GoogleIdentitySnapshot> restore() async =>
      const GoogleIdentitySnapshot.unavailable();

  @override
  Future<GoogleIdentitySnapshot> signIn() async =>
      const GoogleIdentitySnapshot.unavailable();

  @override
  Future<void> signOut() async {}
}
