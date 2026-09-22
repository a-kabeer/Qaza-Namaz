import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../domain/entities/qaza_operation.dart';
import '../../../domain/entities/qaza_record.dart';
import '../../../domain/services/qaza_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/prayer_type_l10n.dart';
import 'qaza_operation_detail_screen.dart';

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
          QazaOperationType.manualAdd => 'دستی اضافہ',
          QazaOperationType.bulkComplete => 'متعدد قضا مکمل',
          QazaOperationType.bulkDelete => 'متعدد قضا حذف',
          QazaOperationType.restore => 'بحال',
        }
      : switch (type) {
          QazaOperationType.calculatorImport => 'Calculator import',
          QazaOperationType.rangeAdd => 'Range add',
          QazaOperationType.multipleDateAdd => 'Multiple-date add',
          QazaOperationType.manualAdd => 'Manual add',
          QazaOperationType.bulkComplete => 'Bulk complete',
          QazaOperationType.bulkDelete => 'Bulk delete',
          QazaOperationType.restore => 'Restore',
        };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
      cursorDate = null;
      cursorId = null;
      hasMore = false;
      operations = const [];
      deleted = const [];
    });
    try {
      final userId = ref.read(requiredUserIdProvider);
      await ref.read(qazaServiceProvider).purgeDeletedBefore(
            userId: userId,
            cutoff: DateTime.now().subtract(const Duration(days: 30)),
          );
      if (section == _HistorySection.recent) {
        operations = await ref.read(qazaOperationServiceProvider).recent(userId);
      } else {
        final page = await ref.read(qazaServiceProvider).getRecentlyDeletedPage(
              userId: userId,
              limit: 50,
            );
        deleted = page.records;
        hasMore = page.hasMore;
        cursorDate = page.nextOriginalDate;
        cursorId = page.nextId;
      }
      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) setState(() { loading = false; error = e.toString(); });
    }
  }

  Future<void> _loadMoreDeleted() async {
    if (loadingMore || !hasMore) return;
    setState(() => loadingMore = true);
    try {
      final page = await ref.read(qazaServiceProvider).getRecentlyDeletedPage(
            userId: ref.read(requiredUserIdProvider),
            limit: 50,
            beforeOriginalDate: cursorDate,
            beforeId: cursorId,
          );
      setState(() {
        deleted = [...deleted, ...page.records];
        hasMore = page.hasMore;
        cursorDate = page.nextOriginalDate;
        cursorId = page.nextId;
        loadingMore = false;
      });
    } catch (e) {
      setState(() { loadingMore = false; error = e.toString(); });
    }
  }

  Future<void> _undoImport(QazaOperation operation) async {
    try {
      final removed = await ref.read(qazaServiceProvider).undoAddedOperation(
            userId: ref.read(requiredUserIdProvider),
            operationId: operation.operationId,
            expectedCreatedAt: operation.createdAt,
          );
      await ref.read(qazaOperationServiceProvider).finish(
            operation,
            status: removed == operation.recordCount
                ? QazaOperationStatus.undone
                : QazaOperationStatus.partial,
            affectedRecordCount: removed,
            note: removed < operation.recordCount
                ? 'Changed or completed records were preserved.'
                : null,
          );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_urdu
              ? removed.toString() + ' ریکارڈ محفوظ طریقے سے واپس کیے گئے۔'
              : removed.toString() + ' records were safely removed from the import.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _restore(QazaRecord record) async {
    final op = await ref.read(qazaOperationServiceProvider).begin(
          userId: ref.read(requiredUserIdProvider),
          type: QazaOperationType.restore,
        );
    try {
      final count = await ref.read(qazaServiceProvider).restoreDeletedRecords(
            userId: ref.read(requiredUserIdProvider),
            recordIds: [record.id],
            restoredAt: op.createdAt,
            operationId: op.operationId,
          );
      await ref.read(qazaOperationServiceProvider).finish(
            op,
            status: count == 1 ? QazaOperationStatus.completed : QazaOperationStatus.partial,
            affectedRecordCount: count,
          );
      await _load();
    } catch (e) {
      await ref.read(qazaOperationServiceProvider).finish(
            op,
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
              ButtonSegment(value: _HistorySection.recent, label: Text(_urdu ? 'حالیہ اعمال' : 'Recent Actions')),
              ButtonSegment(value: _HistorySection.deleted, label: Text(_urdu ? 'حالیہ حذف شدہ' : 'Recently Deleted')),
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
                          Padding(padding: const EdgeInsets.all(24), child: Text(error!)),
                          FilledButton(onPressed: _load, child: Text(l10n.commonRetry)),
                        ],
                      ),
                    )
                  : section == _HistorySection.recent
                      ? operations.isEmpty
                          ? Center(child: Text(_urdu ? 'حالیہ اعمال موجود نہیں۔' : 'No recent actions.'))
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: operations.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final op = operations[index];
                                final undoable = {
                                  QazaOperationType.calculatorImport,
                                  QazaOperationType.rangeAdd,
                                  QazaOperationType.multipleDateAdd,
                                  QazaOperationType.manualAdd,
                                }.contains(op.type) && op.status != QazaOperationStatus.undone;
                                return Card(
                                  child: ListTile(
                                    title: Text(_label(op.type)),
                                    subtitle: Text(op.affectedRecordCount.toString() + ' • ' + DateFormatters.formatGregorianDatePadded(op.createdAt)),
                                    trailing: Wrap(
                                      children: [
                                        IconButton(
                                          tooltip: l10n.commonView,
                                          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => QazaOperationDetailScreen(operation: op))),
                                          icon: const Icon(Icons.visibility_outlined),
                                        ),
                                        if (undoable)
                                          IconButton(
                                            tooltip: _urdu ? 'درآمد واپس کریں' : 'Undo import',
                                            onPressed: () => _undoImport(op),
                                            icon: const Icon(Icons.undo_rounded),
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                      : deleted.isEmpty
                          ? Center(child: Text(_urdu ? 'حالیہ حذف شدہ ریکارڈ موجود نہیں۔' : 'No recently deleted records.'))
                          : NotificationListener<ScrollNotification>(
                              onNotification: (n) {
                                if (n.metrics.extentAfter < 320) _loadMoreDeleted();
                                return false;
                              },
                              child: ListView.separated(
                                padding: const EdgeInsets.all(16),
                                itemCount: deleted.length + (hasMore ? 1 : 0),
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  if (index >= deleted.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                                  final record = deleted[index];
                                  return Card(
                                    child: ListTile(
                                      leading: const Icon(Icons.delete_outline_rounded),
                                      title: Text(record.prayerType.localizedLabel(l10n)),
                                      subtitle: Text(
                                        DateFormatters.formatGregorianDatePadded(record.originalDate) +
                                        ' • ' + DateFormatters.hijriLabel(record.originalDate) +
                                        '\n' + (_urdu ? 'حذف' : 'Deleted') + ': ' +
                                        DateFormatters.formatGregorianDatePadded(record.updatedAt),
                                      ),
                                      trailing: FilledButton.tonal(
                                        onPressed: () async {
                                          try {
                                            await _restore(record);
                                          } catch (_) {
                                            if (!mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_urdu ? 'ریکارڈ بحال نہیں ہو سکا۔' : 'Record could not be restored.')));
                                          }
                                        },
                                        child: Text(l10n.commonRestore),
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
        : AppScaffold(title: AppLocalizations.of(context).qazaTitle, body: body);
  }
}
