enum AccountMode { guest, google }

enum AccountLifecycleState { active, migrating, archived }

class LocalAccount {
  const LocalAccount({
    required this.localAccountId,
    required this.accountMode,
    required this.firebaseUid,
    required this.googleEmail,
    required this.lifecycleState,
    required this.cloudBackupEnabled,
    required this.cloudGeneration,
    required this.createdAt,
    required this.updatedAt,
  });

  final String localAccountId;
  final AccountMode accountMode;
  final String? firebaseUid;
  final String? googleEmail;
  final AccountLifecycleState lifecycleState;
  final bool cloudBackupEnabled;
  final int cloudGeneration;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isGuest => accountMode == AccountMode.guest;
  bool get isGoogle => accountMode == AccountMode.google;
}

enum AccountSessionPhase { loading, connecting, ready, error }

class AccountSessionState {
  const AccountSessionState({
    required this.phase,
    required this.activeLocalAccountId,
    required this.activeAccount,
    required this.initialChoiceRequired,
    required this.migrationState,
    required this.restoreState,
    this.message,
  });

  const AccountSessionState.loading()
      : phase = AccountSessionPhase.loading,
        activeLocalAccountId = null,
        activeAccount = null,
        initialChoiceRequired = false,
        migrationState = 'none',
        restoreState = 'none',
        message = null;

  final AccountSessionPhase phase;
  final String? activeLocalAccountId;
  final LocalAccount? activeAccount;
  final bool initialChoiceRequired;
  final String migrationState;
  final String restoreState;
  final String? message;
}
