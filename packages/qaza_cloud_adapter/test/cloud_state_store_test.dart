import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('cloud and automatic sync default to disabled', () async {
    final state = SharedPreferencesCloudSyncStateStore();

    expect(await state.isCloudSyncEnabled(), isFalse);
    expect(await state.isAutomaticSyncEnabled(), isFalse);
    expect(await state.lastSuccessfulSyncAt(), isNull);
  });

  test('disabling cloud durably disables automatic sync', () async {
    final state = SharedPreferencesCloudSyncStateStore();

    await state.setCloudSyncEnabled(true);
    await state.setAutomaticSyncEnabled(true);
    expect(await state.isAutomaticSyncEnabled(), isTrue);

    await state.setCloudSyncEnabled(false);

    expect(await state.isCloudSyncEnabled(), isFalse);
    expect(await state.isAutomaticSyncEnabled(), isFalse);
  });

  test('automatic sync cannot be enabled when cloud is disabled', () async {
    final state = SharedPreferencesCloudSyncStateStore();

    await expectLater(
      state.setAutomaticSyncEnabled(true),
      throwsA(isA<CloudAdapterException>()),
    );
  });

  test('last successful timestamp round-trips in UTC', () async {
    final state = SharedPreferencesCloudSyncStateStore();
    final value = DateTime.utc(2026, 10, 9, 7, 30);

    await state.setLastSuccessfulSyncAt(value);

    expect(await state.lastSuccessfulSyncAt(), value);
  });
}
