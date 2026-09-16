import '../../core/constants/prayer_types.dart';
import '../../domain/entities/qaza_history_page.dart';
import '../../domain/repositories/qaza_repository.dart';
import '../local/qaza_local_store.dart';
import '../sync/sync_state.dart';
import 'offline_first_qaza_repository.dart';

/// Offline-first repository variant whose history browser uses the local
/// database query directly instead of slicing the in-memory ledger.
class PaginatedOfflineFirstQazaRepository extends OfflineFirstQazaRepository {
  PaginatedOfflineFirstQazaRepository({
    required QazaRepository remote,
    required QazaLocalStore localStore,
    Stream<bool>? connectivityChanges,
    DateTime Function()? now,
  })  : _historyStore = localStore,
        super(
          remote: remote,
          localStore: localStore,
          connectivityChanges: connectivityChanges,
          now: now,
        );

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
    if (userId != activeUserId) {
      return Future.value(const QazaHistoryPage(records: []));
    }
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

  @override
  Future<void> dispose() async {
    await super.dispose();
    final store = _historyStore;
    if (store is SqliteQazaLocalStore) {
      await store.close();
    }
  }
}
