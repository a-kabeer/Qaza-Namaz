import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/features/settings/app_lock_controller.dart';

class _FakeDeviceAuthenticationService
    implements DeviceAuthenticationService {
  bool supported = true;
  bool authenticateResult = true;
  int authenticateCalls = 0;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> authenticate({
    required String localizedReason,
  }) async {
    authenticateCalls++;
    return authenticateResult;
  }
}

ProviderContainer _container(_FakeDeviceAuthenticationService service) {
  return ProviderContainer(
    overrides: [
      deviceAuthenticationServiceProvider.overrideWithValue(service),
    ],
  );
}

void main() {
  test('app lock is disabled by default', () async {
    SharedPreferences.setMockInitialValues({});
    final service = _FakeDeviceAuthenticationService();
    final container = _container(service);
    addTearDown(container.dispose);

    await container.read(appLockControllerProvider.notifier).restore();

    final state = container.read(appLockControllerProvider);
    expect(state.initialized, isTrue);
    expect(state.enabled, isFalse);
    expect(state.locked, isFalse);
  });

  test('enabling app lock requires successful device authentication', () async {
    SharedPreferences.setMockInitialValues({});
    final service = _FakeDeviceAuthenticationService();
    final container = _container(service);
    addTearDown(container.dispose);

    await container.read(appLockControllerProvider.notifier).restore();
    final enabled =
        await container.read(appLockControllerProvider.notifier).setEnabled(
              enabled: true,
              localizedReason: 'Unlock Qaza Namaz',
            );

    expect(enabled, isTrue);
    expect(service.authenticateCalls, 1);
    expect(container.read(appLockControllerProvider).enabled, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(AppLockController.enabledStorageKey), isTrue);
  });

  test('canceled enable leaves app lock disabled', () async {
    SharedPreferences.setMockInitialValues({});
    final service = _FakeDeviceAuthenticationService()
      ..authenticateResult = false;
    final container = _container(service);
    addTearDown(container.dispose);

    await container.read(appLockControllerProvider.notifier).restore();
    final enabled =
        await container.read(appLockControllerProvider.notifier).setEnabled(
              enabled: true,
              localizedReason: 'Unlock Qaza Namaz',
            );

    expect(enabled, isFalse);
    expect(container.read(appLockControllerProvider).enabled, isFalse);
  });

  test('unsupported device cannot enable app lock', () async {
    SharedPreferences.setMockInitialValues({});
    final service = _FakeDeviceAuthenticationService()..supported = false;
    final container = _container(service);
    addTearDown(container.dispose);

    await container.read(appLockControllerProvider.notifier).restore();
    final enabled =
        await container.read(appLockControllerProvider.notifier).setEnabled(
              enabled: true,
              localizedReason: 'Unlock Qaza Namaz',
            );

    expect(enabled, isFalse);
    expect(
      container.read(appLockControllerProvider).error,
      AppLockError.unavailable,
    );
    expect(service.authenticateCalls, 0);
  });

  test('timeout setting persists', () async {
    SharedPreferences.setMockInitialValues({});
    final service = _FakeDeviceAuthenticationService();
    final container = _container(service);
    addTearDown(container.dispose);

    await container.read(appLockControllerProvider.notifier).restore();
    await container.read(appLockControllerProvider.notifier).setEnabled(
          enabled: true,
          localizedReason: 'Unlock Qaza Namaz',
        );
    await container.read(appLockControllerProvider.notifier).setTimeout(
          AppLockTimeout.fiveMinutes,
        );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(AppLockController.timeoutStorageKey),
      'fiveMinutes',
    );
    expect(
      container.read(appLockControllerProvider).timeout,
      AppLockTimeout.fiveMinutes,
    );
  });

  test('immediate timeout locks on background and stays locked until unlock',
      () async {
    SharedPreferences.setMockInitialValues({});
    final service = _FakeDeviceAuthenticationService();
    final container = _container(service);
    addTearDown(container.dispose);

    final controller = container.read(appLockControllerProvider.notifier);
    await controller.restore();
    await controller.setEnabled(
      enabled: true,
      localizedReason: 'Unlock Qaza Namaz',
    );

    controller.onLifecycleState(AppLifecycleState.paused);
    expect(container.read(appLockControllerProvider).locked, isTrue);

    controller.onLifecycleState(AppLifecycleState.resumed);
    expect(container.read(appLockControllerProvider).locked, isTrue);

    expect(
      await controller.unlock(localizedReason: 'Unlock Qaza Namaz'),
      isTrue,
    );
    expect(container.read(appLockControllerProvider).locked, isFalse);
  });

  test('five-minute timeout does not lock after a short background period',
      () async {
    SharedPreferences.setMockInitialValues({});
    final service = _FakeDeviceAuthenticationService();
    final container = _container(service);
    addTearDown(container.dispose);

    final controller = container.read(appLockControllerProvider.notifier);
    await controller.restore();
    await controller.setEnabled(
      enabled: true,
      localizedReason: 'Unlock Qaza Namaz',
    );
    await controller.setTimeout(AppLockTimeout.fiveMinutes);

    controller.onLifecycleState(AppLifecycleState.paused);
    controller.onLifecycleState(AppLifecycleState.resumed);

    expect(container.read(appLockControllerProvider).locked, isFalse);
  });
}
