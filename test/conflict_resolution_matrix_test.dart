import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/domain/services/conflict_resolver.dart';

void main() {
  const resolver = ConflictResolver();

  VersionedEntity entity({
    required int version,
    required String updatedAt,
    required String device,
    required String operation,
    required String id,
  }) =>
      VersionedEntity(
        entityVersion: version,
        updatedAt: DateTime.parse(updatedAt),
        writerDeviceId: device,
        operationId: operation,
        entityId: id,
      );

  test('equal metadata remains deterministic regardless of arrival order', () {
    final a = entity(
      version: 4,
      updatedAt: '2026-10-04T01:00:00Z',
      device: 'device-a',
      operation: 'op-a',
      id: 'record-a',
    );
    final b = entity(
      version: 4,
      updatedAt: '2026-10-04T01:00:00Z',
      device: 'device-b',
      operation: 'op-b',
      id: 'record-a',
    );

    final ab = resolver.winner(a, b);
    final ba = resolver.winner(b, a);

    expect(ab.entityId, ba.entityId);
    expect(ab.writerDeviceId, ba.writerDeviceId);
    expect(ab.operationId, ba.operationId);
  });

  test('updated time breaks equal-version ties before device id', () {
    final older = entity(
      version: 5,
      updatedAt: '2026-10-04T01:00:00Z',
      device: 'device-z',
      operation: 'op-z',
      id: 'x',
    );
    final newer = entity(
      version: 5,
      updatedAt: '2026-10-04T02:00:00Z',
      device: 'device-a',
      operation: 'op-a',
      id: 'x',
    );

    expect(resolver.winner(older, newer), same(newer));
  });

  test('operation id breaks equal version/time/device ties', () {
    final first = entity(
      version: 2,
      updatedAt: '2026-10-04T01:00:00Z',
      device: 'device-a',
      operation: 'op-a',
      id: 'x',
    );
    final second = entity(
      version: 2,
      updatedAt: '2026-10-04T01:00:00Z',
      device: 'device-a',
      operation: 'op-b',
      id: 'x',
    );

    expect(resolver.winner(first, second), same(second));
  });

  test('entity id is the final deterministic tie-breaker', () {
    final first = entity(
      version: 1,
      updatedAt: '2026-10-04T01:00:00Z',
      device: 'device-a',
      operation: 'op-a',
      id: 'a',
    );
    final second = entity(
      version: 1,
      updatedAt: '2026-10-04T01:00:00Z',
      device: 'device-a',
      operation: 'op-a',
      id: 'b',
    );

    expect(resolver.winner(first, second), same(second));
    expect(resolver.compare(first, second), isNegative);
    expect(resolver.compare(second, first), isPositive);
  });
}
