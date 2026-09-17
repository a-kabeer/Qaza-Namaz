import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Application-local SQLite database foundation.
///
/// Part 1 intentionally contains no production tables yet. Part 2 will add
/// the normalized Qaza schema and migration steps. Keeping the database
/// lifecycle separate from the domain/repository layer lets us introduce
/// SQLite without changing application behaviour in this part.
@DriftDatabase(tables: [])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'qaza_namaz'));

  @override
  int get schemaVersion => 1;
}
