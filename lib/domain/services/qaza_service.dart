import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../entities/qaza_progress.dart';
import '../entities/qaza_record.dart';
import '../repositories/qaza_repository.dart';
import 'qaza_availability_service.dart';

export '../entities/qaza_progress.dart';
export '../repositories/qaza_repository.dart' show QazaHistoryPage, QazaPage;
export 'qaza_availability_service.dart' show QazaAvailabilityAnalysis, QazaEligibility, QazaPrayerKey;

class QazaService {
  QazaService(this.repository, {QazaAvailabilityService? availability}) : availability = availability ?? const QazaAvailabilityService();
  final QazaRepository repository;
  final QazaAvailabilityService availability;

  Future<List<QazaRecord>> getRecords({required String userId, PrayerType? prayerType, QazaStatus? status}) => repository.getRecords(userId: userId, prayerType: prayerType, status: status);
  Future<QazaPage> getPage({required String userId, int limit = 50, PrayerType? prayerType, QazaStatus? status, DateTime? afterOriginalDate, String? afterId}) => repository.getPage(userId: userId, limit: limit, prayerType: prayerType, status: status, afterOriginalDate: afterOriginalDate, afterId: afterId);
  Future<QazaRecord?> oldestPending({required String userId, required PrayerType prayerType}) => repository.getOldestPending(userId: userId, prayerType: prayerType);
  Future<QazaHistoryPage> getHistoryPage({required String userId, int limit = 50, PrayerType? prayerType, QazaStatus? status = QazaStatus.completed, DateTime? from, DateTime? to, DateTime? beforeOriginalDate, String? beforeId}) => repository.getHistoryPage(userId: userId, limit: limit, prayerType: prayerType, status: status, from: from, to: to, beforeOriginalDate: beforeOriginalDate, beforeId: beforeId);
  Future<QazaProgressSummary> getProgressSummary({required String userId}) => repository.getProgressSummary(userId: userId);
  Future<List<QazaRecord>> getPendingForUser({required String userId}) => getRecords(userId: userId, status: QazaStatus.pending);
  Future<List<QazaRecord>> getPendingForPrayer({required String userId, required PrayerType prayerType}) => getRecords(userId: userId, prayerType: prayerType, status: QazaStatus.pending);

  Future<List<QazaRecord>> _getExistingForAvailability({required String userId, required Iterable<DateTime> dates, required Iterable<PrayerType> prayerTypes}) async {
    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final selectedPrayers = prayerTypes.toSet();
    if (normalizedDates.isEmpty || selectedPrayers.isEmpty) return const [];
    final sortedDates = normalizedDates.toList()..sort();
    final result = <QazaRecord>[];
    for (final prayer in selectedPrayers) {
      DateTime? beforeDate;
      String? beforeId;
      while (true) {
        final page = await repository.getHistoryPage(userId: userId, limit: 500, prayerType: prayer, status: null, from: sortedDates.first, to: sortedDates.last, beforeOriginalDate: beforeDate, beforeId: beforeId);
        result.addAll(page.records);
        if (!page.hasMore) break;
        beforeDate = page.nextOriginalDate;
        beforeId = page.nextId;
      }
    }
    return result;
  }

  Future<QazaAvailabilityAnalysis> analyzeAvailability({required String userId, required Iterable<DateTime> dates, required Iterable<PrayerType> prayerTypes, Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{}}) async {
    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final selectedPrayers = prayerTypes.toSet();
    final existing = await _getExistingForAvailability(userId: userId, dates: normalizedDates, prayerTypes: selectedPrayers);
    return availability.analyze(userId: userId, dates: normalizedDates, prayerTypes: selectedPrayers, existingRecords: existing, prayedKeys: prayedKeys);
  }

  /// Returns the prayers still eligible on each requested date. Reads remain bounded to the requested dates.
  Future<Map<DateTime, Set<PrayerType>>> getAvailablePrayersByDate({required String userId, required Iterable<DateTime> dates, Iterable<PrayerType> prayerTypes = PrayerType.values, Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{}}) async {
    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final selectedPrayers = prayerTypes.toSet();
    if (normalizedDates.isEmpty || selectedPrayers.isEmpty) return const {};
    final existing = await _getExistingForAvailability(userId: userId, dates: normalizedDates, prayerTypes: selectedPrayers);
    final recorded = availability.recordedKeys(existing);
    final result = <DateTime, Set<PrayerType>>{};
    for (final date in normalizedDates) {
      final available = <PrayerType>{};
      for (final prayer in selectedPrayers) {
        final key = QazaPrayerKey(userId: userId, date: date, prayerType: prayer);
        if (!prayedKeys.contains(key) && !recorded.contains(key)) available.add(prayer);
      }
      result[date] = Set.unmodifiable(available);
    }
    return Map.unmodifiable(result);
  }

