import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/prayer_time/data/device_compass_service.dart';

void main() {
  test('compass stream supports explicit subscription cancellation', () async {
    final fake = _FakeCompassService();

    final subscription = fake.readings().listen((_) {});

    expect(fake.listenCount, 1);

    await subscription.cancel();

    expect(fake.cancelCount, 1);
    await fake.close();
  });
}

class _FakeCompassService implements CompassService {
  late final _controller = StreamController<CompassReading>.broadcast(
    onListen: () => listenCount++,
    onCancel: () => cancelCount++,
  );

  int listenCount = 0;
  int cancelCount = 0;

  @override
  Future<bool> hasSensors() async => true;

  @override
  Stream<CompassReading> readings() => _controller.stream;

  Future<void> close() async {
    await _controller.close();
  }
}
