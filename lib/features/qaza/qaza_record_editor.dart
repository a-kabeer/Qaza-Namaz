import 'package:flutter/material.dart';

import '../../core/constants/prayer_types.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/utils/qaza_date.dart';
import '../../core/widgets/app_spacing.dart';
import '../../domain/entities/qaza_record.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';

Future<QazaRecord?> showQazaRecordEditor(
  BuildContext context, {
  required QazaRecord record,
}) =>
    showModalBottomSheet<QazaRecord?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _QazaRecordEditor(record: record),
    );

class _QazaRecordEditor extends StatefulWidget {
  const _QazaRecordEditor({required this.record});

  final QazaRecord record;

  @override
  State<_QazaRecordEditor> createState() => _QazaRecordEditorState();
}

class _QazaRecordEditorState extends State<_QazaRecordEditor> {
  late PrayerType _prayerType = widget.record.prayerType;
  late DateTime _originalDate = QazaDate.normalize(widget.record.originalDate);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDate: _originalDate.isAfter(now) ? now : _originalDate,
      helpText: AppLocalizations.of(context).qazaEditDateHelp,
    );
    if (picked == null || !mounted) return;
    setState(() => _originalDate = QazaDate.normalize(picked));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.qazaEditRecordTitle,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          DropdownButtonFormField<PrayerType>(
            key: const Key('qaza_record_edit_prayer'),
            initialValue: _prayerType,
            decoration: InputDecoration(
              labelText: l10n.qazaEditPrayer,
            ),
            items: [
              for (final prayer in PrayerType.values)
                DropdownMenuItem(
                  value: prayer,
                  child: Text(prayer.localizedLabel(l10n)),
                ),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _prayerType = value);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            key: const Key('qaza_record_edit_date'),
            onPressed: _pickDate,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              alignment: AlignmentDirectional.centerStart,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.qazaEditDate,
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  DateFormatters.formatGregorianDatePadded(_originalDate),
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  DateFormatters.hijriLabel(_originalDate),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            key: const Key('qaza_record_edit_save'),
            onPressed: () {
              Navigator.of(context).pop(
                widget.record.copyWith(
                  prayerType: _prayerType,
                  originalDate: _originalDate,
                ),
              );
            },
            child: Text(l10n.qazaSaveChanges),
          ),
        ],
      ),
    );
  }
}
