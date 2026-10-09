import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/settings_components.dart';
import '../../l10n/app_localizations.dart';
import '../data_management/qaza_data_management_screen.dart';
import '../settings/qaza_reset_controller.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(accountSessionManagerProvider).activeAccount;
    final accountId = account?.localAccountId;

    void open(Widget screen) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => screen),
      );
    }

    return AppScaffold(
      title: l10n.accountTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.phone_android_rounded, size: 34),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.accountGuestTitle,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.accountGuestLocalDataSubtitle,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Chip(label: Text(l10n.accountSignedIn)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SettingsSection(
            title: l10n.accountTitle,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline_rounded),
              title: Text(l10n.accountKeepProgressSafe),
              subtitle: Text(
                accountId == null
                    ? l10n.accountBackupStatusChecking
                    : l10n.accountGuestContinueMessage,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: SettingsNavRow(
              key: const Key('account_data_management'),
              icon: Icons.backup_outlined,
              title: l10n.dataTitle,
              subtitle: l10n.dataExportBody,
              onTap: () => open(const QazaDataManagementScreen()),
            ),
          ),
          const SizedBox(height: 12),
          const _ResetQazaCounterRow(),
        ],
      ),
    );
  }
}

class _ResetQazaCounterRow extends ConsumerWidget {
  const _ResetQazaCounterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summary = ref.watch(progressSummaryProvider).valueOrNull;
    final running = ref.watch(qazaResetControllerProvider).running;
    final total = summary?.overall.total ?? 0;
    final empty = summary != null && total == 0;

    return DestructiveActionRow(
      key: const Key('account_reset_qaza_counter'),
      icon: Icons.restart_alt_rounded,
      label: l10n.settingsResetCounterTitle,
      description: empty
          ? l10n.settingsResetCounterEmpty
          : l10n.settingsResetCounterSubtitle,
      enabled: summary != null && total > 0 && !running,
      confirmationTitle: l10n.settingsResetCounterDialogTitle,
      confirmationMessage: l10n.settingsResetCounterDialogMessage,
      acknowledgeLabel: l10n.settingsResetCounterAcknowledge(total),
      confirmLabel: l10n.settingsResetCounterConfirm,
      onConfirm: () async {
        final done =
            await ref.read(qazaResetControllerProvider.notifier).reset();
        final error = ref.read(qazaResetControllerProvider).error;
        final snackbar = ref.read(appSnackbarServiceProvider);
        if (done) {
          snackbar.success(l10n.settingsResetCounterDone);
        } else {
          snackbar.error(l10n.settingsResetCounterFailed(error ?? ''));
        }
      },
    );
  }
}
