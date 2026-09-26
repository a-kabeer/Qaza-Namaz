import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/calendar/hijri_date_service.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../domain/entities/qaza_operation.dart';
import '../../../domain/entities/qaza_record.dart';
import '../../../domain/repositories/qaza_recovery_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/prayer_type_l10n.dart';
enum _HistorySection { recent, deleted }

class QazaHistoryScreen extends ConsumerStatefulWidget {
  const QazaHistoryScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  ConsumerState<QazaHistoryScreen> createState() => _QazaHistoryScreenState();
}

class _QazaHistoryScreenState extends ConsumerState<QazaHistoryScreen> {
  _HistorySection section = _HistorySection.recent;
  List<QazaOperation> operations = const [];
  List<QazaRecord> deleted = const [];
  final Map<String, Future<QazaOperationSummary>> _summaryFutures = {};
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = false;
  DateTime? cursorDate;
  String? cursorId;
  String? error;

  bool get _urdu => Localizations.localeOf(context).languageCode == 'ur';

  String _label(QazaOperationType type) => _urdu
      ? switch (type) {
          QazaOperationType.calculatorImport => 'کیلکولیٹر سے اضافہ',
          QazaOperationType.rangeAdd => 'تاریخ کی حد سے اضافہ',
          QazaOperationType.multipleDateAdd => 'متعدد تاریخوں سے اضافہ',
          QazaOperationType.singleDateAdd => 'ایک تاریخ سے اضافہ',
          QazaOperationType.manualAdd => 'ایک تاریخ سے اضافہ',
          QazaOperationType.bulkComplete => 'متعدد قضا مکمل',
          QazaOperationType.singleRecordDelete => 'ایک ریکارڈ حذف',
          QazaOperationType.bulkDelete => 'متعدد قضا حذف',
          QazaOperationType.restore => 'بحال',
        }
      : switch (type) {
          QazaOperationType.calculatorImport => 'Calculator import',
          QazaOperationType.rangeAdd => 'Date-range add',
          QazaOperationType.multipleDateAdd => 'Multiple-date add',
          QazaOperationType.singleDateAdd => 'Single-date add',
          QazaOperationType.manualAdd => 'Single-date add',
          QazaOperationType.bulkComplete => 'Bulk completion',
          QazaOperationType.singleRecordDelete => 'Single-record deletion',
          QazaOperationType.bulkDelete => 'Bulk deletion',
          QazaOperationType.restore => 'Restore',
        };

