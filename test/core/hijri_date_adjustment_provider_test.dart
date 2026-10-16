import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/core/calendar/hijri_date_adjustment_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to zero and persists selected offsets locally', () async {
    SharedPreferences.setMockInitialValues({});

    final firstContainer = ProviderContainer();
    expect(await firstContainer.read(hijriDateAdjustmentProvider.future), 0);

    await firstContainer
        .read(hijriDateAdjustmentProvider.notifier)
        .setOffset(-2);

    expect(firstContainer.read(hijriDateAdjustmentProvider).valueOrNull, -2);
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getInt(HijriDateAdjustmentNotifier.storageKey),
      -2,
    );
    firstContainer.dispose();

    final restoredContainer = ProviderContainer();
    expect(
      await restoredContainer.read(hijriDateAdjustmentProvider.future),
      -2,
    );
    restoredContainer.dispose();
  });

  test('unsupported saved offsets fall back to zero', () async {
    SharedPreferences.setMockInitialValues({
      HijriDateAdjustmentNotifier.storageKey: 3,
    });

    final container = ProviderContainer();
    expect(await container.read(hijriDateAdjustmentProvider.future), 0);
    container.dispose();
  });

  test('rejects offsets outside the five supported choices', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    await container.read(hijriDateAdjustmentProvider.future);

    await expectLater(
      container.read(hijriDateAdjustmentProvider.notifier).setOffset(3),
      throwsArgumentError,
    );
    container.dispose();
  });
}
