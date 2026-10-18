enum AccountMode { local }

/// Stable local workspace key for a verified Google account.
///
/// The provider returns Google's stable account ID, not an email address.
/// Emails can change and must never be used as workspace identity.
String googleLocalWorkspaceId(String googleAccountId) {
  final normalized = googleAccountId.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(googleAccountId, 'googleAccountId');
  }
  return 'google:$normalized';
}

enum AccountLifecycleState { active, archived }

class LocalAccount {
  const LocalAccount({
    required this.localAccountId,
    required this.accountMode,
    required this.lifecycleState,
    required this.createdAt,
    required this.updatedAt,
  });

  final String localAccountId;
  final AccountMode accountMode;
  final AccountLifecycleState lifecycleState;
  final DateTime createdAt;
  final DateTime updatedAt;
}

enum AccountSessionPhase { loading, connecting, ready, error }

class AccountSessionState {
  const AccountSessionState({
    required this.phase,
    required this.activeLocalAccountId,
    required this.activeAccount,
    this.message,
  });

  const AccountSessionState.loading()
      : phase = AccountSessionPhase.loading,
        activeLocalAccountId = null,
        activeAccount = null,
        message = null;

  final AccountSessionPhase phase;
  final String? activeLocalAccountId;
  final LocalAccount? activeAccount;
  final String? message;
}
