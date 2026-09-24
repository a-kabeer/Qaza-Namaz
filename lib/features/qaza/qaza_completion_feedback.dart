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
    if (Localizations.localeOf(context).languageCode == 'ur') {
      return '${prayer} کی قضا، ${date} مکمل ہو گئی۔';
    }
    return '${prayer} Qaza for ${date} completed.';
  }
  if (Localizations.localeOf(context).languageCode == 'ur') {
    return '${batch.entries.length} قضا نمازیں مکمل ہو گئیں۔';
  }
  return '${batch.entries.length} Qaza completed.';
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
    if (Localizations.localeOf(context).languageCode == 'ur') {
      return '${prayer} کی قضا، ${date} دوبارہ باقی میں شامل ہو گئی۔';
    }
    return '${prayer} Qaza for ${date} restored.';
  }
  if (Localizations.localeOf(context).languageCode == 'ur') {
    return '${count} قضا نمازیں دوبارہ باقی میں شامل ہو گئی ہیں۔';
  }
  return '${count} Qaza restored.';
}

String qazaUndoFailureMessage(
  BuildContext context,
  QazaUndoFailureReason reason,
) {
  if (Localizations.localeOf(context).languageCode == 'ur') {
    return switch (reason) {
      QazaUndoFailureReason.expired =>
        'واپس کرنے کا 10 سیکنڈ کا وقت ختم ہو گیا۔',
      QazaUndoFailureReason.staleBatch =>
        'واپس کرنے کا یہ اختیار اب دستیاب نہیں کیونکہ اس کے بعد ایک نیا Undo عمل ہوا ہے۔',
      QazaUndoFailureReason.targetChanged =>
        'واپس کرنے کا اختیار دستیاب نہیں کیونکہ قضا ریکارڈ بدل چکا یا حذف ہو چکا ہے۔',
      QazaUndoFailureReason.failed =>
        'قضا واپس نہیں ہو سکی۔ براہِ کرم دوبارہ کوشش کریں۔',
    };
  }

  return switch (reason) {
    QazaUndoFailureReason.expired =>
      'Undo is no longer available because the 10-second window has ended.',
    QazaUndoFailureReason.staleBatch =>
      'Undo is no longer available because a newer Undo action replaced it.',
    QazaUndoFailureReason.targetChanged =>
      'Undo is no longer available because the Qaza record changed or was removed.',
    QazaUndoFailureReason.failed =>
      'Undo could not be completed. Please try again.',
  };
}
