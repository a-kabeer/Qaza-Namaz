import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/state_widgets.dart';
import '../../domain/entities/qaza_addition.dart';
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
    return AppScaffold(
      title: 'Qaza History',
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SegmentedButton<QazaAdditionHistoryTab>(
                segments: const [
                  ButtonSegment(
                    value: QazaAdditionHistoryTab.recent,
                    label: Text('Recent Additions'),
                    icon: Icon(Icons.playlist_add_rounded),
                  ),
                  ButtonSegment(
                    value: QazaAdditionHistoryTab.deleted,
                    label: Text('Recently Deleted'),
                    icon: Icon(Icons.delete_sweep_rounded),
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
      return ListView(
        children: [
          SizedBox(height: 120),
          const Center(child: Text('No Qaza additions yet.'))
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
              child: const Text('Load more'),
            ),
          );
        }
        final item = state.additions[index];
        final snapshot = item.addition.currentInputSnapshot;
        final mode = switch (snapshot.mode) {
          QazaAdditionMode.single => 'Single',
          QazaAdditionMode.range => 'Range',
          QazaAdditionMode.multiple => 'Multiple',
        };
        final dateText = snapshot.selectedDates.length == 1
            ? _date(context, snapshot.selectedDates.first)
            : snapshot.selectedDates.isEmpty
                ? 'No dates'
                : snapshot.mode == QazaAdditionMode.range &&
                        snapshot.selectedDates.length == 2
                    ? '${_date(context, snapshot.selectedDates.first)} – '
                        '${_date(context, snapshot.selectedDates.last)}'
                    : '${snapshot.selectedDates.length} dates';
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(child: Text('${item.activeCount}')),
            title: Text('$mode • $dateText'),
            subtitle: Text(
              '${item.pendingCount} pending • '
              '${item.completedCount} completed\n'
              'Revision ${item.addition.revision}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => openQazaAdditionDetail(context, item.addition.id),
          ),
        );
      },
    );
  }

  String _date(BuildContext context, DateTime value) =>
      MaterialLocalizations.of(context).formatMediumDate(value);
}

class _DeletedActions extends ConsumerWidget {
  const _DeletedActions({required this.state, required this.controller});
  final QazaAdditionHistoryState state;
  final QazaAdditionHistoryController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.deleted.isEmpty) {
      return const ListView(
        children: [
          SizedBox(height: 120),
          const Center(child: Text('No recently deleted Qaza.'))
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
              child: const Text('Load more'),
            ),
          );
        }
        final item = state.deleted[index];
        final dateText = item.firstOriginalDate == null
            ? 'Original date unavailable'
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
            title: const Text('Deleted Qaza'),
            subtitle: Text(
              '$dateText\n${item.deletedCount} Qaza deleted',
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
                            ? '${result.restoredCount} Qaza restored'
                            : '${result.restoredCount} restored, '
                                '${result.conflictCount} skipped',
                      );
                } catch (error) {
                  if (!context.mounted) return;
                  ref.read(appSnackbarServiceProvider).error(error.toString());
                }
              },
              child: const Text('Restore'),
            ),
          ),
        );
      },
    );
  }

  String _date(BuildContext context, DateTime value) =>
      MaterialLocalizations.of(context).formatMediumDate(value);
}
