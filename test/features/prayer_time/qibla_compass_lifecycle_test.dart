import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/prayer_time/application/qibla_providers.dart';
import 'package:qaza_namaz/features/prayer_time/data/device_compass_service.dart';

void main() {
  test('compass stream is disposed when provider is disposed', () async {
    final fake = _FakeCompassService();
    final container = ProviderContainer(
      overrides: [
        compassServiceProvider.overrideWithValue(fake),
      ],
    );

    final listener = container.listen(
      compassReadingProvider,
      (_, __) {},
      fireImmediately: true,
    );

    await Future<void>.delayed(Duration.zero);
    expect(fake.listenCount, 1);

    container.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(fake.cancelCount, 1);
    listener.close();
    await fake.close();
  });
}

class _FakeCompassService implements CompassService {
  final _controller = StreamController<CompassReading>.broadcast();
  int listenCount = 0;
  int cancelCount = 0;

  @override
  Future<bool> hasSensors() async => true;

  @override
  Stream<CompassReading> readings() {
    listenCount++;
    return _controller.stream;
  }

  Future<void> close() async {
    await _controller.close();
  }
}
