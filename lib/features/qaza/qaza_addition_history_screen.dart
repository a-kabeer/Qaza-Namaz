import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/state_widgets.dart';
import '../../domain/entities/qaza_addition.dart';
import '../../l10n/app_localizations.dart';
import 'widgets/qaza_addition_date_summary.dart';
import 'qaza_navigation.dart';

enum QazaAdditionHistoryTab { recent, deleted }

@immutable
class QazaAdditionHistoryState {
  const QazaAdditionHistoryState({
    this.tab = QazaAdditionHistoryTab.recent,
    this.additions = const <QazaAdditionListItem>[],
    this.deleted = const <QazaDeletionActionListItem>[],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.additionsHasMore = false,
    this.deletedHasMore = false,
  });

  final QazaAdditionHistoryTab tab;
  final List<QazaAdditionListItem> additions;
  final List<QazaDeletionActionListItem> deleted;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final bool additionsHasMore;
  final bool deletedHasMore;

  QazaAdditionHistoryState copyWith({
    QazaAdditionHistoryTab? tab,
    List<QazaAdditionListItem>? additions,
    List<QazaDeletionActionListItem>? deleted,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    bool? additionsHasMore,
    bool? deletedHasMore,
  }) =>
      QazaAdditionHistoryState(
        tab: tab ?? this.tab,
        additions: additions ?? this.additions,
        deleted: deleted ?? this.deleted,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        error: clearError ? null : error ?? this.error,
        additionsHasMore: additionsHasMore ?? this.additionsHasMore,
        deletedHasMore: deletedHasMore ?? this.deletedHasMore,
      );
}

final qazaAdditionHistoryControllerProvider =
    AutoDisposeNotifierProvider<QazaAdditionHistoryController,
        QazaAdditionHistoryState>(
  QazaAdditionHistoryController.new,
);

