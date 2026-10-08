import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';

void main() {
  test('periodic frequency is clamped to Android minimum', () {
    expect(
      normalizeCloudSyncFrequency(const Duration(minutes: 1)),
      const Duration(minutes: 15),
    );
    expect(
      normalizeCloudSyncFrequency(const Duration(hours: 1)),
      const Duration(hours: 1),
    );
  });
}
