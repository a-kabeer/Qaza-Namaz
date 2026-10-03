class VersionedEntity {
  const VersionedEntity({
    required this.entityVersion,
    required this.updatedAt,
    required this.writerDeviceId,
    required this.operationId,
    required this.entityId,
  });

  final int entityVersion;
  final DateTime updatedAt;
  final String writerDeviceId;
  final String operationId;
  final String entityId;
}

class ConflictResolver {
  const ConflictResolver();

  int compare(VersionedEntity a, VersionedEntity b) {
    var result = a.entityVersion.compareTo(b.entityVersion);
    if (result != 0) return result;

    result = a.updatedAt.compareTo(b.updatedAt);
    if (result != 0) return result;

    result = a.writerDeviceId.compareTo(b.writerDeviceId);
    if (result != 0) return result;

    result = a.operationId.compareTo(b.operationId);
    if (result != 0) return result;

    return a.entityId.compareTo(b.entityId);
  }

  VersionedEntity winner(VersionedEntity a, VersionedEntity b) =>
      compare(a, b) >= 0 ? a : b;
}
