import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/data/local/account_local_store.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/domain/entities/local_account.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/features/account/account_session_manager.dart';

void main() {
  test('startup creates and restores one local device session', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final store = AccountLocalStore(database: database);
    final manager = AccountSessionManager(accountStore: store);

    await manager.initialize();

    expect(manager.state.phase, AccountSessionPhase.ready);
    expect(
      manager.activeLocalAccountId,
      UserProfile.localLedgerUserId,
    );
    expect(manager.activeAccount, isNotNull);
    expect(manager.activeAccount!.accountMode, AccountMode.local);

    await manager.refresh();

    expect(manager.state.phase, AccountSessionPhase.ready);
    expect(
      manager.activeLocalAccountId,
      UserProfile.localLedgerUserId,
    );
  });
}
