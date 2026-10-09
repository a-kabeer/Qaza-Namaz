import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/services/cloud_sync_contracts.dart';
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
          _AccountInfoCard(
            icon: Icons.phone_android_rounded,
            title: l10n.accountGuestTitle,
            subtitle: l10n.accountGuestLocalDataSubtitle,
            trailing: Chip(label: Text(l10n.accountSignedIn)),
          ),
          const SizedBox(height: 12),
          _AccountInfoCard(
            icon: Icons.lock_outline_rounded,
            title: l10n.accountKeepProgressSafe,
            subtitle: accountId == null
                ? l10n.accountBackupStatusChecking
                : l10n.accountGuestContinueMessage,
          ),
          const SizedBox(height: 16),
          if (ref.watch(cloudAccountProvider).isSupported &&
              ref.watch(cloudSyncProvider).isSupported) ...[
            const _CloudBackupCard(key: Key('account_cloud_backup')),
            const SizedBox(height: 16),
          ],
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

class _AccountInfoCard extends StatelessWidget {
  const _AccountInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(icon, size: 34),
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
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        ),
      );
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


class _CloudBackupCard extends ConsumerStatefulWidget {
  const _CloudBackupCard({super.key});

  @override
  ConsumerState<_CloudBackupCard> createState() => _CloudBackupCardState();
}

