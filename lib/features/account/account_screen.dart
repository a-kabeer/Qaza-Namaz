import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/local_account.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/settings_components.dart';
import '../../core/widgets/section_header.dart';
import '../../l10n/app_localizations.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    var acknowledged = false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.accountDeleteCloudData),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.accountDeleteCloudDataMessage),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: acknowledged,
                onChanged: (value) =>
                    setState(() => acknowledged = value ?? false),
                title: Text(l10n.accountDeleteCloudDataAcknowledge),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.accountCancel),
            ),
            FilledButton(
              onPressed: acknowledged
                  ? () => Navigator.pop(dialogContext, true)
                  : null,
              child: Text(l10n.accountDeleteCloudData),
            ),
          ],
        ),
      ),
    );
    if (result != true || !context.mounted) return;

    try {
      await ref.read(accountSessionManagerProvider.notifier).deleteCloudData();
      if (!context.mounted) return;
      ref.read(appSnackbarServiceProvider).success(l10n.accountCloudDeleted);
    } catch (_) {
      if (!context.mounted) return;
      ref.read(appSnackbarServiceProvider).error(l10n.cloudDeleteFailed);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(accountSessionManagerProvider);
    final account = session.activeAccount;

    return AppScaffold(
      title: l10n.accountTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _AccountIdentityCard(account: account),
          const SizedBox(height: 20),
          if (account?.isGuest == true)
            _GuestAccountContent(
              onConnectGoogle: session.state.phase ==
                      AccountSessionPhase.connecting
                  ? null
                  : () async {
                      try {
                        await ref
                            .read(accountSessionManagerProvider.notifier)
                            .connectGoogle();
                      } catch (_) {
                        if (!context.mounted) return;
                        ref
                            .read(appSnackbarServiceProvider)
                            .error(l10n.accountConnectFailed);
                      }
                    },
            )
          else if (account?.isGoogle == true)
            _GoogleAccountContent(
              account: account!,
              onEnableBackup: () => ref
                  .read(accountSessionManagerProvider.notifier)
                  .enableBackup(),
              onPauseBackup: () => ref
                  .read(accountSessionManagerProvider.notifier)
                  .pauseBackup(),
              onSignOut: () =>
                  ref.read(accountSessionManagerProvider.notifier).signOut(),
              onDisconnect: () =>
                  ref.read(accountSessionManagerProvider.notifier).disconnect(),
              onDeleteCloudData: () => _confirmDelete(context, ref),
            ),
        ],
      ),
    );
  }
}

class _AccountIdentityCard extends StatelessWidget {
  const _AccountIdentityCard({required this.account});

  final LocalAccount? account;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final google = account?.isGoogle == true;
    final title = google ? l10n.accountGoogle : l10n.accountGuest;
    final subtitle =
        google ? (account?.googleEmail ?? '') : l10n.accountGuestLocalDataSubtitle;
    final status = google
        ? l10n.accountSignedIn
        : l10n.accountNotConnectedGoogle;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              google
                  ? Icons.account_circle_outlined
                  : Icons.person_outline_rounded,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Chip(label: Text(status)),
          ],
        ),
      ),
    );
  }
}

class _GuestAccountContent extends StatelessWidget {
  const _GuestAccountContent({required this.onConnectGoogle});

  final VoidCallback? onConnectGoogle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.accountKeepProgressSafe,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(l10n.accountKeepProgressSafeDescription),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const Key('account_connect_google'),
              onPressed: onConnectGoogle,
              icon: const Icon(Icons.login_rounded),
              label: Text(l10n.accountChoiceContinueGoogle),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.accountGuestContinueMessage,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleAccountContent extends StatelessWidget {
  const _GoogleAccountContent({
    required this.account,
    required this.onEnableBackup,
    required this.onPauseBackup,
    required this.onSignOut,
    required this.onDisconnect,
    required this.onDeleteCloudData,
  });

  final LocalAccount account;
  final VoidCallback onEnableBackup;
  final VoidCallback onPauseBackup;
  final VoidCallback onSignOut;
  final VoidCallback onDisconnect;
  final VoidCallback onDeleteCloudData;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: l10n.accountBackupSection,
          child: SwitchListTile(
            title: Text(l10n.accountCloudBackup),
            subtitle: Text(
              account.cloudBackupEnabled
                  ? l10n.accountBackupAutomaticDescription
                  : l10n.accountBackupPaused,
            ),
            value: account.cloudBackupEnabled,
            onChanged: account.cloudBackupEnabled
                ? (_) => onPauseBackup()
                : (_) => onEnableBackup(),
          ),
        ),
        const SizedBox(height: 20),
        SettingsSection(
          title: l10n.accountAccountActions,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: Text(l10n.accountSignOut),
                subtitle: Text(l10n.accountSignOutDescription),
                onTap: onSignOut,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.link_off_rounded),
                title: Text(l10n.accountDisconnect),
                subtitle: Text(l10n.accountDisconnectDescription),
                onTap: onDisconnect,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionHeader(title: l10n.accountDangerZone),
        const SizedBox(height: 8),
        DestructiveActionRow(
          key: const Key('account_delete_cloud_data'),
          icon: Icons.delete_outline_rounded,
          label: l10n.accountDeleteCloudData,
          description: l10n.accountDeleteCloudDataMessage,
          confirmationTitle: l10n.accountDeleteCloudData,
          confirmationMessage: l10n.accountDeleteCloudDataMessage,
          acknowledgeLabel: l10n.accountDeleteCloudDataAcknowledge,
          confirmLabel: l10n.accountDeleteCloudData,
          onConfirm: onDeleteCloudData,
        ),
      ],
    );
  }
}

class DestructiveActionButton extends StatelessWidget {
  const DestructiveActionButton({
    required this.onPressed,
    required this.label,
    super.key,
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) => FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
        ),
        child: Text(label),
      );
}
