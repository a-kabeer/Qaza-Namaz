import 'package:flutter/material.dart';

import '../../core/calendar/hijri_date_service.dart';
import '../../core/utils/date_formatters.dart';
import '../../domain/services/profile_qaza_plan_reconciliation_service.dart';
import '../../l10n/app_localizations.dart';

Future<ProfileQazaChangeChoice?> showProfileQazaChangeDialog({
  required BuildContext context,
  required ProfileQazaPlanPreview preview,
}) {
  return showDialog<ProfileQazaChangeChoice>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ProfileQazaChangeDialog(preview: preview),
  );
}

class _ProfileQazaChangeDialog extends StatelessWidget {
  const _ProfileQazaChangeDialog({required this.preview});

  final ProfileQazaPlanPreview preview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final previousPlan = preview.previousLedgerPlan;

    return AlertDialog(
      title: Text(l10n.profileQazaPlanChangedTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.profileQazaPlanSummary,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _PlanSummary(
                title: l10n.profileQazaPreviousTotal,
                total: previousPlan?.totalWithWitr ?? 0,
                start: previousPlan?.startDate,
                end: previousPlan?.endDate,
              ),
              const SizedBox(height: 24),
              _PlanSummary(
                title: l10n.profileQazaNewTotal,
                total: preview.newPlanTotal,
                start: preview.newPlan.startDate,
                end: preview.newPlan.endDate,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.profileQazaImpact,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _ImpactRow(
                label: l10n.profileQazaCompletedInPlan,
                value: DateFormatters.formatCount(
                  preview.existingCompletedInNewPlan,
                ),
              ),
              _ImpactRow(
                label: l10n.profileQazaToAdd,
                value: DateFormatters.formatCount(preview.pendingToAdd),
              ),
              _ImpactRow(
                label: l10n.profileQazaNoLongerRequired,
                value: DateFormatters.formatCount(preview.pendingToRemove),
              ),
              const SizedBox(height: 16),
              _ProtectionNote(
                text: l10n.profileQazaCompletedProtected,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('profile_qaza_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('profile_qaza_apply'),
          onPressed: () => Navigator.of(context).pop(
            ProfileQazaChangeChoice.apply,
          ),
          child: Text(l10n.profileQazaApply),
        ),
      ],
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({
    required this.title,
    required this.total,
    this.start,
    this.end,
  });

  final String title;
  final int total;
  final DateTime? start;
  final DateTime? end;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.profileQazaCount(
            DateFormatters.formatCount(total),
          ),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (start != null) ...[
          const SizedBox(height: 6),
          Text(
            _formatGregorianPlanRange(start!, end),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _formatHijriPlanRange(l10n, start!, end),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtectionNote extends StatelessWidget {
  const _ProtectionNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_outlined,
            size: 20,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatGregorianPlanRange(DateTime start, DateTime? end) {
  final last = _lastPlanDate(start, end);
  final startText = DateFormatters.formatGregorianDatePadded(start);
  final lastText = DateFormatters.formatGregorianDatePadded(last);

  return start == last ? startText : '$startText – $lastText';
}

String _formatHijriPlanRange(
  AppLocalizations l10n,
  DateTime start,
  DateTime? end,
) {
  final last = _lastPlanDate(start, end);
  final startText = HijriDateService.format(start, l10n);
  final lastText = HijriDateService.format(last, l10n);

  return start == last ? startText : '$startText – $lastText';
}

DateTime _lastPlanDate(DateTime start, DateTime? end) {
  if (end == null || !end.isAfter(start)) return start;

  final last = end.subtract(const Duration(days: 1));
  return last.isBefore(start) ? start : last;
}
