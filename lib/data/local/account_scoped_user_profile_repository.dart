import 'package:drift/drift.dart';


import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';
import 'account_local_store.dart';

class AccountScopedUserProfileRepository implements UserProfileRepository {
  AccountScopedUserProfileRepository({
    required AccountLocalStore store,
    required String? Function() activeAccountId,
  })  : _store = store,
        _activeAccountId = activeAccountId;

  final AccountLocalStore _store;
  final String? Function() _activeAccountId;

  @override
  Future<UserProfile?> load() async {
    final id = _activeAccountId();
    if (id == null) return null;
    return _store.loadProfile(id);
  }

  @override
  Future<void> save(UserProfile profile) async {
    final id = _activeAccountId();
    if (id == null) {
      throw StateError('No active local account exists.');
    }
    await _store.saveProfile(id, profile);
  }

  @override
  Future<void> clear() async {
    final id = _activeAccountId();
    if (id == null) return;
    await _store.database.customUpdate(
      'DELETE FROM account_profiles WHERE local_account_id = ?',
      variables: [Variable(id)],
    );
  }
}
