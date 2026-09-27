import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../application/prayer_time_providers.dart';
import '../domain/prayer_settings.dart';

class PrayerSettingsPage extends ConsumerStatefulWidget {
  const PrayerSettingsPage({super.key});

  @override
  ConsumerState<PrayerSettingsPage> createState() => _PrayerSettingsPageState();
}

class _PrayerSettingsPageState extends ConsumerState<PrayerSettingsPage> {
  late PrayerSettings _settings;
  late final TextEditingController _fajrAngleController;
  late final TextEditingController _ishaAngleController;
  final Map<PrayerSlotKey, TextEditingController> _adjustmentControllers = {};

  @override
  void initState() {
    super.initState();
    _settings = ref.read(prayerTimeControllerProvider).valueOrNull?.settings ??
        const PrayerSettings();
    _fajrAngleController =
        TextEditingController(text: _settings.fajrAngle.toString());
    _ishaAngleController =
        TextEditingController(text: _settings.ishaAngle.toString());
    for (final slot in PrayerSlotKey.values) {
      _adjustmentControllers[slot] = TextEditingController(
        text: (_settings.adjustments[slot.name] ?? 0).toString(),
      );
    }
  }

  @override
  void dispose() {
    _fajrAngleController.dispose();
    _ishaAngleController.dispose();
    for (final controller in _adjustmentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _methodLabel(
    AppLocalizations l10n,
    PrayerCalculationMethod value,
  ) =>
      switch (value) {
        PrayerCalculationMethod.karachi => 'Karachi',
        PrayerCalculationMethod.muslimWorldLeague => 'Muslim World League',
        PrayerCalculationMethod.isna => 'ISNA',
        PrayerCalculationMethod.makkah => 'Makkah',
        PrayerCalculationMethod.egypt => 'Egypt',
        PrayerCalculationMethod.tehran => 'Tehran',
        PrayerCalculationMethod.custom => l10n.prayerTimeCustom,
      };

  String _highLatitudeLabel(
    AppLocalizations l10n,
    PrayerHighLatitudeRule value,
  ) =>
      switch (value) {
        PrayerHighLatitudeRule.automatic => l10n.prayerTimeAutomatic,
        PrayerHighLatitudeRule.middleOfTheNight =>
          l10n.prayerTimeMiddleOfTheNight,
        PrayerHighLatitudeRule.seventhOfTheNight =>
          l10n.prayerTimeSeventhOfTheNight,
        PrayerHighLatitudeRule.twilightAngle =>
          l10n.prayerTimeTwilightAngle,
      };

  String _slotLabel(AppLocalizations l10n, PrayerSlotKey slot) =>
      switch (slot) {
        PrayerSlotKey.fajr => l10n.prayerTimeFajr,
        PrayerSlotKey.sunrise => l10n.prayerTimeSunrise,
        PrayerSlotKey.dhuhr => l10n.prayerTimeDhuhr,
        PrayerSlotKey.asr => l10n.prayerTimeAsr,
        PrayerSlotKey.maghrib => l10n.prayerTimeMaghrib,
        PrayerSlotKey.isha => l10n.prayerTimeIsha,
      };

  Future<void> _save() async {
    final adjustments = <String, int>{};
    for (final entry in _adjustmentControllers.entries) {
      final value = int.tryParse(entry.value.text.trim());
      if (value != null && value != 0) {
        adjustments[entry.key.name] = value;
      }
    }

    final settings = _settings.copyWith(
      fajrAngle: double.tryParse(_fajrAngleController.text.trim()),
      ishaAngle: double.tryParse(_ishaAngleController.text.trim()),
      adjustments: adjustments,
    );
    await ref
        .read(prayerTimeControllerProvider.notifier)
        .updateSettings(settings);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refreshing = ref.watch(prayerTimeRefreshProvider);

    return AppScaffold(
      title: l10n.prayerTimeSettings,
      actions: [
        IconButton(
          tooltip: l10n.prayerTimeSave,
          onPressed: refreshing ? null : _save,
          icon: const Icon(Icons.check_rounded),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<PrayerCalculationMethod>(
            initialValue: _settings.calculationMethod,
            decoration: InputDecoration(
              labelText: l10n.prayerTimeCalculationMethod,
            ),
            items: [
              for (final value in PrayerCalculationMethod.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(_methodLabel(l10n, value)),
                ),
            ],
            onChanged: refreshing
                ? null
                : (value) {
                    if (value == null) return;
                    setState(
                      () => _settings =
                          _settings.copyWith(calculationMethod: value),
                    );
                  },
          ),
          const SizedBox(height: 12),
          if (_settings.calculationMethod ==
              PrayerCalculationMethod.custom) ...[
            Text(
              l10n.prayerTimeAngleHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _fajrAngleController,
              enabled: !refreshing,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.prayerTimeFajrAngle,
                suffixText: '°',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ishaAngleController,
              enabled: !refreshing,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.prayerTimeIshaAngle,
                suffixText: '°',
              ),
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<PrayerAsrMethod>(
            initialValue: _settings.asrMethod,
            decoration: InputDecoration(labelText: l10n.prayerTimeAsrMethod),
            items: [
              DropdownMenuItem(
                value: PrayerAsrMethod.standard,
                child: Text(l10n.prayerTimeStandard),
              ),
              DropdownMenuItem(
                value: PrayerAsrMethod.hanafi,
                child: Text(l10n.prayerTimeHanafi),
              ),
            ],
            onChanged: refreshing
                ? null
                : (value) {
                    if (value == null) return;
                    setState(
                      () => _settings =
                          _settings.copyWith(asrMethod: value),
                    );
                  },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<PrayerHighLatitudeRule>(
            initialValue: _settings.highLatitudeRule,
            decoration: InputDecoration(
              labelText: l10n.prayerTimeHighLatitudeRule,
            ),
            items: [
              for (final value in PrayerHighLatitudeRule.values)
                DropdownMenuItem(
                  value: value,
                  child: Text(_highLatitudeLabel(l10n, value)),
                ),
            ],
            onChanged: refreshing
                ? null
                : (value) {
                    if (value == null) return;
                    setState(
                      () => _settings =
                          _settings.copyWith(highLatitudeRule: value),
                    );
                  },
          ),
          const SizedBox(height: 16),
          Text(
            l10n.prayerTimeAdjustments,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          for (final slot in PrayerSlotKey.values) ...[
            TextField(
              controller: _adjustmentControllers[slot],
              enabled: !refreshing,
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: _slotLabel(l10n, slot),
                suffixText: l10n.prayerTimeAdjustmentMinutes,
              ),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(l10n.prayerTime12Hour),
              ),
              ButtonSegment(
                value: true,
                label: Text(l10n.prayerTime24Hour),
              ),
            ],
            selected: {_settings.use24HourFormat},
            onSelectionChanged: refreshing
                ? null
                : (value) {
                    setState(
                      () => _settings =
                          _settings.copyWith(use24HourFormat: value.first),
                    );
                  },
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: refreshing ? null : _save,
            icon: const Icon(Icons.save_rounded),
            label: Text(l10n.prayerTimeSave),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.prayerTimeLocationData,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.prayerTimeLocationDataAttribution,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

enum PrayerSlotKey { fajr, sunrise, dhuhr, asr, maghrib, isha }
