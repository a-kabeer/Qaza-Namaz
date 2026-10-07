import 'dart:convert';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/local_account.dart';
import '../../domain/entities/qaza_plan_revision.dart';
import '../../domain/entities/qaza_record.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/services/conflict_resolver.dart';
import 'database/app_database.dart';

class AccountLocalStore {
  AccountLocalStore({required this.database});

  final AppDatabase database;
  StreamController<BackupStatusSnapshot> _backupStatusController(
    String localAccountId,
  ) {
    return _backupStatusControllers.putIfAbsent(
      localAccountId,
      () => StreamController<BackupStatusSnapshot>.broadcast(
        onListen: () {
          unawaited(_emitInitialBackupStatus(localAccountId));
        },
      ),
    );
  }
