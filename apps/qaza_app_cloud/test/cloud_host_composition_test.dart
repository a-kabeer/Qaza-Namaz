import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';
import 'package:qaza_namaz_cloud/cloud_host_composition.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cloud host injects cloud providers without changing offline defaults',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    final gateway = GoogleSignInGateway();
    final state = SharedPreferencesCloudSyncStateStore();
    final scheduler = CloudSyncScheduler(state: state);
    final overrides = cloudHostProviderOverrides(
      gateway: gateway,
      state: state,
      scheduler: scheduler,
      serverClientId: 'test-server-client-id',
    );
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    addTearDown(database.close);

    expect(container.read(cloudAccountProvider).isSupported, isTrue);
    expect(container.read(cloudSyncProvider).isSupported, isTrue);
    expect(container.read(packageAssetNamespaceProvider), 'qaza_namaz');

    final offlineContainer = ProviderContainer();
    addTearDown(offlineContainer.dispose);
    expect(offlineContainer.read(cloudAccountProvider).isSupported, isFalse);
    expect(offlineContainer.read(cloudSyncProvider).isSupported, isFalse);
  });
}
