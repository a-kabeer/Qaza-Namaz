import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';

void main() {
  test('automatic backup supports Daily, Weekly and Monthly intervals', () {
    expect(
      normalizeCloudSyncFrequency(const Duration(days: 1)),
      const Duration(days: 1),
    );
    expect(
      normalizeCloudSyncFrequency(const Duration(days: 7)),
      const Duration(days: 7),
    );
    expect(
      normalizeCloudSyncFrequency(const Duration(days: 30)),
      const Duration(days: 30),
    );
  });

  test('unsupported custom intervals safely fall back to Daily', () {
    expect(
      normalizeCloudSyncFrequency(const Duration(minutes: 1)),
      const Duration(days: 1),
    );
    expect(
      normalizeCloudSyncFrequency(const Duration(hours: 1)),
      const Duration(days: 1),
    );
  });
}