class QazaAdditionHistoryController
    extends AutoDisposeNotifier<QazaAdditionHistoryState> {
  static const pageSize = 30;
  DateTime? _additionCursorDate;
  String? _additionCursorId;
  DateTime? _deletedCursorDate;
  String? _deletedCursorId;

  @override
  QazaAdditionHistoryState build() {
    Future.microtask(loadInitial);
    return const QazaAdditionHistoryState();
  }

  void setTab(QazaAdditionHistoryTab tab) {
    state = state.copyWith(tab: tab);
  }

  Future<void> loadInitial() async {
    state = state.copyWith(
      loading: true,
      additions: const [],
      deleted: const [],
      additionsHasMore: false,
      deletedHasMore: false,
      clearError: true,
    );
    _additionCursorDate = null;
    _additionCursorId = null;
    _deletedCursorDate = null;
    _deletedCursorId = null;
    try {
      await Future.wait([
        _loadAdditions(initial: true),
        _loadDeleted(initial: true),
      ]);
      state = state.copyWith(loading: false);
    } catch (error) {
      state = state.copyWith(loading: false, error: error.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      if (state.tab == QazaAdditionHistoryTab.recent) {
        await _loadAdditions();
      } else {
        await _loadDeleted();
      }
    } catch (error) {
      state = state.copyWith(error: error.toString());
    } finally {
      state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> refresh() => loadInitial();

  Future<void> _loadAdditions({bool initial = false}) async {
    if (!initial && !state.additionsHasMore) return;
    final userId = ref.read(activeUserIdProvider);
    if (userId == null) return;
    final page =
        await ref.read(qazaAdditionRepositoryProvider).getRecentAdditions(
              userId: userId,
              limit: pageSize,
              afterCreatedAt: initial ? null : _additionCursorDate,
              afterId: initial ? null : _additionCursorId,
            );
    _additionCursorDate = page.nextCreatedAt;
    _additionCursorId = page.nextId;
    state = state.copyWith(
      additions: initial ? page.items : [...state.additions, ...page.items],
      additionsHasMore: page.hasMore,
      loading: false,
    );
  }

  Future<void> _loadDeleted({bool initial = false}) async {
    if (!initial && !state.deletedHasMore) return;
    final userId = ref.read(activeUserIdProvider);
    if (userId == null) return;
    final page = await ref
        .read(qazaAdditionRepositoryProvider)
        .getRecentDeletionActions(
          userId: userId,
          limit: pageSize,
          afterCreatedAt: initial ? null : _deletedCursorDate,
          afterId: initial ? null : _deletedCursorId,
        );
    _deletedCursorDate = page.nextCreatedAt;
    _deletedCursorId = page.nextId;
    state = state.copyWith(
      deleted: initial ? page.items : [...state.deleted, ...page.items],
      deletedHasMore: page.hasMore,
      loading: false,
    );
  }

  Future<QazaRestoreResult> restore(String deletionActionId) async {
    final result = await ref
        .read(qazaAdditionRepositoryProvider)
        .restoreDeletionAction(
          userId: ref.read(requiredUserIdProvider),
          deletionActionId: deletionActionId,
        );
    ref.invalidate(progressSummaryProvider);
    await loadInitial();
    return result;
  }
}

class QazaAdditionHistoryScreen extends ConsumerWidget {
  const QazaAdditionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(qazaAdditionHistoryControllerProvider);
    final controller = ref.read(qazaAdditionHistoryControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    return AppScaffold(
      title: l10n.qazaHistoryTitle,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SegmentedButton<QazaAdditionHistoryTab>(
                segments: [
                  ButtonSegment(
                    value: QazaAdditionHistoryTab.recent,
                    label: Text(l10n.qazaHistoryRecentAdditions),
                    icon: const Icon(Icons.playlist_add_rounded),
                  ),
                  ButtonSegment(
                    value: QazaAdditionHistoryTab.deleted,
                    label: Text(l10n.qazaHistoryRecentlyDeleted),
                    icon: const Icon(Icons.delete_sweep_rounded),
                  ),
                ],
                selected: {state.tab},
                onSelectionChanged: (value) =>
                    controller.setTab(value.first),
              ),
            ),
            Expanded(
              child: state.error != null
                  ? ErrorState(
                      message: state.error!,
                      onRetry: controller.refresh,
                    )
                  : state.loading &&
                          state.additions.isEmpty &&
                          state.deleted.isEmpty
                      ? const LoadingState()
                      : RefreshIndicator(
                          onRefresh: controller.refresh,
                          child: state.tab == QazaAdditionHistoryTab.recent
                              ? _RecentAdditions(state: state, controller: controller)
                              : _DeletedActions(state: state, controller: controller),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentAdditions extends StatelessWidget {
  const _RecentAdditions({required this.state, required this.controller});

  final QazaAdditionHistoryState state;
  final QazaAdditionHistoryController controller;

  @override
  Widget build(BuildContext context) {
    if (state.additions.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return ListView(
        children: [
          const SizedBox(height: 120),
          Center(child: Text(l10n.qazaHistoryNoAdditions)),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.additions.length + (state.additionsHasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.additions.length) {
          return Center(
            child: FilledButton.tonal(
              onPressed: state.loadingMore ? null : controller.loadMore,
              child: Text(l10n.qazaHistoryLoadMore),
            ),
          );
        }

        final item = state.additions[index];
        return _RecentAdditionCard(
          key: ValueKey(item.addition.id),
          item: item,
        );
      },
    );
  }
}

class _RecentAdditionCard extends StatefulWidget {
  const _RecentAdditionCard({
    super.key,
    required this.item,
  });

  final QazaAdditionListItem item;

  @override
  State<_RecentAdditionCard> createState() => _RecentAdditionCardState();
}

class _RecentAdditionCardState extends State<_RecentAdditionCard> {
  bool _datesExpanded = false;

  void _openDetail() {
    openQazaAdditionDetail(context, widget.item.addition.id);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final snapshot = item.addition.currentInputSnapshot;
    final summary = QazaAdditionDateSummary(snapshot);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final total = item.pendingCount + item.completedCount;
    final progress = total == 0 ? 0.0 : item.completedCount / total;
    final percent = total == 0 ? 0 : item.completedCount * 100 ~/ total;
    final prayers = summary.prayerLabels(l10n);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: _openDetail,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary.modeLabel(l10n),
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ..._dateSummary(
                    context,
                    summary,
                    l10n,
                    theme.textTheme,
                  ),
                ],
              ),
            ),
          ),
          if (summary.hasExpandableMultipleDates) ...[
            Padding(
              padding: const EdgeInsets.only(left: 8, right: 8, bottom: 4),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => _datesExpanded = !_datesExpanded);
                  },
                  icon: Icon(
                    _datesExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                  ),
                  label: Text(
                    _datesExpanded
                        ? l10n.qazaHistoryHideDates
                        : l10n.qazaHistoryShowAllDates,
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: kThemeAnimationDuration,
              curve: Curves.easeInOut,
              child: _datesExpanded
                  ? InkWell(
                      onTap: _openDetail,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: _expandedMultipleDates(
                          context,
                          summary,
                          l10n,
                          theme.textTheme,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
          InkWell(
            onTap: _openDetail,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    summary.selectionScopeLabel(l10n),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (prayers.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      prayers.join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          label: l10n.qazaHistoryProgressPercentage(
                            percent,
                          ),
                          value: l10n.progressCompletedPending(
                            item.completedCount.toString(),
                            item.pendingCount.toString(),
                          ),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.qazaHistoryProgressPercentage(percent),
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.progressCompletedPending(
                      item.completedCount.toString(),
                      item.pendingCount.toString(),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.qazaHistoryTrackedRecords(total),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.qazaHistoryAdded(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(item.addition.createdAt),
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _dateSummary(
    BuildContext context,
    QazaAdditionDateSummary summary,
    AppLocalizations l10n,
    TextTheme textTheme,
  ) {
    switch (summary.snapshot.mode) {
      case QazaAdditionMode.single:
        if (summary.selectedDates.isEmpty) {
          return [
            Text(
              l10n.qazaHistoryNoDates,
              style: textTheme.bodyMedium,
            ),
          ];
        }
        final date = summary.selectedDates.first;
        return [
          Text(
            summary.formatGregorian(context, date),
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            summary.formatHijri(l10n, date),
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ];
      case QazaAdditionMode.range:
        return [
          Text(
            summary.rangeGregorian(context, l10n),
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            summary.rangeHijri(context, l10n),
            style: textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ];
      case QazaAdditionMode.multiple:
        if (summary.selectedDates.isEmpty) {
          return [
            Text(
              l10n.qazaHistoryNoDates,
              style: textTheme.bodyMedium,
            ),
          ];
        }
        final preview = summary.multiplePreview(
          context: context,
          l10n: l10n,
        );
        final gregorian = preview.map((line) => line.gregorian).join(' · ');
        final hijri = preview.map((line) => line.hijri).join(' · ');
        final suffix = summary.hasExpandableMultipleDates ? ' …' : '';
        return [
          Text(
            summary.selectedDatesLabel(l10n),
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            gregorian + suffix,
            style: textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            hijri + suffix,
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ];
    }
  }

  Widget _expandedMultipleDates(
    BuildContext context,
    QazaAdditionDateSummary summary,
    AppLocalizations l10n,
    TextTheme textTheme,
  ) {
    final lines = summary.multipleExpanded(context, l10n);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    line.gregorian,
                    style: textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line.hijri,
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DeletedActions extends ConsumerWidget {
  const _DeletedActions({required this.state, required this.controller});
  final QazaAdditionHistoryState state;
  final QazaAdditionHistoryController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.deleted.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(child: Text(l10n.qazaHistoryNoRecentlyDeleted)),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: state.deleted.length + (state.deletedHasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.deleted.length) {
          return Center(
            child: FilledButton.tonal(
              onPressed: state.loadingMore ? null : controller.loadMore,
              child: Text(l10n.qazaHistoryLoadMore),
            ),
          );
        }
        final item = state.deleted[index];
        final dateText = item.firstOriginalDate == null
            ? l10n.qazaHistoryOriginalDateUnavailable
            : item.firstOriginalDate == item.lastOriginalDate
                ? _date(context, item.firstOriginalDate!)
                : '${_date(context, item.firstOriginalDate!)} – '
                    '${_date(context, item.lastOriginalDate!)}';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.delete_outline_rounded),
            ),
            title: Text(l10n.qazaHistoryDeletedQaza),
            subtitle: Text(
              dateText + '\n' + l10n.qazaHistoryDeletedQazaCount(item.deletedCount),
            ),
            isThreeLine: true,
            onTap: () => openQazaAdditionDetail(context, item.additionId),
            trailing: FilledButton.tonal(
              onPressed: () async {
                try {
                  final result = await controller.restore(item.id);
                  if (!context.mounted) return;
                  ref.read(appSnackbarServiceProvider).success(
                        result.conflictCount == 0
                            ? l10n.qazaHistoryRestoreSuccess(result.restoredCount)
                            : l10n.qazaHistoryRestoreConflict(
                                result.restoredCount,
                                result.conflictCount,
                              ),
                      );
                } catch (error) {
                  if (!context.mounted) return;
                  ref.read(appSnackbarServiceProvider).error(error.toString());
                }
              },
              child: Text(l10n.qazaHistoryRestore),
            ),
          ),
        );
      },
    );
  }

  String _date(BuildContext context, DateTime value) =>
      MaterialLocalizations.of(context).formatMediumDate(value);
}
