import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/domain/services/cloud_sync_contracts.dart';

void main() {
  test('offline providers report cloud as unsupported', () async {
    const account = UnsupportedCloudAccountProvider();
    const sync = UnsupportedCloudSyncProvider();

    expect(account.isSupported, isFalse);
    expect((await account.restore()).status, CloudAccountStatus.unavailable);
    expect(sync.isSupported, isFalse);
    expect((await sync.status()).status, CloudSyncStatus.unavailable);
  });
}
