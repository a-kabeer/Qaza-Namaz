import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../l10n/app_localizations.dart';
import 'daily_salah_tracking_providers.dart';
import 'daily_salah_tracking_service.dart';

class DailySalahTrackingScreen extends ConsumerStatefulWidget {
  const DailySalahTrackingScreen({super.key});

  @override
  ConsumerState<DailySalahTrackingScreen> createState() =>
      _DailySalahTrackingScreenState();
}

class _DailySalahTrackingScreenState
    extends ConsumerState<DailySalahTrackingScreen> {
  late DateTime _selectedDate = _dayOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final logs = ref.watch(dailySalahTrackingLogsProvider(_selectedDate));
    final includeWitr = ref.watch(effectiveWitrProvider);
    final prayers = PrayerType.values
        .where((prayer) => includeWitr || prayer != PrayerType.witr)
        .toList(growable: false);
    final locale = Localizations.localeOf(context).toString();

    return AppScaffold(
      title: l10n.dailySalahTrackingTitle,
      body: logs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.errorStorage,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (dailyLogs) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('daily_salah_previous_day'),
                      tooltip: l10n.dailySalahTrackingPreviousDay,
                      onPressed: () => _changeDay(-1),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        key: const Key('daily_salah_select_date'),
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          DateFormat.yMMMd(locale).format(_selectedDate),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('daily_salah_next_day'),
                      tooltip: l10n.dailySalahTrackingNextDay,
                      onPressed: _isToday ? null : () => _changeDay(1),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final prayer in prayers)
              _buildPrayerCard(
                context: context,
                l10n: l10n,
                prayer: prayer,
                log: dailyLogs[prayer],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerCard({
    required BuildContext context,
    required AppLocalizations l10n,
    required PrayerType prayer,
    required DailySalahLog? log,
  }) {
    final status = log?.status ?? DailySalahStatus.unrecorded;
    final prayedSelected = status == DailySalahStatus.prayed;
    final missedSelected = status == DailySalahStatus.missed;
    final theme = Theme.of(context);

    return Card(
      key: Key('daily_salah_prayer_\${prayer.name}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _localizedPrayerName(l10n, prayer),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: prayedSelected
                      ? FilledButton(
                          key: Key('daily_salah_prayed_\${prayer.name}'),
                          onPressed: () => _setPrayed(prayer, status),
                          child: Text(l10n.dailySalahTrackingPrayed),
                        )
                      : OutlinedButton(
                          key: Key('daily_salah_prayed_' + prayer.name),
                          onPressed: () => _setPrayed(prayer, status),
                          child: Text(l10n.dailySalahTrackingPrayed),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: missedSelected
                      ? FilledButton(
                          key: Key('daily_salah_missed_\${prayer.name}'),
                          onPressed: () => _confirmMissed(prayer),
                          child: Text(l10n.dailySalahTrackingMissed),
                        )
                      : OutlinedButton(
                          key: Key('daily_salah_missed_' + prayer.name),
                          onPressed: () => _confirmMissed(prayer),
                          child: Text(l10n.dailySalahTrackingMissed),
                        ),
                ),
              ],
            ),
            if (log?.trackerCreatedQazaId != null)
              FutureBuilder<bool>(
                future: ref
                    .read(dailySalahTrackingServiceProvider)
                    .canUndoTrackerCreatedQaza(
                      userId: log!.userId,
                      prayerType: prayer,
                      date: _selectedDate,
                    ),
                builder: (context, snapshot) {
                  if (snapshot.data != true) return const SizedBox.shrink();
                  return Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      key: Key('daily_salah_undo_\${prayer.name}'),
                      onPressed: () => _confirmUndo(prayer),
                      child: Text(l10n.dailySalahTrackingUndoQaza),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _setPrayed(
    PrayerType prayer,
    DailySalahStatus currentStatus,
  ) async {
    final userId = ref.read(activeUserIdProvider);
    if (userId == null) return;
    final nextStatus = currentStatus == DailySalahStatus.prayed
        ? DailySalahStatus.unrecorded
        : DailySalahStatus.prayed;
    try {
      await ref.read(dailySalahTrackingServiceProvider).setStatus(
            userId: userId,
            prayerType: prayer,
            date: _selectedDate,
            status: nextStatus,
          );
      ref.invalidate(dailySalahTrackingLogsProvider(_selectedDate));
    } catch (_) {
      if (!mounted) return;
      ref
          .read(appSnackbarServiceProvider)
          .error(AppLocalizations.of(context).errorStorage);
    }
  }

  Future<void> _confirmMissed(PrayerType prayer) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.dailySalahTrackingConfirmMissedTitle),
        content: Text(l10n.dailySalahTrackingConfirmMissedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('daily_salah_confirm_missed'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonContinue),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final userId = ref.read(activeUserIdProvider);
    if (userId == null) return;
    try {
      await ref.read(dailySalahTrackingServiceProvider).recordMissed(
            userId: userId,
            prayerType: prayer,
            date: _selectedDate,
          );
      ref.invalidate(dailySalahTrackingLogsProvider(_selectedDate));
      ref.invalidate(dailySalahTrackingEnabledProvider);
      ref.invalidate(progressSummaryProvider);
    } catch (_) {
      if (!mounted) return;
      ref
          .read(appSnackbarServiceProvider)
          .error(AppLocalizations.of(context).errorStorage);
    }
  }

  Future<void> _confirmUndo(PrayerType prayer) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.dailySalahTrackingUndoTitle),
        content: Text(l10n.dailySalahTrackingUndoMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.dailySalahTrackingUndoQaza),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final userId = ref.read(activeUserIdProvider);
    if (userId == null) return;
    try {
      final deleted = await ref
          .read(dailySalahTrackingServiceProvider)
          .undoTrackerCreatedQaza(
            userId: userId,
            prayerType: prayer,
            date: _selectedDate,
          );
      if (!mounted) return;
      ref.invalidate(dailySalahTrackingLogsProvider(_selectedDate));
      ref.invalidate(progressSummaryProvider);
      if (!deleted) {
        ref
            .read(appSnackbarServiceProvider)
            .error(l10n.dailySalahTrackingUndoUnavailable);
      }
    } catch (_) {
      if (!mounted) return;
      ref
          .read(appSnackbarServiceProvider)
          .error(AppLocalizations.of(context).errorStorage);
    }
  }

  Future<void> _pickDate() async {
    final today = _dayOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isAfter(today) ? today : _selectedDate,
      firstDate: DateTime(1900),
      lastDate: today,
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = _dayOnly(picked));
  }

  void _changeDay(int amount) {
    final next = _dayOnly(_selectedDate.add(Duration(days: amount)));
    if (next.isAfter(_dayOnly(DateTime.now()))) return;
    setState(() => _selectedDate = next);
  }

  bool get _isToday => _selectedDate == _dayOnly(DateTime.now());

  static DateTime _dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _localizedPrayerName(
    AppLocalizations l10n,
    PrayerType prayer,
  ) =>
      switch (prayer) {
        PrayerType.fajr => l10n.prayerFajr,
        PrayerType.zuhr => l10n.prayerZuhr,
        PrayerType.asr => l10n.prayerAsr,
        PrayerType.maghrib => l10n.prayerMaghrib,
        PrayerType.isha => l10n.prayerIsha,
        PrayerType.witr => l10n.prayerWitr,
      };
}
