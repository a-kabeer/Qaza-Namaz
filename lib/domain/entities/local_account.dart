enum AccountMode { local }

/// Whether a persisted local workspace represents a Guest session.
/// The bare 'guest' ID is retained for compatibility with existing installs.
bool isGuestLocalWorkspaceId(String? localAccountId) {
  final value = localAccountId?.trim();
  return value == 'guest' ||
      (value?.startsWith('guest:') ?? false) ||
      (value?.startsWith('guest_') ?? false);
}

/// Stable local workspace key for a verified Google account.
///
/// The provider returns Google's stable account ID, not an email address.
/// Emails can change and must never be used as workspace identity.
String googleLocalWorkspaceId(String googleAccountId) {
  final normalized = googleAccountId.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(googleAccountId, 'googleAccountId');
  }
  return 'google_$normalized';
}

enum AccountLifecycleState {
  active,
  archived,
  draft,
  adopting,
  restoring,
  adoptedRecovery,
  recoveryCopy,
  deletedHold,
}

class LocalWorkspaceDeletionHold {
  const LocalWorkspaceDeletionHold({
    required this.localAccountId,
    required this.requestedAt,
    required this.expiresAt,
    this.displayName,
  });

  final String localAccountId;
  final DateTime requestedAt;
  final DateTime expiresAt;
  final String? displayName;
}

/// Record counts owned by one workspace, shown in the delete confirmation
/// so the user can see exactly what will be lost.
class GuestWorkspaceRecordCounts {
  const GuestWorkspaceRecordCounts({
    required this.qazaRecords,
    required this.dailySalahRecords,
  });

  final int qazaRecords;
  final int dailySalahRecords;
}

class LocalAccount {
  const LocalAccount({
    required this.localAccountId,
    required this.accountMode,
    required this.lifecycleState,
    required this.createdAt,
    required this.updatedAt,
    this.displayName,
  });

  final String localAccountId;
  final AccountMode accountMode;
  final AccountLifecycleState lifecycleState;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? displayName;
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
