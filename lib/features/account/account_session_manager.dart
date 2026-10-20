import 'package:flutter/foundation.dart';

import '../../data/local/account_local_store.dart';
import '../../domain/entities/local_account.dart';

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
    // The initial state is already loading. Avoid a redundant synchronous
    // notifyListeners() when initialize() is called from app initState, which
    // can dirty ProviderScope while its widget subtree is still mounting.
    if (_state.phase != AccountSessionPhase.loading) {
      _setState(const AccountSessionState.loading());
    }
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

  /// Returns to a safe local Guest workspace without deleting any records.
  ///
  /// Older installations may have adopted and archived the legacy `guest`
  /// workspace. Never reactivate that archived workspace during sign-out;
  /// create an empty temporary Guest workspace instead and let the account
  /// chooser explicitly reopen a saved Guest account.
  Future<void> activateGuest() async {
    final currentId = activeLocalAccountId;
    final current =
        currentId == null ? null : await _accountStore.getAccount(currentId);
    if (current != null &&
        isGuestLocalWorkspaceId(current.localAccountId) &&
        (current.lifecycleState == AccountLifecycleState.active ||
            current.lifecycleState == AccountLifecycleState.draft)) {
      await activateLocalAccount(current.localAccountId);
      return;
    }

    // Signing out of Google must not silently reopen an unrelated saved Guest.
    // The chooser lets the user select that workspace explicitly.
    final freshGuestId = await _accountStore.createGuestWorkspace();
    await activateLocalAccount(freshGuestId);
  }

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
