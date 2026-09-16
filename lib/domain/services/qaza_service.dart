import '../../core/constants/prayer_types.dart';
import '../../core/utils/qaza_date.dart';
import '../entities/qaza_progress.dart';
import '../entities/qaza_record.dart';
import '../repositories/qaza_repository.dart';
import 'qaza_availability_service.dart';

export '../entities/qaza_progress.dart';

class QazaService {
  QazaService(this.repository, {QazaAvailabilityService? availability}) : availability = availability ?? const QazaAvailabilityService();
  final QazaRepository repository;
  final QazaAvailabilityService availability;

  Future<List<QazaRecord>> getRecords({required String userId, PrayerType? prayerType, QazaStatus? status}) => repository.getRecords(userId: userId, prayerType: prayerType, status: status);
  Future<List<QazaRecord>> getPendingForUser({required String userId}) => getRecords(userId: userId, status: QazaStatus.pending);
  Future<List<QazaRecord>> getPendingForPrayer({required String userId, required PrayerType prayerType}) => getRecords(userId: userId, prayerType: prayerType, status: QazaStatus.pending);

  Future<QazaAvailabilityAnalysis> analyzeAvailability({required String userId, required Iterable<DateTime> dates, required Iterable<PrayerType> prayerTypes, Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{}}) async {
    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final existing = await repository.getRecordsForDates(userId: userId, dates: normalizedDates);
    return availability.analyze(userId: userId, dates: normalizedDates, prayerTypes: prayerTypes, existingRecords: existing, prayedKeys: prayedKeys);
  }

  Future<void> addRecords(List<QazaRecord> records) => repository.addRecords(records);
  Future<void> completeRecord({required String userId, required String recordId, required DateTime completedAt}) => repository.completeRecord(userId: userId, recordId: recordId, completedAt: completedAt);
  Future<void> completeRecords({required String userId, required List<String> recordIds, required DateTime completedAt}) => repository.completeRecords(userId: userId, recordIds: recordIds, completedAt: completedAt);

  Future<void> recordQaza({required String userId, required PrayerType prayerType, required DateTime originalDate}) => recordQazaForDates(userId: userId, dates: [originalDate], prayerTypes: [prayerType]);

  Future<void> recordQazaForDates({required String userId, required Iterable<DateTime> dates, required Iterable<PrayerType> prayerTypes, Set<QazaPrayerKey> prayedKeys = const <QazaPrayerKey>{}}) async {
    final normalizedDates = dates.map(QazaDate.normalize).toSet();
    final selectedPrayers = prayerTypes.toSet();
    if (normalizedDates.isEmpty || selectedPrayers.isEmpty) return;
    final existing = await repository.getRecordsForDates(userId: userId, dates: normalizedDates);
    final analysis = availability.analyze(userId: userId, dates: normalizedDates, prayerTypes: selectedPrayers, existingRecords: existing, prayedKeys: prayedKeys);
    if (analysis.newCandidates.isEmpty) return;
    final now = DateTime.now();
    await repository.addRecords([for (final candidate in analysis.newCandidates) QazaRecord(id: candidate.value, userId: userId, prayerType: candidate.prayerType, originalDate: candidate.date, createdAt: now, updatedAt: now)]);
  }

  Future<QazaRecord?> oldestPending({required String userId, required PrayerType prayerType}) async {
    final page = await repository.getHistoryPage(userId: userId, prayerType: prayerType, status: QazaStatus.pending, limit: 1, ascending: true);
    return page.records.isEmpty ? null : page.records.first;
  }

  Future<bool> completeOldestPending({required String userId, required PrayerType prayerType, DateTime? completedAt}) async {
    final record = await oldestPending(userId: userId, prayerType: prayerType);
    if (record == null) return false;
    await completeRecord(userId: userId, recordId: record.id, completedAt: completedAt ?? DateTime.now());
    return true;
  }

  Future<int> completeSelected({required String userId, required List<String> recordIds, DateTime? completedAt}) async {
    if (recordIds.isEmpty) return 0;
    final selected = recordIds.toSet();
    final records = await repository.getRecordsByIds(userId: userId, recordIds: selected);
    final validPendingIds = records.where((record) => selected.contains(record.id) && record.status == QazaStatus.pending).map((record) => record.id).toList(growable: false);
    if (validPendingIds.isEmpty) return 0;
    await completeRecords(userId: userId, recordIds: validPendingIds, completedAt: completedAt ?? DateTime.now());
    return validPendingIds.length;
  }

  Future<QazaProgress> overallProgress(String userId) async {
    final summary = await repository.getSummary(userId);
    return QazaProgress(pending: summary.pending, completed: summary.completed);
  }

  Future<PrayerProgress> prayerProgress(String userId, PrayerType prayerType) async {
    final summary = await repository.getSummary(userId);
    return PrayerProgress(prayerType: prayerType, progress: summary.byPrayer[prayerType] ?? const QazaProgress(pending: 0, completed: 0));
  }

  static List<QazaRecord> completedNewestFirst(Iterable<QazaRecord> records) {
    final completed = records.where((record) => record.status == QazaStatus.completed).toList();
    completed.sort((a, b) => (b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return completed;
  }

  Future<List<QazaRecord>> history(String userId) async => completedNewestFirst(await getRecords(userId: userId, status: QazaStatus.completed));

  static QazaProgress progressOf(Iterable<QazaRecord> records) {
    var completed = 0, total = 0;
    for (final record in records) { total++; if (record.status == QazaStatus.completed) completed++; }
    return QazaProgress(pending: total - completed < 0 ? 0 : total - completed, completed: completed);
  }

  QazaProgress _progress(List<QazaRecord> records) => progressOf(records);
}