  Future<void> addRecords(List<QazaRecord> records) => repository.addRecords(records);
  Future<void> completeRecord({required String userId, required String recordId, required DateTime completedAt}) => repository.completeRecord(userId: userId, recordId: recordId, completedAt: completedAt);
  Future<void> completeRecords({required String userId, required List<String> recordIds, required DateTime completedAt}) => repository.completeRecords(userId: userId, recordIds: recordIds, completedAt: completedAt);
  Future<void> recordQaza({required String userId, required PrayerType prayerType, required DateTime originalDate}) => recordQazaForDates(userId: userId, dates: [originalDate], prayerTypes: [prayerType]);

  Future<void> recordQazaForDates({required String userId, required Iterable<DateTime> dates, required Iterable<PrayerType> prayerTypes, Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{}}) async {
    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final selectedPrayers = prayerTypes.toSet();
    if (normalizedDates.isEmpty || selectedPrayers.isEmpty) return;
    final existing = await _getExistingForAvailability(userId: userId, dates: normalizedDates, prayerTypes: selectedPrayers);
    final analysis = availability.analyze(userId: userId, dates: normalizedDates, prayerTypes: selectedPrayers, existingRecords: existing, prayedKeys: prayedKeys);
    if (analysis.newCandidates.isEmpty) return;
    final now = DateTime.now();
    await repository.addRecords([for (final candidate in analysis.newCandidates) QazaRecord(id: candidate.value, userId: userId, prayerType: candidate.prayerType, originalDate: candidate.date, status: QazaStatus.pending, createdAt: now, updatedAt: now)]);
  }

  Future<bool> completeOldestPending({required String userId, required PrayerType prayerType, DateTime? completedAt}) async {
    final record = await oldestPending(userId: userId, prayerType: prayerType);
    if (record == null) return false;
    await completeRecord(userId: userId, recordId: record.id, completedAt: completedAt ?? DateTime.now());
    return true;
  }

  Future<int> completeSelected({required String userId, required List<String> recordIds, DateTime? completedAt}) async {
    final remaining = recordIds.toSet();
    if (remaining.isEmpty) return 0;
    final valid = <String>[];
    DateTime? afterDate;
    String? afterId;
    while (remaining.isNotEmpty) {
      final page = await repository.getPage(userId: userId, limit: 500, status: QazaStatus.pending, afterOriginalDate: afterDate, afterId: afterId);
      for (final record in page.records) { if (remaining.remove(record.id)) valid.add(record.id); }
      if (!page.hasMore) break;
      afterDate = page.nextOriginalDate;
      afterId = page.nextId;
    }
    if (valid.isEmpty) return 0;
    await completeRecords(userId: userId, recordIds: valid, completedAt: completedAt ?? DateTime.now());
    return valid.length;
  }

  Future<QazaProgress> overallProgress(String userId) async => (await getProgressSummary(userId: userId)).overall;
  Future<PrayerProgress> prayerProgress(String userId, PrayerType prayerType) async => (await getProgressSummary(userId: userId)).byPrayer[prayerType] ?? PrayerProgress(prayerType: prayerType, progress: const QazaProgress(pending: 0, completed: 0));

  static List<QazaRecord> completedNewestFirst(Iterable<QazaRecord> records) {
    final completed = records.where((record) => record.status == QazaStatus.completed).toList();
    completed.sort((a, b) => (b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return completed;
  }

  Future<List<QazaRecord>> history(String userId) async {
    final result = <QazaRecord>[];
    DateTime? date;
    String? id;
    while (true) {
      final page = await getHistoryPage(userId: userId, limit: 500, status: QazaStatus.completed, beforeOriginalDate: date, beforeId: id);
      result.addAll(page.records);
      if (!page.hasMore) return result;
      date = page.nextOriginalDate;
      id = page.nextId;
    }
  }

  static QazaProgress progressOf(Iterable<QazaRecord> records) {
    var completed = 0;
    var total = 0;
    for (final record in records) { total++; if (record.status == QazaStatus.completed) completed++; }
    return QazaProgress(pending: total - completed < 0 ? 0 : total - completed, completed: completed);
  }
}
