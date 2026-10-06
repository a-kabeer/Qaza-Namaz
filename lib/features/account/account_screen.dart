import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
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
  BackupStatusSnapshot? _backupStatus;
  Timer? _statusTimer;
  bool _backupActionRunning = false;

  @override
  void initState() {
    super.initState();
    _refreshBackupStatus();
    _statusTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _refreshBackupStatus(),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshBackupStatus() async {
    try {
      final status = await ref
          .read(accountLocalStoreProvider)
          .readBackupStatus(widget.account.localAccountId);
      if (mounted) setState(() => _backupStatus = status);
    } catch (_) {}
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
      await _refreshBackupStatus();
    } catch (_) {
      await _refreshBackupStatus();
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

  String _statusText(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = _backupStatus;
    if (status == null) return l10n.accountBackupStatusChecking;
    if (!status.backupEnabled) return l10n.accountBackupStatusDisabled;
    if (status.isCurrent && status.lastSuccessfulBackupAt != null) {
      final time = MaterialLocalizations.of(context).formatTimeOfDay(
        TimeOfDay.fromDateTime(status.lastSuccessfulBackupAt!),
        alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
      );
      return l10n.accountBackupStatusBackedUp(
        l10n.commonToday + ', ' + time,
      );
    }
    switch (status.state) {
      case 'running':
        return l10n.accountBackupStatusBackingUp;
      case 'waitingForConnection':
        return l10n.accountBackupStatusWaitingConnection;
      case 'failed':
        return l10n.accountBackupStatusFailed;
      default:
        return l10n.accountBackupStatusPending;
    }
  }

  bool get _isBackingUp => _backupStatus?.state == 'running';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final status = _backupStatus;
    final enabled = status?.backupEnabled ?? widget.account.cloudBackupEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: l10n.accountBackupSection,
          child: Column(
            children: [
              SwitchListTile(
                key: const Key('account_automatic_backup_switch'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.accountAutomaticBackup),
                subtitle: Text(l10n.accountBackupAutomaticDescription),
                value: enabled,
                onChanged: _backupActionRunning ? null : _setBackup,
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Row(
                  key: ValueKey(_statusText(context)),
                  children: [
                    if (_isBackingUp)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        enabled && status?.isCurrent == true
                            ? Icons.check_circle_outline_rounded
                            : Icons.cloud_outlined,
                        size: 18,
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusText(context),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('account_sign_out'),
            onPressed: _backupActionRunning ? null : _signOut,
            icon: const Icon(Icons.logout_rounded),
            label: Text(l10n.accountSignOut),
          ),
        ),
      ],
    );
  }
}