  String _statusLabel(QazaOperationStatus status) => _urdu
      ? switch (status) {
          QazaOperationStatus.running => 'جاری',
          QazaOperationStatus.completed => 'مکمل',
          QazaOperationStatus.partial => 'جزوی',
          QazaOperationStatus.undone => 'واپس کیا گیا',
          QazaOperationStatus.removed => 'ہٹا دیا گیا',
          QazaOperationStatus.failed => 'ناکام',
        }
      : switch (status) {
          QazaOperationStatus.running => 'Running',
          QazaOperationStatus.completed => 'Completed',
          QazaOperationStatus.partial => 'Partial',
          QazaOperationStatus.undone => 'Undone',
          QazaOperationStatus.removed => 'Removed',
          QazaOperationStatus.failed => 'Failed',
        };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
        cursorDate = null;
        cursorId = null;
        hasMore = false;
        operations = const [];
        deleted = const [];
        _summaryFutures.clear();
      });
    }

    try {
      final userId = ref.read(requiredUserIdProvider);
      final service = ref.read(qazaServiceProvider);

      await service.purgeDeletedBefore(
        userId: userId,
        cutoff: DateTime.now().subtract(const Duration(days: 30)),
      );

      if (section == _HistorySection.recent) {
        final loaded =
            await ref.read(qazaOperationServiceProvider).recent(userId);
        for (final operation in loaded) {
          _summaryFutures[operation.operationId] = service.getOperationSummary(
            userId: userId,
            operationId: operation.operationId,
          );
        }
        operations = loaded;
      } else {
        final page = await service.getRecentlyDeletedPage(
          userId: userId,
          limit: 50,
        );
        deleted = page.records;
        hasMore = page.hasMore;
        cursorDate = deleted.isEmpty ? null : deleted.last.updatedAt;
        cursorId = deleted.isEmpty ? null : deleted.last.id;
      }

      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.toString();
        });
      }
    }
  }

  Future<void> _loadMoreDeleted() async {
    if (loadingMore || !hasMore) return;
    setState(() => loadingMore = true);
    try {
      final page = await ref.read(qazaServiceProvider).getRecentlyDeletedPage(
            userId: ref.read(requiredUserIdProvider),
            limit: 50,
            beforeDeletedAt: cursorDate,
            beforeId: cursorId,
          );
      if (!mounted) return;
      setState(() {
        deleted = [...deleted, ...page.records];
        hasMore = page.hasMore;
        cursorDate = deleted.isEmpty ? null : deleted.last.updatedAt;
        cursorId = deleted.isEmpty ? null : deleted.last.id;
        loadingMore = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loadingMore = false;
          error = e.toString();
        });
      }
    }
  }

  Future<void> _restore(QazaRecord record) async {
    final operationService = ref.read(qazaOperationServiceProvider);
    final service = ref.read(qazaServiceProvider);
    final userId = ref.read(requiredUserIdProvider);

    final operation = await operationService.begin(
      userId: userId,
      type: QazaOperationType.restore,
      inputSnapshot: {
        'version': 1,
        'recordIds': [record.id],
        'sourceOperationId': record.operationId,
      },
    );

    try {
      final count = await service.restoreDeletedRecords(
        userId: userId,
        recordIds: [record.id],
        restoredAt: operation.createdAt,
        operationId: operation.operationId,
      );
      await operationService.finish(
        operation,
        status: count == 1
            ? QazaOperationStatus.completed
            : QazaOperationStatus.partial,
        affectedRecordCount: count,
        note: count == 0
            ? 'Record was no longer restorable or conflicted with an existing prayer/date.'
            : null,
      );
      await _load();
      if (!mounted) return;
      if (count == 1) {
        ref.read(appSnackbarServiceProvider).success(
              _urdu ? 'قضا بحال کر دی گئی۔' : 'Qaza record restored.',
            );
      } else {
        ref.read(appSnackbarServiceProvider).warning(
              _urdu
                  ? 'یہ ریکارڈ بحال نہیں ہو سکا، ممکن ہے یہ پہلے ہی تبدیل یا متصادم ہو۔'
                  : 'Record could not be restored because it changed or conflicts with an existing record.',
            );
      }
    } catch (e) {
      await operationService.finish(
        operation,
        status: QazaOperationStatus.failed,
        affectedRecordCount: 0,
        note: e.toString(),
      );
      rethrow;
    }
  }

  Widget _content() {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<_HistorySection>(
            segments: [
              ButtonSegment(
                value: _HistorySection.recent,
                label: Text(_urdu ? 'حالیہ اعمال' : 'Recent Actions'),
              ),
              ButtonSegment(
                value: _HistorySection.deleted,
                label: Text(_urdu ? 'حالیہ حذف شدہ' : 'Recently Deleted'),
              ),
            ],
            selected: {section},
            onSelectionChanged: (value) {
              setState(() => section = value.first);
              _load();
            },
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(error!),
                          ),
                          FilledButton(
                            onPressed: _load,
                            child: Text(l10n.commonRetry),
                          ),
                        ],
                      ),
                    )
                  : section == _HistorySection.recent
                      ? operations.isEmpty
                          ? Center(
                              child: Text(
                                _urdu
                                    ? 'حالیہ اعمال موجود نہیں۔'
                                    : 'No recent actions.',
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: operations.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final operation = operations[index];
                                return _OperationHistoryCard(
                                  key: Key(
                                    'qaza_operation_card_${operation.operationId}',
                                  ),
                                  operation: operation,
                                  label: _label(operation.type),
                                  statusLabel: _statusLabel(operation.status),
                                  summaryFuture:
                                      _summaryFutures[operation.operationId]!,
                                  onOpen: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            QazaOperationDetailScreen(
                                          operation: operation,
                                        ),
                                      ),
                                    );
                                    if (mounted) _load();
                                  },
                                );
                              },
                            )
                      : deleted.isEmpty
                          ? Center(
                              child: Text(
                                _urdu
                                    ? 'حالیہ حذف شدہ ریکارڈ موجود نہیں۔'
                                    : 'No recently deleted records.',
                              ),
                            )
                          : NotificationListener<ScrollNotification>(
                              onNotification: (n) {
                                if (n.metrics.extentAfter < 320) {
                                  _loadMoreDeleted();
                                }
                                return false;
                              },
                              child: ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: deleted.length + (hasMore ? 1 : 0),
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  if (index >= deleted.length) {
                                    return const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  final record = deleted[index];
                                  return Card(
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.delete_outline_rounded,
                                      ),
                                      title: Text(
                                        record.prayerType.localizedLabel(l10n),
                                      ),
                                      subtitle: Text(
                                        '${DateFormatters.formatGregorianDatePadded(record.originalDate)} • ${l10n.formatHijriDate(record.originalDate)}\n${_urdu ? 'حذف' : 'Deleted'}: ${DateFormatters.formatClockTime(
                                          record.updatedAt,
                                        )} • ${DateFormatters.formatGregorianDatePadded(
                                          record.updatedAt,
                                        )}',
                                      ),
                                      trailing: FilledButton.tonal(
                                        onPressed: () async {
                                          try {
                                            await _restore(record);
                                          } catch (_) {
                                            if (!context.mounted) return;
                                            ref.read(appSnackbarServiceProvider).error(
                                                  _urdu
                                                      ? 'ریکارڈ بحال نہیں ہو سکا۔'
                                                      : 'Record could not be restored.',
                                                );
                                          }
                                        },
                                        child: Text(
                                          _urdu ? 'بحال' : 'Restore',
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = SafeArea(child: _content());
    return widget.embedded
        ? body
        : AppScaffold(
            title: AppLocalizations.of(context).qazaTitle,
            body: body,
          );
  }
}

