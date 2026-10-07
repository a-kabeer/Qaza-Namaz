import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    try {
      final prefs = await SharedPreferences.getInstance();
      UserProfile? legacyProfile;
      final raw = prefs.getString(UserProfile.storageKey);
      if (raw != null) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            legacyProfile =
                UserProfile.fromJson(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      }

      await _accountStore.ensureInitialized(
        hasLegacyProfile: raw != null,
        hasLegacyQaza:
            await _accountStore.hasAnyQaza(UserProfile.localLedgerUserId),
        legacyProfile: legacyProfile,
      );

      final accountId = await _accountStore.ensureGuestActive();
      final account = await _accountStore.getAccount(accountId);
      if (account == null) {
        throw StateError('Unable to initialize the local device account.');
      }

      _setState(
        AccountSessionState(
          phase: AccountSessionPhase.ready,
          activeLocalAccountId: account.localAccountId,
          activeAccount: account,
          initialChoiceRequired: false,
          migrationState: 'none',
          restoreState: 'local_only',
        ),
      );
      _initialized = true;
    } catch (error) {
      _setState(
        AccountSessionState(
          phase: AccountSessionPhase.error,
          activeLocalAccountId: null,
          activeAccount: null,
          initialChoiceRequired: false,
          migrationState: 'failed',
          restoreState: 'failed',
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

  Future<void> refresh() async {
    final accountId = await _accountStore.activeLocalAccountId();
    final account =
        accountId == null ? null : await _accountStore.getAccount(accountId);
    _setState(
      AccountSessionState(
        phase: account == null
            ? AccountSessionPhase.error
            : AccountSessionPhase.ready,
        activeLocalAccountId: account?.localAccountId,
        activeAccount: account,
        initialChoiceRequired: false,
        migrationState: 'none',
        restoreState: 'local_only',
        message: account == null
            ? 'The local device account could not be restored.'
            : null,
      ),
    );
  }
}
