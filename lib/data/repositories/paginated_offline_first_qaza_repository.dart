import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_history_page.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../local/qaza_local_store.dart';
import '../local/sqlite_qaza_local_store.dart';
import 'offline_first_qaza_repository.dart';

class PaginatedOfflineFirstQazaRepository extends OfflineFirstQazaRepository {
  PaginatedOfflineFirstQazaRepository({
    required QazaRepository remote,
    required QazaLocalStore localStore,
    Stream<bool>? connectivityChanges,
    DateTime Function()? now,
  })  : _historyStore = localStore,
        super(remote: remote, localStore: localStore, connectivityChanges: connectivityChanges, now: now);

  final QazaLocalStore _historyStore;

  @override
  Future<QazaHistoryPage> getHistoryPage({
    required String userId,
    PrayerType? prayerType,
    QazaStatus? status,
    DateTime? originalDateFrom,
    DateTime? originalDateTo,
    String? cursor,
    int limit = 25,
    bool ascending = false,
  }) {
    if (userId != activeUserId) return Future.value(const QazaHistoryPage(records: []));
    return _historyStore.getHistoryPage(
      userId: userId,
      prayerType: prayerType,
      status: status,
      originalDateFrom: originalDateFrom,
      originalDateTo: originalDateTo,
      cursor: cursor,
      limit: limit,
      ascending: ascending,
    );
  }

  Future<void> close() async {
    dispose();
    if (_historyStore is SqliteQazaLocalStore) {
      await (_historyStore as SqliteQazaLocalStore).close();
    }
  }
}