class _OperationHistoryCard extends StatelessWidget {
  const _OperationHistoryCard({
    super.key,
    required this.operation,
    required this.label,
    required this.statusLabel,
    required this.summaryFuture,
    required this.onOpen,
  });

  final QazaOperation operation;
  final String label;
  final String statusLabel;
  final Future<QazaOperationSummary> summaryFuture;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(statusLabel)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${DateFormatters.formatGregorianDatePadded(operation.createdAt)} • ${DateFormatters.formatClockTime(operation.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            FutureBuilder<QazaOperationSummary>(
              future: summaryFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const LinearProgressIndicator(minHeight: 3);
                }
                final summary = snapshot.data!;
                final originallyAdded = operation.recordCount > 0
                    ? operation.recordCount
                    : summary.currentCount;
                return Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    _CountText(label: 'Added', count: originallyAdded),
                    _CountText(label: 'Pending', count: summary.pending),
                    _CountText(
                      label: 'Completed',
                      count: summary.completed,
                    ),
                    _CountText(label: 'Deleted', count: summary.deleted),
                  ],
                );
              },
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.manage_search_rounded),
                label: Text(
                  Localizations.localeOf(context).languageCode == 'ur'
                      ? 'دیکھیں اور انتظام کریں'
                      : 'View & manage',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountText extends StatelessWidget {
  const _CountText({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: ${DateFormatters.formatCount(count)}',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}
