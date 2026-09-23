// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $QazaRecordsTable extends QazaRecords
    with TableInfo<$QazaRecordsTable, QazaRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QazaRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationIdMeta =
      const VerificationMeta('operationId');
  @override
  late final GeneratedColumn<String> operationId = GeneratedColumn<String>(
      'operation_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _prayerTypeMeta =
      const VerificationMeta('prayerType');
  @override
  late final GeneratedColumn<String> prayerType = GeneratedColumn<String>(
      'prayer_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _originalDateMeta =
      const VerificationMeta('originalDate');
  @override
  late final GeneratedColumn<DateTime> originalDate = GeneratedColumn<DateTime>(
      'original_date', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        operationId,
        prayerType,
        originalDate,
        status,
        completedAt,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'qaza_records';
  @override
  VerificationContext validateIntegrity(Insertable<QazaRecordRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('operation_id')) {
      context.handle(
          _operationIdMeta,
          operationId.isAcceptableOrUnknown(
              data['operation_id']!, _operationIdMeta));
    }
    if (data.containsKey('prayer_type')) {
      context.handle(
          _prayerTypeMeta,
          prayerType.isAcceptableOrUnknown(
              data['prayer_type']!, _prayerTypeMeta));
    } else if (isInserting) {
      context.missing(_prayerTypeMeta);
    }
    if (data.containsKey('original_date')) {
      context.handle(
          _originalDateMeta,
          originalDate.isAcceptableOrUnknown(
              data['original_date']!, _originalDateMeta));
    } else if (isInserting) {
      context.missing(_originalDateMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {userId, prayerType, originalDate},
      ];
  @override
  QazaRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QazaRecordRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      operationId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation_id']),
      prayerType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}prayer_type'])!,
      originalDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}original_date'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $QazaRecordsTable createAlias(String alias) {
    return $QazaRecordsTable(attachedDatabase, alias);
  }
}

