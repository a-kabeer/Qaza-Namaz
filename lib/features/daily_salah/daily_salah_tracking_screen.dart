import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../l10n/app_localizations.dart';
import 'daily_salah_tracking_providers.dart';
import 'daily_salah_tracking_service.dart';
import '../home/home_controller.dart';
import '../qaza/qaza_tracker_controller.dart';

class DailySalahTrackingScreen extends ConsumerStatefulWidget {
  const DailySalahTrackingScreen({super.key});

  @override
  ConsumerState<DailySalahTrackingScreen> createState() =>
      _DailySalahTrackingScreenState();
}

class _DailySalahTrackingScreenState
    extends ConsumerState<DailySalahTrackingScreen> {
  /// Null means the screen follows the active Fajr-based tracking date.
  DateTime? _selectedDate;
  double _horizontalDragDistance = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trackingDate = ref.watch(dailySalahTrackingDateProvider);
    final selectedDate = _selectedDate ?? trackingDate;
    final logs = ref.watch(dailySalahTrackingLogsProvider(selectedDate));
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
            GestureDetector(
              key: const Key('daily_salah_calendar_swipe'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (_) {
                _horizontalDragDistance = 0;
              },
              onHorizontalDragUpdate: (details) {
                _horizontalDragDistance += details.delta.dx;
              },
              onHorizontalDragEnd: (_) {
                final distance = _horizontalDragDistance;
                _horizontalDragDistance = 0;
                if (distance < -40) {
                  _changeDay(1, trackingDate);
                } else if (distance > 40) {
                  _changeDay(-1, trackingDate);
                }
              },
              onHorizontalDragCancel: () {
                _horizontalDragDistance = 0;
              },
              child: Card(
                key: const Key('daily_salah_calendar'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        key: const Key('daily_salah_previous_day'),
                        tooltip: l10n.dailySalahTrackingPreviousDay,
                        onPressed: () => _changeDay(-1, trackingDate),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          key: const Key('daily_salah_select_date'),
                          onPressed: () =>
                              _pickDate(selectedDate, trackingDate),
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text(
                            DateFormat.yMMMd(locale).format(selectedDate),
                            key: const Key('daily_salah_selected_date'),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('daily_salah_next_day'),
                        tooltip: l10n.dailySalahTrackingNextDay,
                        onPressed: _isTrackingDate(selectedDate, trackingDate)
                            ? null
                            : () => _changeDay(1, trackingDate),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
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
                selectedDate: selectedDate,
                isAvailable: ref.watch(
                  dailySalahPrayerAvailableProvider((
                    date: selectedDate,
                    trackingDate: trackingDate,
                    prayerType: prayer,
                  )),
                ),
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
    required DateTime selectedDate,
    required bool isAvailable,
  }) {
    final status = log?.status ?? DailySalahStatus.unrecorded;
    final prayedSelected = status == DailySalahStatus.prayed;
    final missedSelected = status == DailySalahStatus.missed;
    final theme = Theme.of(context);

    return Card(
      key: Key('daily_salah_prayer_' + prayer.name),
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
                          key: Key('daily_salah_prayed_' + prayer.name),
                          onPressed: isAvailable ? () {} : null,
                          child: Text(l10n.dailySalahTrackingPrayed),
                        )
                      : OutlinedButton(
                          key: Key('daily_salah_prayed_' + prayer.name),
                          onPressed: isAvailable
                              ? () => _setPrayed(
                                    prayer,
                                    status,
                                    selectedDate,
                                  )
                              : null,
                          child: Text(l10n.dailySalahTrackingPrayed),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: missedSelected
                      ? FilledButton(
                          key: Key('daily_salah_missed_' + prayer.name),
                          onPressed: isAvailable ? () {} : null,
                          child: Text(l10n.dailySalahTrackingMissed),
                        )
                      : OutlinedButton(
                          key: Key('daily_salah_missed_' + prayer.name),
                          onPressed: isAvailable
                              ? () => _confirmMissed(prayer, selectedDate)
                              : null,
                          child: Text(l10n.dailySalahTrackingMissed),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setPrayed(
    PrayerType prayer,
    DailySalahStatus currentStatus,
    DateTime date,
  ) async {
    if (currentStatus == DailySalahStatus.prayed) return;
    if (currentStatus == DailySalahStatus.missed) {
      await _confirmPrayed(prayer, date);
      return;
    }
    await _saveStatus(prayer, date, DailySalahStatus.prayed);
  }

  Future<void> _confirmPrayed(
    PrayerType prayer,
    DateTime date,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.dailySalahTrackingConfirmPrayedTitle),
        content: Text(l10n.dailySalahTrackingConfirmPrayedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('daily_salah_confirm_change_to_prayed'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonContinue),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _saveStatus(prayer, date, DailySalahStatus.prayed);
  }

  Future<void> _saveStatus(
    PrayerType prayer,
    DateTime date,
    DailySalahStatus status,
  ) async {
    final userId = ref.read(activeUserIdProvider);
    if (userId == null) return;
    try {
      await ref.read(dailySalahTrackingServiceProvider).setStatus(
            userId: userId,
            prayerType: prayer,
            date: date,
            status: status,
          );
      ref.invalidate(dailySalahTrackingLogsProvider(date));
      ref.invalidate(progressSummaryProvider);
      ref.invalidate(qazaTrackerControllerProvider(null));
      ref.read(homeControllerProvider).invalidateDashboard();
    } catch (_) {
      if (!mounted) return;
      ref
          .read(appSnackbarServiceProvider)
          .error(AppLocalizations.of(context).errorStorage);
    }
  }

  Future<void> _confirmMissed(PrayerType prayer, DateTime date) async {
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
            date: date,
          );
      ref.invalidate(dailySalahTrackingLogsProvider(date));
      ref.invalidate(progressSummaryProvider);
      ref.invalidate(dailySalahTrackingEnabledProvider);
      ref.invalidate(qazaTrackerControllerProvider(null));
      ref.read(homeControllerProvider).invalidateDashboard();
    } catch (_) {
      if (!mounted) return;
      ref
          .read(appSnackbarServiceProvider)
          .error(AppLocalizations.of(context).errorStorage);
    }
  }

  Future<void> _pickDate(
    DateTime selectedDate,
    DateTime trackingDate,
  ) async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: CalendarDatePicker(
          initialDate:
              selectedDate.isAfter(trackingDate) ? trackingDate : selectedDate,
          firstDate: DateTime(1900),
          lastDate: trackingDate,
          onDateChanged: (date) => Navigator.of(dialogContext).pop(date),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _selectDate(picked, trackingDate);
  }

  void _changeDay(int amount, DateTime trackingDate) {
    final current = _selectedDate ?? trackingDate;
    final next = _dayOnly(current.add(Duration(days: amount)));
    if (next.isAfter(_dayOnly(trackingDate))) return;
    _selectDate(next, trackingDate);
  }

  void _selectDate(DateTime date, DateTime trackingDate) {
    final selected = _dayOnly(date);
    setState(() {
      _selectedDate = _isTrackingDate(selected, trackingDate) ? null : selected;
    });
  }

  bool _isTrackingDate(DateTime date, DateTime trackingDate) =>
      _dayOnly(date) == _dayOnly(trackingDate);

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
