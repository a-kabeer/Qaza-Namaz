import 'package:flutter/foundation.dart';

import '../../data/local/account_local_store.dart';
import '../../domain/entities/local_account.dart';
import '../../domain/entities/user_profile.dart';

class AccountSessionManager extends ChangeNotifier {
  AccountSessionManager({
    required AccountLocalStore accountStore,
    this.onActiveLocalAccountChanged,
  }) : _accountStore = accountStore;

  final AccountLocalStore _accountStore;
  final void Function(String?)? onActiveLocalAccountChanged;

  AccountSessionState _state = const AccountSessionState.loading();
  bool _initialized = false;
  Future<void>? _initializationFuture;

  AccountSessionState get state => _state;
  String? get activeLocalAccountId => _state.activeLocalAccountId;
  LocalAccount? get activeAccount => _state.activeAccount;

  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    final running = _initializationFuture;
    if (running != null) return running;

    final future = _initializeLocalState();
    _initializationFuture = future;
    return future.whenComplete(() {
      if (identical(_initializationFuture, future)) {
        _initializationFuture = null;
      }
    });
  }

  Future<void> _initializeLocalState() async {
    _setState(const AccountSessionState.loading());
    try {
      await _accountStore.ensureInitialized();
      final localAccountId = await _accountStore.ensureLocalAccountActive();
      final account = await _accountStore.getAccount(localAccountId);
      if (account == null) {
        throw StateError('Unable to initialize the local device account.');
      }

      _setState(
        AccountSessionState(
          phase: AccountSessionPhase.ready,
          activeLocalAccountId: account.localAccountId,
          activeAccount: account,
        ),
      );
      _initialized = true;
    } catch (error) {
      _initialized = false;
      _setState(
        AccountSessionState(
          phase: AccountSessionPhase.error,
          activeLocalAccountId: null,
          activeAccount: null,
          message: error.toString(),
        ),
      );
    }
  }

  /// Activates the stable workspace associated with a verified Google ID.
  Future<void> activateGoogleAccount(String googleAccountId) =>
      activateLocalAccount(googleLocalWorkspaceId(googleAccountId));

  /// Returns to the existing Guest workspace without deleting any records.
  Future<void> activateGuest() =>
      activateLocalAccount(UserProfile.localLedgerUserId);

  Future<void> activateLocalAccount(String localAccountId) async {
    try {
      await _accountStore.ensureAccountActive(localAccountId);
      final account = await _accountStore.getAccount(localAccountId);
      if (account == null) {
        throw StateError('The selected local workspace could not be opened.');
      }
      _setState(
        AccountSessionState(
          phase: AccountSessionPhase.ready,
          activeLocalAccountId: account.localAccountId,
          activeAccount: account,
        ),
      );
      _initialized = true;
    } catch (error) {
      _initialized = false;
      _setState(
        AccountSessionState(
          phase: AccountSessionPhase.error,
          activeLocalAccountId: null,
          activeAccount: null,
          message: error.toString(),
        ),
      );
      rethrow;
    }
  }

  Future<void> retry() async {
    _initialized = false;
    await initialize();
  }

  Future<void> refresh() async {
    try {
      final account = await _accountStore.activeAccount();
      if (account == null) {
        _initialized = false;
        _setState(
          const AccountSessionState(
            phase: AccountSessionPhase.error,
            activeLocalAccountId: null,
            activeAccount: null,
            message: 'The local device account could not be restored.',
          ),
        );
        return;
      }

      _setState(
        AccountSessionState(
          phase: AccountSessionPhase.ready,
          activeLocalAccountId: account.localAccountId,
          activeAccount: account,
        ),
      );
      _initialized = true;
    } catch (error) {
      _initialized = false;
      _setState(
        AccountSessionState(
          phase: AccountSessionPhase.error,
          activeLocalAccountId: null,
          activeAccount: null,
          message: error.toString(),
        ),
      );
    }
  }

  void _setState(AccountSessionState next) {
    _state = next;
    onActiveLocalAccountChanged?.call(next.activeLocalAccountId);
    notifyListeners();
  }
}
