import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';

/// Explicit dependency-injection boundary for the independently built cloud
/// host. The offline root app never imports or invokes this composition.
List<Override> cloudHostProviderOverrides({
  required GoogleSignInGateway gateway,
  required SharedPreferencesCloudSyncStateStore state,
  required CloudSyncScheduler scheduler,
  required String? serverClientId,
}) {
  return <Override>[
    packageAssetNamespaceProvider.overrideWithValue('qaza_namaz'),
    cloudAccountProvider.overrideWith(
      (ref) => GoogleCloudAccountProvider(
        gateway: gateway,
        state: state,
        scheduler: scheduler,
        serverClientId: serverClientId,
      ),
    ),
    cloudSyncProvider.overrideWith(
      (ref) => GoogleCloudSyncProvider(
        database: ref.watch(appDatabaseProvider),
        gateway: gateway,
        state: state,
        scheduler: scheduler,
        serverClientId: serverClientId,
      ),
    ),
  ];
}
