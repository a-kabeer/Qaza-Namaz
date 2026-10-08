import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/domain/services/conflict_resolver.dart';

void main() {
  const resolver = ConflictResolver();

  VersionedEntity entity({
    required int version,
    required String updatedAt,
    required String writer,
    required String operation,
    required String id,
  }) =>
      VersionedEntity(
        entityVersion: version,
        updatedAt: DateTime.parse(updatedAt),
        writerDeviceId: writer,
        operationId: operation,
        entityId: id,
      );

  test('higher entity version wins', () {
    final a = entity(
      version: 2,
      updatedAt: '2026-10-04T00:00:00Z',
      writer: 'a',
      operation: 'a',
      id: 'x',
    );
    final b = entity(
      version: 1,
      updatedAt: '2027-10-04T00:00:00Z',
      writer: 'z',
      operation: 'z',
      id: 'x',
    );
    expect(resolver.winner(a, b), same(a));
  });

  test('equal version uses deterministic tie-breakers', () {
    final a = entity(
      version: 5,
      updatedAt: '2026-10-04T00:00:00Z',
      writer: 'device-a',
      operation: 'op-a',
      id: 'x',
    );
    final b = entity(
      version: 5,
      updatedAt: '2026-10-04T00:00:00Z',
      writer: 'device-b',
      operation: 'op-a',
      id: 'x',
    );
    expect(resolver.compare(a, b), lessThan(0));
    expect(resolver.winner(a, b), same(b));
  });

  test('comparison is antisymmetric for distinct states', () {
    final a = entity(
      version: 1,
      updatedAt: '2026-10-04T00:00:00Z',
      writer: 'device-a',
      operation: 'op-a',
      id: 'a',
    );
    final b = entity(
      version: 1,
      updatedAt: '2026-10-04T00:00:00Z',
      writer: 'device-a',
      operation: 'op-a',
      id: 'b',
    );
    expect(resolver.compare(a, b), -resolver.compare(b, a));
  });
}
