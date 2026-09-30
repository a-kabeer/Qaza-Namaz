import 'package:flutter/material.dart';

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
    final scheme = theme.colorScheme;

    return AlertDialog(
      title: Text(l10n.profileQazaPlanChangedTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.profileQazaPlanSummary),
            const SizedBox(height: 20),
            _StatRow(
              label: l10n.profileQazaPreviousTotal,
              value: (preview.previousLedgerPlan?.totalWithWitr ?? 0).toString(),
            ),
            _StatRow(
              label: l10n.profileQazaNewTotal,
              value: preview.newPlanTotal.toString(),
            ),
            _StatRow(
              label: l10n.profileQazaCompletedInPlan,
              value: preview.existingCompletedInNewPlan.toString(),
            ),
            _StatRow(
              label: l10n.profileQazaToAdd,
              value: preview.pendingToAdd.toString(),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.profileQazaCompletedProtected,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('profile_qaza_keep_existing'),
          onPressed: () => Navigator.of(context).pop(
            ProfileQazaChangeChoice.keepExisting,
          ),
          child: Text(l10n.profileQazaKeepExisting),
        ),
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

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 16),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
