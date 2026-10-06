import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/local/account_local_store.dart';
import '../../domain/entities/local_account.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/settings_components.dart';
import '../../l10n/app_localizations.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final session = ref.watch(accountSessionManagerProvider);
    final account = session.activeAccount;

    ref.listen(
      accountSessionManagerProvider,
      (previous, next) {
        if (previous?.state.phase == AccountSessionPhase.connecting &&
            next.state.phase == AccountSessionPhase.ready &&
            next.state.message != null &&
            context.mounted) {
          ref
              .read(appSnackbarServiceProvider)
              .error(l10n.accountConnectFailed);
        }
      },
    );

    return AppScaffold(
      title: l10n.accountTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _AccountIdentityCard(account: account),
          const SizedBox(height: 20),
          if (account?.isGuest == true)
            _GuestAccountContent(
              onConnectGoogle:
                  session.state.phase == AccountSessionPhase.connecting
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
            _GoogleAccountContent(account: account!),
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
    final title = google ? l10n.accountGoogle : l10n.accountGuestTitle;
    final subtitle = google
        ? (account?.googleEmail ?? '')
        : l10n.accountGuestLocalDataSubtitle;
    final status = google ? l10n.accountSignedIn : l10n.accountNotConnectedGoogle;

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
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
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

class _GoogleAccountContent extends ConsumerStatefulWidget {
  const _GoogleAccountContent({required this.account});

  final LocalAccount account;

  @override
  ConsumerState<_GoogleAccountContent> createState() =>
      _GoogleAccountContentState();
}

class _GoogleAccountContentState
    extends ConsumerState<_GoogleAccountContent> {
  late final Stream<BackupStatusSnapshot> _backupStatusStream;
  bool _backupActionRunning = false;

  @override
  void initState() {
    super.initState();
    _backupStatusStream = ref
        .read(accountLocalStoreProvider)
        .watchBackupStatus(widget.account.localAccountId);
  }

  Future<void> _setBackup(bool enabled) async {
    if (_backupActionRunning) return;
    setState(() => _backupActionRunning = true);
    try {
      final manager = ref.read(accountSessionManagerProvider.notifier);
      if (enabled) {
        await manager.enableBackup();
      } else {
        await manager.pauseBackup();
      }
    } catch (_) {
      // The local preference/state write is authoritative. Any cloud failure
      // remains represented by the reactive local backup status.
    } finally {
      if (mounted) setState(() => _backupActionRunning = false);
    }
  }

  Future<void> _retryBackup() async {
    if (_backupActionRunning) return;
    setState(() => _backupActionRunning = true);
    try {
      await ref.read(backupWorkerProvider).retryNow();
    } catch (_) {
      // The worker persists failed/waiting state locally and keeps the
      // automatic retry path available.
    } finally {
      if (mounted) setState(() => _backupActionRunning = false);
    }
  }

  Future<void> _signOut() async {
    if (_backupActionRunning) return;
    setState(() => _backupActionRunning = true);
    try {
      await ref.read(accountSessionManagerProvider.notifier).signOut();
    } catch (_) {
      if (mounted) setState(() => _backupActionRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return StreamBuilder<BackupStatusSnapshot>(
      stream: _backupStatusStream,
      builder: (context, snapshot) {
        final status = snapshot.data;
        final enabled =
            status?.backupEnabled ?? widget.account.cloudBackupEnabled;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SettingsSection(
              title: l10n.accountBackupSection,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    key: const Key('account_automatic_backup_switch'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.accountAutomaticBackup),
                    subtitle: Text(l10n.accountBackupAutomaticDescription),
                    value: enabled,
                    onChanged: _backupActionRunning ? null : _setBackup,
                  ),
                  const SizedBox(height: 8),
                  _AccountBackupStatusView(
                    status: status,
                    enabled: enabled,
                    retryEnabled:
                        status?.state == 'failed' && !_backupActionRunning,
                    onRetry: _retryBackup,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const Key('account_sign_out'),
                onPressed: _backupActionRunning ? null : _signOut,
                icon: const Icon(Icons.logout_rounded),
                label: Text(l10n.accountSignOut),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AccountBackupStatusView extends StatelessWidget {
  const _AccountBackupStatusView({
    required this.status,
    required this.enabled,
    required this.retryEnabled,
    required this.onRetry,
  });

  final BackupStatusSnapshot? status;
  final bool enabled;
  final bool retryEnabled;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;

    String title;
    String? message;
    String? secondaryMessage;
    IconData icon;
    final showProgress = status?.hasDeterminateProgress == true;
    final runningWithoutProgress = status?.state == 'running' && !showProgress;

    if (status == null) {
      title = l10n.accountBackupStatusChecking;
      icon = Icons.cloud_outlined;
    } else if (!enabled) {
      title = l10n.accountBackupStatusDisabled;
      icon = Icons.cloud_off_outlined;
    } else {
      switch (status!.state) {
        case 'running':
          title = l10n.accountBackupStatusBackingUp;
          icon = Icons.cloud_upload_outlined;
          break;
        case 'waitingForConnection':
          title = l10n.accountBackupStatusWaitingConnection;
          message = l10n.accountBackupStatusWaitingConnectionMessage;
          icon = Icons.cloud_outlined;
          break;
        case 'failed':
          title = l10n.accountBackupStatusFailedTitle;
          message = l10n.accountBackupStatusFailedMessage;
          secondaryMessage = l10n.accountBackupStatusFailedAutomaticRetry;
          icon = Icons.warning_amber_rounded;
          break;
        case 'idle':
          if (status!.isCurrent && status!.lastSuccessfulBackupAt != null) {
            title = l10n.accountBackupStatusComplete;
            final time = MaterialLocalizations.of(context).formatTimeOfDay(
              TimeOfDay.fromDateTime(status!.lastSuccessfulBackupAt!),
              alwaysUse24HourFormat:
                  MediaQuery.of(context).alwaysUse24HourFormat,
            );
            message = l10n.accountBackupStatusCompletedAt(
              l10n.commonToday + ', ' + time,
            );
            icon = Icons.check_circle_outline_rounded;
          } else {
            title = l10n.accountBackupStatusPending;
            icon = Icons.cloud_outlined;
          }
          break;
        case 'pending':
        default:
          title = l10n.accountBackupStatusPending;
          icon = Icons.cloud_outlined;
          break;
      }
    }

    final statusChildren = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      if (message != null) ...[
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 30),
          child: Text(
            message!,
            style: textTheme.bodySmall,
          ),
        ),
      ],
      if (secondaryMessage != null) ...[
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 30),
          child: Text(
            secondaryMessage!,
            style: textTheme.bodySmall,
          ),
        ),
      ],
      if (status?.state == 'running') ...[
        const SizedBox(height: 10),
        if (showProgress)
          _BackupProgressIndicator(status: status!)
        else if (runningWithoutProgress)
          const LinearProgressIndicator(minHeight: 4),
      ],
      if (status?.state == 'failed') ...[
        const SizedBox(height: 6),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('account_backup_try_again'),
            onPressed: retryEnabled ? onRetry : null,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l10n.accountBackupStatusRetry),
          ),
        ),
      ],
    ];

    return Semantics(
      container: true,
      label: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: statusChildren,
      ),
    );
  }
}

class _BackupProgressIndicator extends StatelessWidget {
  const _BackupProgressIndicator({required this.status});

  final BackupStatusSnapshot status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final percent = (status.progressFraction * 100).round();

    return Semantics(
      label: l10n.accountBackupStatusBackingUp,
      value: '$percent%',
      child: Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              value: status.progressFraction,
              minHeight: 6,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 44,
            child: Text(
              '$percent%',
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
        ],
      ),
    );
  }
}