class QazaRecordRow extends DataClass implements Insertable<QazaRecordRow> {
  final String id;
  final String userId;
  final String? operationId;
  final String prayerType;
  final DateTime originalDate;
  final String status;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const QazaRecordRow(
      {required this.id,
      required this.userId,
      this.operationId,
      required this.prayerType,
      required this.originalDate,
      required this.status,
      this.completedAt,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    if (!nullToAbsent || operationId != null) {
      map['operation_id'] = Variable<String>(operationId);
    }
    map['prayer_type'] = Variable<String>(prayerType);
    map['original_date'] = Variable<DateTime>(originalDate);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  QazaRecordsCompanion toCompanion(bool nullToAbsent) {
    return QazaRecordsCompanion(
      id: Value(id),
      userId: Value(userId),
      operationId: operationId == null && nullToAbsent
          ? const Value.absent()
          : Value(operationId),
      prayerType: Value(prayerType),
      originalDate: Value(originalDate),
      status: Value(status),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory QazaRecordRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QazaRecordRow(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      operationId: serializer.fromJson<String?>(json['operationId']),
      prayerType: serializer.fromJson<String>(json['prayerType']),
      originalDate: serializer.fromJson<DateTime>(json['originalDate']),
      status: serializer.fromJson<String>(json['status']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'operationId': serializer.toJson<String?>(operationId),
      'prayerType': serializer.toJson<String>(prayerType),
      'originalDate': serializer.toJson<DateTime>(originalDate),
      'status': serializer.toJson<String>(status),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  QazaRecordRow copyWith(
          {String? id,
          String? userId,
          Value<String?> operationId = const Value.absent(),
          String? prayerType,
          DateTime? originalDate,
          String? status,
          Value<DateTime?> completedAt = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      QazaRecordRow(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        operationId: operationId.present ? operationId.value : this.operationId,
        prayerType: prayerType ?? this.prayerType,
        originalDate: originalDate ?? this.originalDate,
        status: status ?? this.status,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  QazaRecordRow copyWithCompanion(QazaRecordsCompanion data) {
    return QazaRecordRow(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      operationId: data.operationId.present ? data.operationId.value : this.operationId,
      prayerType:
          data.prayerType.present ? data.prayerType.value : this.prayerType,
      originalDate: data.originalDate.present
          ? data.originalDate.value
          : this.originalDate,
      status: data.status.present ? data.status.value : this.status,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QazaRecordRow(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('operationId: $operationId, ')
          ..write('prayerType: $prayerType, ')
          ..write('originalDate: $originalDate, ')
          ..write('status: $status, ')
          ..write('completedAt: $completedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, operationId, prayerType,
      originalDate, status, completedAt, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QazaRecordRow &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.operationId == this.operationId &&
          other.prayerType == this.prayerType &&
          other.originalDate == this.originalDate &&
          other.status == this.status &&
          other.completedAt == this.completedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class QazaRecordsCompanion extends UpdateCompanion<QazaRecordRow> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String?> operationId;
  final Value<String> prayerType;
  final Value<DateTime> originalDate;
  final Value<String> status;
  final Value<DateTime?> completedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const QazaRecordsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.operationId = const Value.absent(),
    this.prayerType = const Value.absent(),
    this.originalDate = const Value.absent(),
    this.status = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QazaRecordsCompanion.insert({
    required String id,
    required String userId,
    Value<String?> operationId = const Value.absent(),
    required String prayerType,
    required DateTime originalDate,
    required String status,
    this.completedAt = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        operationId = operationId,
        prayerType = Value(prayerType),
        originalDate = Value(originalDate),
        status = Value(status),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<QazaRecordRow> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? operationId,
    Expression<String>? prayerType,
    Expression<DateTime>? originalDate,
    Expression<String>? status,
    Expression<DateTime>? completedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (operationId != null) 'operation_id': operationId,
      if (prayerType != null) 'prayer_type': prayerType,
      if (originalDate != null) 'original_date': originalDate,
      if (status != null) 'status': status,
      if (completedAt != null) 'completed_at': completedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QazaRecordsCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String?>? operationId,
      Value<String>? prayerType,
      Value<DateTime>? originalDate,
      Value<String>? status,
      Value<DateTime?>? completedAt,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return QazaRecordsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      operationId: operationId ?? this.operationId,
      prayerType: prayerType ?? this.prayerType,
      originalDate: originalDate ?? this.originalDate,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (operationId.present) {
      map['operation_id'] = Variable<String>(operationId.value);
    }
    if (prayerType.present) {
      map['prayer_type'] = Variable<String>(prayerType.value);
    }
    if (originalDate.present) {
      map['original_date'] = Variable<DateTime>(originalDate.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QazaRecordsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('operationId: $operationId, ')
          ..write('prayerType: $prayerType, ')
          ..write('originalDate: $originalDate, ')
          ..write('status: $status, ')
          ..write('completedAt: $completedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, SyncOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _queuedAtMeta =
      const VerificationMeta('queuedAt');
  @override
  late final GeneratedColumn<DateTime> queuedAt = GeneratedColumn<DateTime>(
      'queued_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _recordJsonMeta =
      const VerificationMeta('recordJson');
  @override
  late final GeneratedColumn<String> recordJson = GeneratedColumn<String>(
      'record_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _targetRecordIdMeta =
      const VerificationMeta('targetRecordId');
  @override
  late final GeneratedColumn<String> targetRecordId = GeneratedColumn<String>(
      'target_record_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _attemptsMeta =
      const VerificationMeta('attempts');
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
      'attempts', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        type,
        queuedAt,
        recordJson,
        targetRecordId,
        completedAt,
        attempts,
        lastError
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(Insertable<SyncOutboxData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('queued_at')) {
      context.handle(_queuedAtMeta,
          queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta));
    } else if (isInserting) {
      context.missing(_queuedAtMeta);
    }
    if (data.containsKey('record_json')) {
      context.handle(
          _recordJsonMeta,
          recordJson.isAcceptableOrUnknown(
              data['record_json']!, _recordJsonMeta));
    }
    if (data.containsKey('target_record_id')) {
      context.handle(
          _targetRecordIdMeta,
          targetRecordId.isAcceptableOrUnknown(
              data['target_record_id']!, _targetRecordIdMeta));
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    if (data.containsKey('attempts')) {
      context.handle(_attemptsMeta,
          attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      queuedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}queued_at'])!,
      recordJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}record_json']),
      targetRecordId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}target_record_id']),
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
      attempts: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}attempts'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class SyncOutboxData extends DataClass implements Insertable<SyncOutboxData> {
  final String id;
  final String userId;
  final String type;
  final DateTime queuedAt;
  final String? recordJson;
  final String? targetRecordId;
  final DateTime? completedAt;
  final int attempts;
  final String? lastError;
  const SyncOutboxData(
      {required this.id,
      required this.userId,
      required this.type,
      required this.queuedAt,
      this.recordJson,
      this.targetRecordId,
      this.completedAt,
      required this.attempts,
      this.lastError});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['type'] = Variable<String>(type);
    map['queued_at'] = Variable<DateTime>(queuedAt);
    if (!nullToAbsent || recordJson != null) {
      map['record_json'] = Variable<String>(recordJson);
    }
    if (!nullToAbsent || targetRecordId != null) {
      map['target_record_id'] = Variable<String>(targetRecordId);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['attempts'] = Variable<int>(attempts);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      id: Value(id),
      userId: Value(userId),
      type: Value(type),
      queuedAt: Value(queuedAt),
      recordJson: recordJson == null && nullToAbsent
          ? const Value.absent()
          : Value(recordJson),
      targetRecordId: targetRecordId == null && nullToAbsent
          ? const Value.absent()
          : Value(targetRecordId),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      attempts: Value(attempts),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory SyncOutboxData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      type: serializer.fromJson<String>(json['type']),
      queuedAt: serializer.fromJson<DateTime>(json['queuedAt']),
      recordJson: serializer.fromJson<String?>(json['recordJson']),
      targetRecordId: serializer.fromJson<String?>(json['targetRecordId']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'type': serializer.toJson<String>(type),
      'queuedAt': serializer.toJson<DateTime>(queuedAt),
      'recordJson': serializer.toJson<String?>(recordJson),
      'targetRecordId': serializer.toJson<String?>(targetRecordId),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'attempts': serializer.toJson<int>(attempts),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  SyncOutboxData copyWith(
          {String? id,
          String? userId,
          String? type,
          DateTime? queuedAt,
          Value<String?> recordJson = const Value.absent(),
          Value<String?> targetRecordId = const Value.absent(),
          Value<DateTime?> completedAt = const Value.absent(),
          int? attempts,
          Value<String?> lastError = const Value.absent()}) =>
      SyncOutboxData(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        type: type ?? this.type,
        queuedAt: queuedAt ?? this.queuedAt,
        recordJson: recordJson.present ? recordJson.value : this.recordJson,
        targetRecordId:
            targetRecordId.present ? targetRecordId.value : this.targetRecordId,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        attempts: attempts ?? this.attempts,
        lastError: lastError.present ? lastError.value : this.lastError,
      );
  SyncOutboxData copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      type: data.type.present ? data.type.value : this.type,
      queuedAt: data.queuedAt.present ? data.queuedAt.value : this.queuedAt,
      recordJson:
          data.recordJson.present ? data.recordJson.value : this.recordJson,
      targetRecordId: data.targetRecordId.present
          ? data.targetRecordId.value
          : this.targetRecordId,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('recordJson: $recordJson, ')
          ..write('targetRecordId: $targetRecordId, ')
          ..write('completedAt: $completedAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, type, queuedAt, recordJson,
      targetRecordId, completedAt, attempts, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.type == this.type &&
          other.queuedAt == this.queuedAt &&
          other.recordJson == this.recordJson &&
          other.targetRecordId == this.targetRecordId &&
          other.completedAt == this.completedAt &&
          other.attempts == this.attempts &&
          other.lastError == this.lastError);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> type;
  final Value<DateTime> queuedAt;
  final Value<String?> recordJson;
  final Value<String?> targetRecordId;
  final Value<DateTime?> completedAt;
  final Value<int> attempts;
  final Value<String?> lastError;
  final Value<int> rowid;
  const SyncOutboxCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.type = const Value.absent(),
    this.queuedAt = const Value.absent(),
    this.recordJson = const Value.absent(),
    this.targetRecordId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    required String id,
    required String userId,
    required String type,
    required DateTime queuedAt,
    this.recordJson = const Value.absent(),
    this.targetRecordId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.attempts = const Value.absent(),
    this.lastError = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        type = Value(type),
        queuedAt = Value(queuedAt);
  static Insertable<SyncOutboxData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? type,
    Expression<DateTime>? queuedAt,
    Expression<String>? recordJson,
    Expression<String>? targetRecordId,
    Expression<DateTime>? completedAt,
    Expression<int>? attempts,
    Expression<String>? lastError,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (type != null) 'type': type,
      if (queuedAt != null) 'queued_at': queuedAt,
      if (recordJson != null) 'record_json': recordJson,
      if (targetRecordId != null) 'target_record_id': targetRecordId,
      if (completedAt != null) 'completed_at': completedAt,
      if (attempts != null) 'attempts': attempts,
      if (lastError != null) 'last_error': lastError,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String>? type,
      Value<DateTime>? queuedAt,
      Value<String?>? recordJson,
      Value<String?>? targetRecordId,
      Value<DateTime?>? completedAt,
      Value<int>? attempts,
      Value<String?>? lastError,
      Value<int>? rowid}) {
    return SyncOutboxCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      queuedAt: queuedAt ?? this.queuedAt,
      recordJson: recordJson ?? this.recordJson,
      targetRecordId: targetRecordId ?? this.targetRecordId,
      completedAt: completedAt ?? this.completedAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<DateTime>(queuedAt.value);
    }
    if (recordJson.present) {
      map['record_json'] = Variable<String>(recordJson.value);
    }
    if (targetRecordId.present) {
      map['target_record_id'] = Variable<String>(targetRecordId.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('type: $type, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('recordJson: $recordJson, ')
          ..write('targetRecordId: $targetRecordId, ')
          ..write('completedAt: $completedAt, ')
          ..write('attempts: $attempts, ')
          ..write('lastError: $lastError, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $QazaRecordsTable qazaRecords = $QazaRecordsTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final QazaRecordsDao qazaRecordsDao =
      QazaRecordsDao(this as AppDatabase);
  late final SyncOutboxDao syncOutboxDao = SyncOutboxDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [qazaRecords, syncOutbox];
}

typedef $$QazaRecordsTableCreateCompanionBuilder = QazaRecordsCompanion
    Function({
  required String id,
  required String userId,
  Value<String?> operationId,
  required String prayerType,
  required DateTime originalDate,
  required String status,
  Value<DateTime?> completedAt,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$QazaRecordsTableUpdateCompanionBuilder = QazaRecordsCompanion
    Function({
  Value<String> id,
  Value<String> userId,
  Value<String?> operationId,
  Value<String> prayerType,
  Value<DateTime> originalDate,
  Value<String> status,
  Value<DateTime?> completedAt,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$QazaRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $QazaRecordsTable> {
  $$QazaRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get prayerType => $composableBuilder(
      column: $table.prayerType, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get originalDate => $composableBuilder(
      column: $table.originalDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$QazaRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $QazaRecordsTable> {
  $$QazaRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operationId => $composableBuilder(
      column: $table.operationId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get prayerType => $composableBuilder(
      column: $table.prayerType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get originalDate => $composableBuilder(
      column: $table.originalDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$QazaRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QazaRecordsTable> {
  $$QazaRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get operationId =>
      $composableBuilder(column: $table.operationId, builder: (column) => column);

  GeneratedColumn<String> get prayerType => $composableBuilder(
      column: $table.prayerType, builder: (column) => column);

  GeneratedColumn<DateTime> get originalDate => $composableBuilder(
      column: $table.originalDate, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$QazaRecordsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $QazaRecordsTable,
    QazaRecordRow,
    $$QazaRecordsTableFilterComposer,
    $$QazaRecordsTableOrderingComposer,
    $$QazaRecordsTableAnnotationComposer,
    $$QazaRecordsTableCreateCompanionBuilder,
    $$QazaRecordsTableUpdateCompanionBuilder,
    (
      QazaRecordRow,
      BaseReferences<_$AppDatabase, $QazaRecordsTable, QazaRecordRow>
    ),
    QazaRecordRow,
    PrefetchHooks Function()> {
  $$QazaRecordsTableTableManager(_$AppDatabase db, $QazaRecordsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QazaRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QazaRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QazaRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String?> operationId = const Value.absent(),
            Value<String> prayerType = const Value.absent(),
            Value<DateTime> originalDate = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              QazaRecordsCompanion(
            id: id,
            userId: userId,
            operationId: operationId,
            prayerType: prayerType,
            originalDate: originalDate,
            status: status,
            completedAt: completedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            Value<String?> operationId = const Value.absent(),
            required String prayerType,
            required DateTime originalDate,
            required String status,
            Value<DateTime?> completedAt = const Value.absent(),
            required DateTime createdAt,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              QazaRecordsCompanion.insert(
            id: id,
            userId: userId,
            operationId: operationId,
            prayerType: prayerType,
            originalDate: originalDate,
            status: status,
            completedAt: completedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$QazaRecordsTable, QazaRecordRow>(table),
                    BaseReferences<_$AppDatabase, $QazaRecordsTable,
                        QazaRecordRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$QazaRecordsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $QazaRecordsTable,
    QazaRecordRow,
    $$QazaRecordsTableFilterComposer,
    $$QazaRecordsTableOrderingComposer,
    $$QazaRecordsTableAnnotationComposer,
    $$QazaRecordsTableCreateCompanionBuilder,
    $$QazaRecordsTableUpdateCompanionBuilder,
    (
      QazaRecordRow,
      BaseReferences<_$AppDatabase, $QazaRecordsTable, QazaRecordRow>
    ),
    QazaRecordRow,
    PrefetchHooks Function()>;
typedef $$SyncOutboxTableCreateCompanionBuilder = SyncOutboxCompanion Function({
  required String id,
  required String userId,
  required String type,
  required DateTime queuedAt,
  Value<String?> recordJson,
  Value<String?> targetRecordId,
  Value<DateTime?> completedAt,
  Value<int> attempts,
  Value<String?> lastError,
  Value<int> rowid,
});
typedef $$SyncOutboxTableUpdateCompanionBuilder = SyncOutboxCompanion Function({
  Value<String> id,
  Value<String> userId,
  Value<String> type,
  Value<DateTime> queuedAt,
  Value<String?> recordJson,
  Value<String?> targetRecordId,
  Value<DateTime?> completedAt,
  Value<int> attempts,
  Value<String?> lastError,
  Value<int> rowid,
});

class $$SyncOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get queuedAt => $composableBuilder(
      column: $table.queuedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recordJson => $composableBuilder(
      column: $table.recordJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetRecordId => $composableBuilder(
      column: $table.targetRecordId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get queuedAt => $composableBuilder(
      column: $table.queuedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recordJson => $composableBuilder(
      column: $table.recordJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetRecordId => $composableBuilder(
      column: $table.targetRecordId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get attempts => $composableBuilder(
      column: $table.attempts, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get queuedAt =>
      $composableBuilder(column: $table.queuedAt, builder: (column) => column);

  GeneratedColumn<String> get recordJson => $composableBuilder(
      column: $table.recordJson, builder: (column) => column);

  GeneratedColumn<String> get targetRecordId => $composableBuilder(
      column: $table.targetRecordId, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$SyncOutboxTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncOutboxTable,
    SyncOutboxData,
    $$SyncOutboxTableFilterComposer,
    $$SyncOutboxTableOrderingComposer,
    $$SyncOutboxTableAnnotationComposer,
    $$SyncOutboxTableCreateCompanionBuilder,
    $$SyncOutboxTableUpdateCompanionBuilder,
    (
      SyncOutboxData,
      BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxData>
    ),
    SyncOutboxData,
    PrefetchHooks Function()> {
  $$SyncOutboxTableTableManager(_$AppDatabase db, $SyncOutboxTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<DateTime> queuedAt = const Value.absent(),
            Value<String?> recordJson = const Value.absent(),
            Value<String?> targetRecordId = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncOutboxCompanion(
            id: id,
            userId: userId,
            type: type,
            queuedAt: queuedAt,
            recordJson: recordJson,
            targetRecordId: targetRecordId,
            completedAt: completedAt,
            attempts: attempts,
            lastError: lastError,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required String type,
            required DateTime queuedAt,
            Value<String?> recordJson = const Value.absent(),
            Value<String?> targetRecordId = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<int> attempts = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncOutboxCompanion.insert(
            id: id,
            userId: userId,
            type: type,
            queuedAt: queuedAt,
            recordJson: recordJson,
            targetRecordId: targetRecordId,
            completedAt: completedAt,
            attempts: attempts,
            lastError: lastError,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SyncOutboxTable, SyncOutboxData>(table),
                    BaseReferences<_$AppDatabase, $SyncOutboxTable,
                        SyncOutboxData>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncOutboxTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncOutboxTable,
    SyncOutboxData,
    $$SyncOutboxTableFilterComposer,
    $$SyncOutboxTableOrderingComposer,
    $$SyncOutboxTableAnnotationComposer,
    $$SyncOutboxTableCreateCompanionBuilder,
    $$SyncOutboxTableUpdateCompanionBuilder,
    (
      SyncOutboxData,
      BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxData>
    ),
    SyncOutboxData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$QazaRecordsTableTableManager get qazaRecords =>
      $$QazaRecordsTableTableManager(_db, _db.qazaRecords);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
}
