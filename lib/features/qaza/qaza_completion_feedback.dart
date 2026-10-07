import 'package:flutter/material.dart';

import '../../core/utils/date_formatters.dart';
import '../../domain/services/qaza_undo_service.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';

String qazaCompletionSuccessMessage(
  BuildContext context,
  QazaUndoBatch batch,
) {
  final l10n = AppLocalizations.of(context);
  if (batch.entries.length == 1) {
    final entry = batch.entries.single;
    final prayer = entry.prayerType.localizedLabel(l10n);
    final date = DateFormatters.formatGregorianDatePadded(entry.originalDate);
    return l10n.qazaCompletionSingle(prayer, date);
  }
  return l10n.qazaCompletionMultiple(batch.entries.length);
}

String qazaUndoSuccessMessage(
  BuildContext context,
  QazaUndoBatch batch,
  int count,
) {
  final l10n = AppLocalizations.of(context);
  if (count == 1 && batch.entries.length == 1) {
    final entry = batch.entries.single;
    final prayer = entry.prayerType.localizedLabel(l10n);
    final date = DateFormatters.formatGregorianDatePadded(entry.originalDate);
    return l10n.qazaUndoSingle(prayer, date);
  }
  return l10n.qazaUndoMultiple(count);
}

String qazaUndoFailureMessage(
  BuildContext context,
  QazaUndoFailureReason reason,
) {
  final l10n = AppLocalizations.of(context);
  return switch (reason) {
    QazaUndoFailureReason.expired => l10n.qazaUndoExpired,
    QazaUndoFailureReason.staleBatch => l10n.qazaUndoStaleBatch,
    QazaUndoFailureReason.targetChanged => l10n.qazaUndoTargetChanged,
    QazaUndoFailureReason.failed => l10n.qazaUndoFailed,
  };
}
