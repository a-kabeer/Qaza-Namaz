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

  Future<void> refresh() async {
    final accountId = await _accountStore.activeLocalAccountId();
    final account =
        accountId == null ? null : await _accountStore.getAccount(accountId);
    if (account == null) {
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
  }

  void _setState(AccountSessionState next) {
    _state = next;
    onActiveLocalAccountChanged?.call(next.activeLocalAccountId);
    notifyListeners();
  }
}
