import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calendar/hijri_date_service.dart';
import '../../core/constants/prayer_types.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/services/qaza_plan_service.dart';
import '../../l10n/app_localizations.dart';
import '../qaza/qaza_import_controller.dart';

enum QazaReviewAction { edit, add }

typedef QazaReviewConfirm = Future<bool> Function();

class QazaReviewDialog extends ConsumerStatefulWidget {
  const QazaReviewDialog({
    super.key,
    required this.profile,
    required this.plan,
    required this.onConfirm,
  });

  final UserProfile profile;
  final QazaPlan plan;
  final QazaReviewConfirm onConfirm;

  @override
  ConsumerState<QazaReviewDialog> createState() => _QazaReviewDialogState();
}

class _QazaReviewDialogState extends ConsumerState<QazaReviewDialog> {
  bool _starting = false;
  bool _watchingImport = false;
  bool _didComplete = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final started = await widget.onConfirm();
      if (!mounted) return;
      if (!started) {
        setState(() {
          _starting = false;
          _error = AppLocalizations.of(context).qazaReviewError;
        });
        return;
      }
      setState(() {
        _watchingImport = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = AppLocalizations.of(context).qazaReviewError;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    final started = ref.read(qazaImportProvider.notifier).retry();
    if (!started && mounted) {
      setState(() {
        _starting = false;
        _error = AppLocalizations.of(context).qazaReviewError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final importState = ref.watch(qazaImportProvider);
    final importIsActive = importState.isActive;
    final importFailed =
        _watchingImport && importState.phase == QazaImportTaskPhase.failed;

    if (_watchingImport &&
        importState.phase == QazaImportTaskPhase.completed &&
        !_didComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _didComplete) return;
        _didComplete = true;
        Navigator.of(context).pop(QazaReviewAction.add);
      });
    }

    final actionsBusy = _starting || importIsActive;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.qazaReviewTitle),
            const SizedBox(height: 4),
            Text(
              l10n.qazaReviewSubtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: (MediaQuery.sizeOf(context).height - 180)
                .clamp(420.0, 620.0)
                .toDouble(),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTotal(context, l10n),
                const SizedBox(height: 16),
                _buildSummary(context, l10n),
                const SizedBox(height: 16),
                _buildBreakdown(context, l10n),
                const SizedBox(height: 12),
                Text(
                  l10n.qazaReviewNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_watchingImport && (importIsActive || importFailed)) ...[
                  const SizedBox(height: 12),
                  _buildImportStatus(context, l10n, importState),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  key: const Key('qaza_review_edit'),
                  onPressed: actionsBusy
                      ? null
                      : () => Navigator.of(context).pop(QazaReviewAction.edit),
                  child: Text(l10n.qazaReviewEdit),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const Key('qaza_review_add'),
                  onPressed: importFailed
                      ? _retry
                      : (actionsBusy ? null : _confirm),
                  child: Text(
                    importFailed
                        ? l10n.commonRetry
                        : (actionsBusy
                            ? l10n.qazaReviewAdding
                            : l10n.qazaReviewAdd),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImportStatus(
    BuildContext context,
    AppLocalizations l10n,
    QazaImportTaskState importState,
  ) {
    final progress = importState.progress;
    final failed = importState.phase == QazaImportTaskPhase.failed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          failed ? l10n.qazaReviewError : l10n.qazaReviewAdding,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress),
        if (progress != null) ...[
          const SizedBox(height: 6),
          Text(
            ${importState.processed} / ${importState.total},
          ),
        ],
      ],
    );
  }

  Widget _buildTotal(BuildContext context, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          label: l10n.qazaReviewTotal,
          value: widget.plan.totalWithWitr.toString(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.plan.totalWithWitr.toString(),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 2),
              Text(l10n.qazaReviewTotal),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.profileMadhab,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 2),
        Text(_madhabLabel(l10n, widget.profile.madhab!)),
        const SizedBox(height: 12),
        Text(
          l10n.qazaReviewPeriod,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Text(
          ${_formatGregorian(widget.plan.startDate)} – ${_formatGregorian(widget.plan.endDate)},
        ),
        const SizedBox(height: 2),
        Text(
          ${_formatHijri(l10n, widget.plan.startDate)} – ${_formatHijri(l10n, widget.plan.endDate)},
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildBreakdown(BuildContext context, AppLocalizations l10n) {
    final rows = <(String, int)>[
      (l10n.prayerFajr, widget.plan.prayerBreakdown[PrayerType.fajr] ?? 0),
      (l10n.prayerZuhr, widget.plan.prayerBreakdown[PrayerType.zuhr] ?? 0),
      (l10n.prayerAsr, widget.plan.prayerBreakdown[PrayerType.asr] ?? 0),
      (
        l10n.prayerMaghrib,
        widget.plan.prayerBreakdown[PrayerType.maghrib] ?? 0
      ),
      (l10n.prayerIsha, widget.plan.prayerBreakdown[PrayerType.isha] ?? 0),
      (l10n.prayerWitr, widget.plan.witrCount),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.qazaReviewBreakdown,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        for (final row in rows)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(row.$1),
            trailing: Text(
              row.$2.toString(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
      ],
    );
  }

  String _madhabLabel(AppLocalizations l10n, Madhab madhab) => switch (madhab) {
        Madhab.hanafi => l10n.profileHanafi,
        Madhab.shafi => l10n.profileShafi,
        Madhab.maliki => l10n.profileMaliki,
        Madhab.hanbali => l10n.profileHanbali,
        Madhab.other => l10n.profileOther,
      };

  String _formatGregorian(DateTime date) =>
      ${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year.toString()};

  String _formatHijri(AppLocalizations l10n, DateTime date) =>
      l10n.formatHijriDate(date);
}
