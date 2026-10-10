import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/services/cloud_sync_contracts.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/settings_components.dart';
import '../../l10n/app_localizations.dart';
import '../data_management/qaza_data_management_screen.dart';
import '../settings/qaza_reset_controller.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  AsyncValue<CloudAccountSnapshot> _accountSnapshot = const AsyncLoading();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_restoreCloudAccount);
  }

  Future<void> _restoreCloudAccount() async {
    final accountProvider = ref.read(cloudAccountProvider);
    if (!accountProvider.isSupported) {
      if (mounted) {
        setState(
          () => _accountSnapshot =
              const AsyncData(CloudAccountSnapshot.unavailable()),
        );
      }
      return;
    }

    try {
      final account = await accountProvider.restore();
      if (!mounted) return;
      setState(() => _accountSnapshot = AsyncData(account));
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _accountSnapshot =
            AsyncData(CloudAccountSnapshot.failed(error.toString())),
      );
    }
  }

  void _setAccountSnapshot(CloudAccountSnapshot account) {
    if (!mounted) return;
    setState(() => _accountSnapshot = AsyncData(account));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    void open(Widget screen) {
      Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => screen),
      );
    }

    final account = _accountSnapshot.valueOrNull ??
        const CloudAccountSnapshot.disconnected();
    final cloudSupported = ref.watch(cloudAccountProvider).isSupported &&
        ref.watch(cloudSyncProvider).isSupported;

    return AppScaffold(
      title: l10n.accountTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          _GoogleProfileCard(accountState: _accountSnapshot),
          const SizedBox(height: 12),
          if (cloudSupported) ...[
            _CloudBackupCard(
              key: const Key('account_cloud_backup'),
              accountSnapshot: account,
              accountLoading: _accountSnapshot.isLoading,
              onAccountChanged: _setAccountSnapshot,
            ),
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

class _GoogleProfileCard extends StatelessWidget {
  const _GoogleProfileCard({required this.accountState});

  final AsyncValue<CloudAccountSnapshot> accountState;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = accountState.valueOrNull;
    final connected = account?.isConnected ?? false;
    final unavailable =
        accountState.hasError || account?.status == CloudAccountStatus.failed;
    final rawName = account?.displayName?.trim();
    final rawEmail = account?.email?.trim();
    final displayName = rawName?.isNotEmpty == true
        ? rawName!
        : rawEmail?.isNotEmpty == true
            ? rawEmail!
            : l10n.accountNotAvailable;
    final email = rawEmail?.isNotEmpty == true && rawEmail != displayName
        ? rawEmail
        : null;
    final title = accountState.isLoading
        ? l10n.accountProfileChecking
        : connected
            ? displayName
            : unavailable
                ? l10n.accountProfileUnavailable
                : l10n.accountGuest;
    final subtitle = accountState.isLoading
        ? ''
        : connected
            ? l10n.accountSignedInWithGoogle
            : unavailable
                ? l10n.accountProfileUnavailableDetail
                : l10n.accountGuestContinueMessage;
    final photoUrl = connected ? _safeGooglePhotoUrl(account?.photoUrl) : null;
    final avatarLabel =
        connected ? '$displayName, ${l10n.accountGoogleAuth}' : title;

    return Card(
      key: const Key('account_google_profile_card'),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Semantics(
              label: avatarLabel,
              image: true,
              child: CircleAvatar(
                radius: 28,
                backgroundColor:
                    Theme.of(context).colorScheme.secondaryContainer,
                child: photoUrl == null
                    ? const Icon(Icons.person_outline_rounded, size: 30)
                    : ClipOval(
                        child: Image.network(
                          photoUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                                  ? child
                                  : const Icon(
                                      Icons.person_outline_rounded,
                                      size: 30,
                                    ),
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 30,
                              ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (email != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      email,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _safeGooglePhotoUrl(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme.toLowerCase() != 'https' || uri.host.isEmpty) {
    return null;
  }
  return raw;
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
  const _CloudBackupCard({
    super.key,
    required this.accountSnapshot,
    required this.accountLoading,
    required this.onAccountChanged,
  });

  final CloudAccountSnapshot accountSnapshot;
  final bool accountLoading;
  final ValueChanged<CloudAccountSnapshot> onAccountChanged;

  @override
  ConsumerState<_CloudBackupCard> createState() => _CloudBackupCardState();
}

class _CloudBackupCardState extends ConsumerState<_CloudBackupCard> {
  CloudSyncSnapshot _sync = const CloudSyncSnapshot.disconnected();
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_refresh);
  }

  Future<void> _refresh() async {
    final sync = await ref.read(cloudSyncProvider).status();
    if (!mounted) return;
    setState(() {
      _sync = sync;
      _message = widget.accountSnapshot.message ?? sync.message;
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
    widget.onAccountChanged(account);
    setState(() {
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
      widget.onAccountChanged(const CloudAccountSnapshot.disconnected());
      final sync = await ref.read(cloudSyncProvider).status();
      if (!mounted) return;
      setState(() {
        _sync = sync;
        _message = sync.message;
      });
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
      setState(
          () => _message = AppLocalizations.of(context).cloudBackupSucceeded);
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
            onPressed: () =>
                Navigator.pop(context, CloudConflictChoice.keepLocal),
            child: Text(l10n.cloudKeepLocal),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, CloudConflictChoice.useRemote),
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
    final result = await ref
        .read(cloudSyncProvider)
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
    final connected = widget.accountSnapshot.isConnected;
    final displayName =
        widget.accountSnapshot.displayName?.trim().isNotEmpty == true
            ? widget.accountSnapshot.displayName!.trim()
            : widget.accountSnapshot.email?.trim();
    final lastBackup = _sync.lastSuccessAt == null
        ? l10n.cloudNeverBackedUp
        : '${MaterialLocalizations.of(context).formatMediumDate(
            _sync.lastSuccessAt!.toLocal(),
          )} ${MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(_sync.lastSuccessAt!.toLocal()),
          )}';

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
                        widget.accountLoading
                            ? l10n.accountProfileChecking
                            : connected
                                ? displayName == null || displayName.isEmpty
                                    ? l10n.cloudConnected
                                    : '${l10n.cloudConnected}: $displayName'
                                : l10n.cloudNotConnected,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (widget.accountLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (!connected)
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
                '${l10n.cloudLastBackup}: $lastBackup',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_sync.status == CloudSyncStatus.conflict &&
                  _sync.conflict != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('account_resolve_pending_cloud_conflict'),
                    onPressed:
                        _busy ? null : () => _resolveConflict(_sync.conflict!),
                    icon: const Icon(Icons.compare_arrows_rounded),
                    label: Text(l10n.cloudBackupConflictTitle),
                  ),
                ),
              ],
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
                          widget.accountSnapshot.status ==
                              CloudAccountStatus.failed
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
