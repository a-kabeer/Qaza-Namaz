import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_cloud_adapter/qaza_cloud_adapter.dart';

void main() {
  test('automatic periodic sync is fixed to a daily interval', () {
    expect(
      normalizeCloudSyncFrequency(const Duration(minutes: 1)),
      const Duration(days: 1),
    );
    expect(
      normalizeCloudSyncFrequency(const Duration(hours: 1)),
      const Duration(days: 1),
    );
    expect(
      normalizeCloudSyncFrequency(const Duration(days: 1)),
      const Duration(days: 1),
    );
  });
}
