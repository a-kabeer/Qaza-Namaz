import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/calendar/hijri_date_service.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/errors/app_error_messages.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../domain/entities/qaza_operation.dart';
import '../../../domain/entities/qaza_record.dart';
import '../../../domain/repositories/qaza_recovery_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/prayer_type_l10n.dart';
import '../qaza_record_editor.dart';

enum QazaOperationDetailFilter {
  all,
  pending,
  completed,
  deleted,
}

class QazaOperationDetailScreen extends ConsumerStatefulWidget {
  const QazaOperationDetailScreen({
    super.key,
    required this.operation,
  });

  final QazaOperation operation;

  @override
  ConsumerState<QazaOperationDetailScreen> createState() =>
      _QazaOperationDetailScreenState();
}

class _QazaOperationDetailScreenState
    extends ConsumerState<QazaOperationDetailScreen> {
  List<QazaRecord> records = const [];
  QazaOperationSummary summary = const QazaOperationSummary();
  QazaOperationDetailFilter filter = QazaOperationDetailFilter.all;
  QazaOperationStatus operationStatus = QazaOperationStatus.running;

  bool loading = true;
  bool loadingMore = false;
  bool mutating = false;
  bool hasMore = false;
  DateTime? cursorDate;
  String? cursorId;
  String? error;

  bool get _urdu => Localizations.localeOf(context).languageCode == 'ur';

  QazaStatus? get _status => switch (filter) {
        QazaOperationDetailFilter.all => null,
        QazaOperationDetailFilter.pending => QazaStatus.pending,
        QazaOperationDetailFilter.completed => QazaStatus.completed,
        QazaOperationDetailFilter.deleted => QazaStatus.deleted,
      };

  bool get _matchLastAction => switch (widget.operation.type) {
        QazaOperationType.bulkComplete ||
        QazaOperationType.bulkDelete ||
        QazaOperationType.restore =>
          true,
        _ => false,
      };

  bool get _isAddition => widget.operation.isAddition;

  bool get _canManageAddition =>
      _isAddition &&
      operationStatus != QazaOperationStatus.undone &&
      operationStatus != QazaOperationStatus.removed &&
      summary.unchangedPending > 0 &&
      !mutating;

  String _operationLabel(QazaOperationType type) => _urdu
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

  String _filterLabel(QazaOperationDetailFilter value) => _urdu
      ? switch (value) {
          QazaOperationDetailFilter.all => 'تمام',
          QazaOperationDetailFilter.pending => 'زیر التوا',
          QazaOperationDetailFilter.completed => 'مکمل',
          QazaOperationDetailFilter.deleted => 'حذف شدہ',
        }
      : switch (value) {
          QazaOperationDetailFilter.all => 'All',
          QazaOperationDetailFilter.pending => 'Pending',
          QazaOperationDetailFilter.completed => 'Completed',
          QazaOperationDetailFilter.deleted => 'Deleted',
        };

  @override
  void initState() {
    super.initState();
    operationStatus = widget.operation.status;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
      cursorDate = null;
      cursorId = null;
      hasMore = false;
      records = const [];
    });

    try {
      final service = ref.read(qazaServiceProvider);
      final userId = ref.read(requiredUserIdProvider);
      final nextSummary = _isAddition
          ? await service.getOperationSummary(
              userId: userId,
              operationId: widget.operation.operationId,
            )
          : const QazaOperationSummary();

      final page = await service.getOperationPage(
        userId: userId,
        operationId: widget.operation.operationId,
        matchLastAction: _matchLastAction,
        operationAt: widget.operation.createdAt,
        status: _status,
        limit: 50,
      );

      if (!mounted) return;
      setState(() {
        summary = nextSummary;
        records = page.records;
        hasMore = page.hasMore;
        cursorDate = page.nextOriginalDate;
        cursorId = page.nextId;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.toString();
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (loadingMore || !hasMore) return;
    setState(() => loadingMore = true);
    try {
      final page = await ref.read(qazaServiceProvider).getOperationPage(
            userId: ref.read(requiredUserIdProvider),
            operationId: widget.operation.operationId,
            matchLastAction: _matchLastAction,
            operationAt: widget.operation.createdAt,
            status: _status,
            limit: 50,
            beforeOriginalDate: cursorDate,
            beforeId: cursorId,
          );
      if (!mounted) return;
      setState(() {
        records = [...records, ...page.records];
        hasMore = page.hasMore;
        cursorDate = page.nextOriginalDate;
        cursorId = page.nextId;
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

  Future<void> _refreshForFilter(QazaOperationDetailFilter next) async {
    if (filter == next) return;
    setState(() => filter = next);
    await _load();
  }

  Future<void> _undoAddition() async {
    if (!_canManageAddition) return;
    final count = summary.unchangedPending;
    final confirmed = await confirmDestructive(
      context,
      title: _urdu ? 'اضافہ واپس کریں؟' : 'Undo this addition?',
      message: (_urdu
          ? '$count زیر التوا ریکارڈ اس اضافے سے محفوظ طریقے سے واپس کیے جائیں گے۔ مکمل یا تبدیل شدہ ریکارڈ محفوظ رہیں گے۔'
          : '$count untouched pending records from this addition will be safely reversed. Completed or changed records will be preserved.'),
      confirmLabel: _urdu ? 'واپس کریں' : 'Undo addition',
    );
    if (!confirmed || !mounted) return;

    setState(() => mutating = true);
    try {
      final service = ref.read(qazaServiceProvider);
      final operationService = ref.read(qazaOperationServiceProvider);
      final affected = await service.undoAddedOperation(
        userId: ref.read(requiredUserIdProvider),
        operationId: widget.operation.operationId,
        expectedCreatedAt: widget.operation.createdAt,
      );
      final status =
          affected == widget.operation.recordCount && affected == count
              ? QazaOperationStatus.undone
              : QazaOperationStatus.partial;
      await operationService.finish(
        widget.operation,
        status: status,
        affectedRecordCount: affected,
        note: affected < count
            ? 'Some records changed before the undo and were preserved.'
            : null,
      );
      operationStatus = status;
      await _load();
      if (!mounted) return;
      ref.read(appSnackbarServiceProvider).success(
            _urdu
                ? '$affected ریکارڈ واپس کیے گئے۔ تبدیل یا مکمل ریکارڈ محفوظ رہے۔'
                : '$affected records were reversed. Changed or completed records were preserved.',
          );
    } catch (e) {
      if (!mounted) return;
      ref.read(appSnackbarServiceProvider).error(
            AppError.from(e).message(context),
          );
    } finally {
      if (mounted) setState(() => mutating = false);
    }
  }

  Future<void> _removeAddition() async {
    if (!_canManageAddition) return;
    final count = summary.unchangedPending;
    final confirmed = await confirmDestructive(
      context,
      title: _urdu ? 'یہ اضافہ ہٹائیں؟' : 'Remove this addition?',
      message: (_urdu
          ? '$count زیر التوا ریکارڈ اس اضافے سے نرم حذف کیے جائیں گے اور Recently Deleted سے بحال کیے جا سکیں گے۔'
          : '$count untouched pending records from this addition will be soft-deleted and can be restored from Recently Deleted.'),
      confirmLabel: _urdu ? 'یہ اضافہ ہٹائیں' : 'Remove this addition',
    );
    if (!confirmed || !mounted) return;

    setState(() => mutating = true);
    try {
      final service = ref.read(qazaServiceProvider);
      final operationService = ref.read(qazaOperationServiceProvider);
      final affected = await service.removeAddition(
        userId: ref.read(requiredUserIdProvider),
        operationId: widget.operation.operationId,
        expectedCreatedAt: widget.operation.createdAt,
        deletedAt: DateTime.now(),
      );
      final status = affected == count
          ? QazaOperationStatus.removed
          : QazaOperationStatus.partial;
      await operationService.finish(
        widget.operation,
        status: status,
        affectedRecordCount: affected,
        note: affected < count
            ? 'Some records changed before removal and were preserved.'
            : null,
      );
      operationStatus = status;
      await _load();
      if (!mounted) return;
      ref.read(appSnackbarServiceProvider).success(
            _urdu
                ? '$affected ریکارڈ ہٹا دیے گئے۔'
                : '$affected records were removed and can be recovered.',
          );
    } catch (e) {
      if (!mounted) return;
      ref.read(appSnackbarServiceProvider).error(
            AppError.from(e).message(context),
          );
    } finally {
      if (mounted) setState(() => mutating = false);
    }
  }

  Future<void> _editRecord(QazaRecord record) async {
    if (mutating || record.status == QazaStatus.deleted) return;
    final edited = await showQazaRecordEditor(
      context,
      record: record,
    );
    if (edited == null || !mounted) return;

    setState(() => mutating = true);
    try {
      await ref.read(qazaServiceProvider).updateRecord(
            userId: ref.read(requiredUserIdProvider),
            record: edited,
          );
      await _load();
      if (!mounted) return;
      ref.read(appSnackbarServiceProvider).success(
            _urdu ? 'ریکارڈ درست کر دیا گیا۔' : 'Record corrected.',
          );
    } catch (e) {
      if (!mounted) return;
      ref.read(appSnackbarServiceProvider).error(
            AppError.from(e).message(context),
          );
    } finally {
      if (mounted) setState(() => mutating = false);
    }
  }

  Widget _summaryCard({
    required String label,
    required int count,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 156,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            DateFormatters.formatCount(count),
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ],
      ),
    );
  }

  Widget _body() {
    final l10n = AppLocalizations.of(context);
    final originalCount = widget.operation.recordCount > 0
        ? widget.operation.recordCount
        : summary.currentCount;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _operationLabel(widget.operation.type),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              Chip(label: Text(_statusLabel(operationStatus))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              '${DateFormatters.formatGregorianDatePadded(
                widget.operation.createdAt,
              )} • ${DateFormatters.formatClockTime(widget.operation.createdAt)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryCard(
                label: _urdu ? 'اصل اضافہ' : 'Originally added',
                count: originalCount,
              ),
              _summaryCard(
                label: _urdu ? 'زیر التوا' : 'Pending',
                count: summary.pending,
              ),
              _summaryCard(
                label: _urdu ? 'مکمل' : 'Completed',
                count: summary.completed,
              ),
              _summaryCard(
                label: _urdu ? 'حذف شدہ' : 'Deleted',
                count: summary.deleted,
              ),
            ],
          ),
        ),
        if (_isAddition && summary.changedPending > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                (_urdu
                    ? '${summary.changedPending} زیر التوا ریکارڈ تبدیل ہو چکے ہیں؛ Undo/Remove انہیں محفوظ رکھے گا۔'
                    : '${summary.changedPending} pending records have changed since the addition; Undo/Remove will preserve them.'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        if (_isAddition && summary.unchangedPending > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    key: const Key('qaza_operation_undo_addition'),
                    onPressed: mutating ? null : _undoAddition,
                    icon: const Icon(Icons.undo_rounded),
                    label: Text(
                      _urdu ? 'اضافہ واپس کریں' : 'Undo addition',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('qaza_operation_remove_addition'),
                    onPressed: mutating ? null : _removeAddition,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(
                      _urdu ? 'یہ اضافہ ہٹائیں' : 'Remove this addition',
                    ),
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final value in QazaOperationDetailFilter.values) ...[
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: FilterChip(
                      key: Key('qaza_operation_filter_${value.name}'),
                      selected: filter == value,
                      label: Text(_filterLabel(value)),
                      onSelected: (_) => _refreshForFilter(value),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? Center(child: Text(error!))
                  : records.isEmpty
                      ? Center(
                          child: Text(
                            _urdu
                                ? 'اس فلٹر میں کوئی ریکارڈ موجود نہیں۔'
                                : 'No records match this filter.',
                          ),
                        )
                      : NotificationListener<ScrollNotification>(
                          onNotification: (notification) {
                            if (notification.metrics.extentAfter < 320) {
                              _loadMore();
                            }
                            return false;
                          },
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                              16,
                              4,
                              16,
                              24,
                            ),
                            itemCount: records.length + (hasMore ? 1 : 0),
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              if (index >= records.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final record = records[index];
                              final icon = switch (record.status) {
                                QazaStatus.pending =>
                                  Icons.pending_actions_rounded,
                                QazaStatus.completed =>
                                  Icons.check_circle_outline_rounded,
                                QazaStatus.deleted =>
                                  Icons.delete_outline_rounded,
                              };
                              return Card(
                                key: Key(
                                  'qaza_operation_record_${record.id}',
                                ),
                                child: ListTile(
                                  leading: Icon(icon),
                                  title: Text(
                                    DateFormatters.formatGregorianDatePadded(
                                      record.originalDate,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${record.prayerType.localizedLabel(l10n)}\n${l10n.formatHijriDate(record.originalDate)} • ${record.status.localizedLabel(l10n)}',
                                  ),
                                  trailing: record.status == QazaStatus.deleted
                                      ? null
                                      : IconButton(
                                          key: Key(
                                            'qaza_operation_edit_${record.id}',
                                          ),
                                          tooltip: _urdu
                                              ? 'ریکارڈ درست کریں'
                                              : 'Correct record',
                                          onPressed: mutating
                                              ? null
                                              : () => _editRecord(record),
                                          icon: const Icon(
                                            Icons.edit_outlined,
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
    return AppScaffold(
      title: _urdu ? 'عمل کی تفصیل' : 'Action details',
      body: SafeArea(child: _body()),
    );
  }
}
