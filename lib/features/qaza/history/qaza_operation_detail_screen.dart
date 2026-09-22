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

class QazaOperationDetailScreen extends ConsumerStatefulWidget {
  const QazaOperationDetailScreen({super.key, required this.operation});
  final QazaOperation operation;

  @override
  ConsumerState<QazaOperationDetailScreen> createState() =>
      _QazaOperationDetailScreenState();
}

class _QazaOperationDetailScreenState
    extends ConsumerState<QazaOperationDetailScreen> {
  List<QazaRecord> records = const [];
  bool loading = true;
  bool loadingMore = false;
  bool hasMore = false;
  DateTime? cursorDate;
  String? cursorId;
  String? error;

  bool get _matchLastAction =>
      widget.operation.type == QazaOperationType.bulkComplete ||
      widget.operation.type == QazaOperationType.bulkDelete ||
      widget.operation.type == QazaOperationType.restore;

  QazaStatus? get _status => switch (widget.operation.type) {
        QazaOperationType.bulkDelete => QazaStatus.deleted,
        QazaOperationType.bulkComplete => QazaStatus.completed,
        _ => null,
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
      records = const [];
    });
    try {
      final page = await ref.read(qazaServiceProvider).getOperationPage(
            userId: ref.read(requiredUserIdProvider),
            operationId: widget.operation.operationId,
            matchLastAction: _matchLastAction,
            operationAt: widget.operation.createdAt,
            status: _status,
            limit: 50,
          );
      if (!mounted) return;
      setState(() {
        records = page.records;
        hasMore = page.hasMore;
        cursorDate = page.nextOriginalDate;
        cursorId = page.nextId;
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { loading = false; error = e.toString(); });
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
      setState(() {
        records = [...records, ...page.records];
        hasMore = page.hasMore;
        cursorDate = page.nextOriginalDate;
        cursorId = page.nextId;
        loadingMore = false;
      });
    } catch (e) {
      setState(() { loadingMore = false; error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final urdu = Localizations.localeOf(context).languageCode == 'ur';
    return AppScaffold(
      title: urdu ? 'عمل کی تفصیل' : 'Action details',
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(child: Text(error!))
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.extentAfter < 320) _loadMore();
                      return false;
                    },
                    child: records.isEmpty
                        ? Center(child: Text(urdu ? 'اس عمل کے ریکارڈ دستیاب نہیں۔' : 'No records are available.'))
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: records.length + (hasMore ? 1 : 0),
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              if (index >= records.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final record = records[index];
                              final icon = record.status == QazaStatus.deleted
                                  ? Icons.delete_outline_rounded
                                  : record.status == QazaStatus.completed
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.pending_actions_rounded;
                              return Card(
                                child: ListTile(
                                  leading: Icon(icon),
                                  title: Text(record.prayerType.localizedLabel(l10n)),
                                  subtitle: Text(
                                    DateFormatters.formatGregorianDatePadded(record.originalDate) +
                                    ' • ' + DateFormatters.hijriLabel(record.originalDate),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
      ),
    );
  }
}
