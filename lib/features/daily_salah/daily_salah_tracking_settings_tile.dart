import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import 'daily_salah_tracking_providers.dart';

class DailySalahTrackingSettingsTile extends ConsumerWidget {
  const DailySalahTrackingSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final enabled = ref.watch(dailySalahTrackingEnabledProvider);

    return Card(
      child: SwitchListTile(
        key: const Key('daily_salah_tracking_toggle'),
        secondary: const Icon(Icons.checklist_rounded),
        title: Text(l10n.dailySalahTrackingTitle),
        subtitle: Text(l10n.dailySalahTrackingEnableSubtitle),
        value: enabled.valueOrNull ?? false,
        onChanged: enabled.isLoading
            ? null
            : (value) async {
                try {
                  await ref
                      .read(dailySalahTrackingServiceProvider)
                      .setEnabled(value);
                  ref.invalidate(dailySalahTrackingEnabledProvider);
                } catch (_) {
                  if (!context.mounted) return;
                  ref
                      .read(appSnackbarServiceProvider)
                      .error(AppLocalizations.of(context).errorStorage);
                }
              },
      ),
    );
  }
}