class _CloudBackupCardState extends ConsumerState<_CloudBackupCard> {
  CloudAccountSnapshot _account = const CloudAccountSnapshot.disconnected();
  CloudSyncSnapshot _sync = const CloudSyncSnapshot.disconnected();
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_refresh);
  }

  Future<void> _refresh() async {
    final account = await ref.read(cloudAccountProvider).restore();
    final sync = await ref.read(cloudSyncProvider).status();
    if (!mounted) return;
    setState(() {
      _account = account;
      _sync = sync;
      _message = account.message ?? sync.message;
    });
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final account = await ref.read(cloudAccountProvider).signIn();
    final sync = await ref.read(cloudSyncProvider).status();
    if (!mounted) return;
    setState(() {
      _account = account;
      _sync = sync;
      _message = account.message ?? sync.message;
      _busy = false;
    });
  }

  Future<void> _disconnect() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cloudDisconnectConfirmTitle),
        content: Text(l10n.cloudDisconnectConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.cloudDisconnect),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(cloudAccountProvider).disconnect();
      await _refresh();
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _backupNow() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await ref.read(cloudSyncProvider).backupNow();
    if (!mounted) return;
    setState(() {
      _sync = result;
      _message = result.message;
    });
    if (result.status == CloudSyncStatus.conflict && result.conflict != null) {
      await _resolveConflict(result.conflict!);
    } else if (result.status == CloudSyncStatus.synced && mounted) {
      setState(() => _message = AppLocalizations.of(context).cloudBackupSucceeded);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _resolveConflict(CloudConflictInfo conflict) async {
    final l10n = AppLocalizations.of(context);
    final choice = await showDialog<CloudConflictChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cloudBackupConflictTitle),
        content: Text(l10n.cloudBackupConflictMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, CloudConflictChoice.keepLocal),
            child: Text(l10n.cloudKeepLocal),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, CloudConflictChoice.useRemote),
            child: Text(l10n.cloudUseRemote),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    final useRemote = choice == CloudConflictChoice.useRemote;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          useRemote
              ? l10n.cloudUseRemoteConfirmTitle
              : l10n.cloudKeepLocalConfirmTitle,
        ),
        content: Text(
          useRemote
              ? l10n.cloudUseRemoteConfirmMessage
              : l10n.cloudKeepLocalConfirmMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonContinue),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await ref.read(cloudSyncProvider).resolveConflict(
          conflict: conflict,
          choice: choice,
          confirmed: true,
        );
    if (!mounted) return;
    if (useRemote && result.status == CloudSyncStatus.synced) {
      await _refreshAfterRestore();
      if (!mounted) return;
    }
    setState(() {
      _sync = result;
      _message = result.status == CloudSyncStatus.synced
          ? l10n.cloudBackupSucceeded
          : result.message;
    });
  }

  Future<void> _refreshAfterRestore() async {
    // Import replaces the active-account/session rows as well as Qaza data.
    // Reload the session before rebuilding profile and repository providers.
    await ref.read(accountSessionManagerProvider).refresh();
    ref.invalidate(appRouteProvider);
    ref.invalidate(userProfileProvider);
    ref.invalidate(progressSummaryProvider);
    ref.invalidate(qazaRepositoryProvider);
    ref.invalidate(qazaAdditionRepositoryProvider);
    ref.invalidate(qazaPlanRevisionRepositoryProvider);
  }

  Future<void> _toggleAutomaticBackup(bool enabled) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final result =
        await ref.read(cloudSyncProvider).setAutomaticSyncEnabled(enabled);
    if (!mounted) return;
    setState(() {
      _sync = result;
      _message = result.message;
      _busy = false;
    });
  }

  Future<void> _recoverLocalSnapshot() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cloudRecoveryConfirmTitle),
        content: Text(l10n.cloudRecoveryConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.commonContinue),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await ref.read(cloudSyncProvider)
        .restoreLocalRecoverySnapshot(confirmed: true);
    if (result.status == CloudSyncStatus.synced) {
      await _refreshAfterRestore();
      if (!mounted) return;
    }
    setState(() {
      _sync = result;
      _message = result.status == CloudSyncStatus.synced
          ? l10n.cloudBackupSucceeded
          : result.message;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final connected = _account.isConnected;
    final displayName = _account.displayName?.trim().isNotEmpty == true
        ? _account.displayName!.trim()
        : _account.email;
    final lastBackup = _sync.lastSuccessAt == null
        ? l10n.cloudNeverBackedUp
        : MaterialLocalizations.of(context).formatMediumDate(
              _sync.lastSuccessAt!.toLocal(),
            ) +
            ' ' +
            MaterialLocalizations.of(context).formatTimeOfDay(
              TimeOfDay.fromDateTime(_sync.lastSuccessAt!.toLocal()),
            );

    return Card(
      key: const Key('account_cloud_backup_card'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cloud_done_outlined, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.cloudBackupTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        connected
                            ? l10n.cloudConnected + ': ' + (displayName ?? '')
                            : l10n.cloudNotConnected,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!connected)
              FilledButton.icon(
                onPressed: _busy ? null : _connect,
                icon: const Icon(Icons.login_rounded),
                label: Text(l10n.cloudConnect),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _backupNow,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.backup_rounded),
                  label: Text(
                    _busy ? l10n.cloudBackupWorking : l10n.cloudBackupNow,
                  ),
                ),
              ),
              SwitchListTile(
                key: const Key('account_daily_cloud_backup'),
                contentPadding: EdgeInsets.zero,
                value: _sync.automaticSyncEnabled,
                onChanged: _busy ? null : _toggleAutomaticBackup,
                title: Text(l10n.cloudAutomaticBackup),
              ),
              Text(
                l10n.cloudLastBackup + ': ' + lastBackup,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _busy ? null : _disconnect,
                  child: Text(l10n.cloudDisconnect),
                ),
              ),
            ],
            if (_sync.hasLocalRecoverySnapshot) ...[
              const SizedBox(height: 10),
              Text(l10n.cloudRecoveryAvailable),
              TextButton.icon(
                onPressed: _busy ? null : _recoverLocalSnapshot,
                icon: const Icon(Icons.restore_rounded),
                label: Text(l10n.cloudRecoverLocal),
              ),
            ],
            if (_message != null && _message!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _message!,
                style: TextStyle(
                  color: _sync.status == CloudSyncStatus.failed ||
                          _account.status == CloudAccountStatus.failed
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
