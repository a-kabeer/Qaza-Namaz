
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/local_account.dart';
import '../../core/widgets/app_scaffold.dart';
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
          Card(
            child: ListTile(
              leading: Icon(
                account?.isGoogle == true
                    ? Icons.account_circle_outlined
                    : Icons.person_outline_rounded,
              ),
              title: Text(
                account?.isGoogle == true
                    ? l10n.accountGoogle
                    : l10n.accountGuest,
              ),
              subtitle: account?.isGoogle == true
                  ? Text(account?.googleEmail ?? '')
                  : Text(l10n.accountGuest),
            ),
          ),
          const SizedBox(height: 12),
          if (account?.isGuest == true)
            FilledButton.icon(
              key: const Key('account_connect_google'),
              onPressed: session.state.phase == AccountSessionPhase.connecting
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
              icon: const Icon(Icons.login_rounded),
              label: Text(l10n.accountConnectGoogle),
            )
          else if (account?.isGoogle == true) ...[
            Card(
              child: SwitchListTile(
                title: Text(l10n.accountCloudBackup),
                subtitle: Text(
                  account!.cloudBackupEnabled
                      ? l10n.accountAutomatic
                      : l10n.accountBackupPaused,
                ),
                value: account.cloudBackupEnabled,
                onChanged: (value) async {
                  if (value) {
                    await ref
                        .read(accountSessionManagerProvider.notifier)
                        .enableBackup();
                  } else {
                    await ref
                        .read(accountSessionManagerProvider.notifier)
                        .disconnect();
                  }
                },
              ),
            ),
            if (!account.cloudBackupEnabled)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: OutlinedButton(
                  onPressed: () => ref
                      .read(accountSessionManagerProvider.notifier)
                      .enableBackup(),
                  child: Text(l10n.accountEnableBackup),
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ref
                  .read(accountSessionManagerProvider.notifier)
                  .disconnect(),
              child: Text(l10n.accountDisconnect),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref
                  .read(accountSessionManagerProvider.notifier)
                  .signOut(),
              child: Text(l10n.accountSignOut),
            ),
            const SizedBox(height: 8),
            DestructiveActionButton(
              onPressed: () => _confirmDelete(context, ref),
              label: l10n.accountDeleteCloudData,
            ),
          ],
        ],
      ),
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
