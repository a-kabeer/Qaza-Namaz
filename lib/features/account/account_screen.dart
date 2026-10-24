import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/workspace_refresh.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../core/diagnostics/flow_timing.dart';
import '../../domain/services/cloud_sync_contracts.dart';
import '../../domain/entities/local_account.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/settings_components.dart';
import '../../l10n/app_localizations.dart';
import '../data_management/qaza_data_management_screen.dart';
import 'guest_workspace_management_screen.dart';
import '../onboarding/startup_gate.dart';
import '../settings/qaza_reset_controller.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.autoConnect = false});

  final bool autoConnect;

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

  Future<void> _signOutGuest() async {
    await ref.read(appDatabaseProvider).markReturningAccountChoicePending();
    ref.read(startupWorkspaceRestoreSatisfiedProvider.notifier).state = false;
    ref.invalidate(returningAccountChoicePendingProvider);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const StartupGate()),
      (_) => false,
    );
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
    final activeAccount =
        ref.watch(accountSessionManagerProvider).activeAccount;
    final isGuest = isGuestLocalWorkspaceId(activeAccount?.localAccountId);
    // The cloud card owns Google sign-out when a Google identity is connected.
    // Avoid showing two identical actions if startup is still reconciling the
    // previously active Guest workspace.
    final showGuestSignOut = isGuest && !account.isConnected;

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
              autoConnect: widget.autoConnect && !_accountSnapshot.isLoading,
              onAccountChanged: _setAccountSnapshot,
            ),
            const SizedBox(height: 16),
          ],
          if (showGuestSignOut) ...[
            Card(
              child: ListTile(
                key: const Key('account_guest_sign_out'),
                leading: const Icon(Icons.logout_rounded),
                title: Text(l10n.cloudDisconnect),
                subtitle: Text(l10n.accountChoiceGuestDescription),
                onTap: _signOutGuest,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Card(
            child: SettingsNavRow(
              key: const Key('account_guest_workspace_management'),
              icon: Icons.manage_accounts_outlined,
              title: l10n.accountGuestTitle,
              subtitle: null,
              onTap: () => open(const GuestWorkspaceManagementScreen()),
            ),
          ),
          const SizedBox(height: 12),
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
    final reconnectRequired =
        account?.status == CloudAccountStatus.reconnectRequired;
    final identityAvailable = connected || reconnectRequired;
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
        : identityAvailable
            ? displayName
            : unavailable
                ? l10n.accountProfileUnavailable
                : l10n.accountGuest;
    final subtitle = accountState.isLoading
        ? ''
        : connected
            ? l10n.accountSignedInWithGoogle
            : reconnectRequired
                ? l10n.accountProfileUnavailableDetail
                : unavailable
                    ? l10n.accountProfileUnavailableDetail
                    : l10n.accountGuestContinueMessage;
    final photoUrl =
        identityAvailable ? _safeGooglePhotoUrl(account?.photoUrl) : null;
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
    required this.autoConnect,
    required this.onAccountChanged,
  });

  final CloudAccountSnapshot accountSnapshot;
  final bool accountLoading;
  final bool autoConnect;
  final ValueChanged<CloudAccountSnapshot> onAccountChanged;

  @override
  ConsumerState<_CloudBackupCard> createState() => _CloudBackupCardState();
}

enum _CloudAccountOperationStage {
  connecting,
  checkingBackup,
  backingUp,
  signingOut,
}

class _CloudBackupCardState extends ConsumerState<_CloudBackupCard> {
  CloudSyncSnapshot _sync = const CloudSyncSnapshot.disconnected();
  _CloudAccountOperationStage? _operationStage;
  bool _busy = false;
  bool _settingsBusy = false;
  bool _backupBusy = false;
  String? _message;
  CloudBackupProgress? _backupProgress;

  String _frequencyLabel(CloudBackupFrequency frequency) {
    final l10n = AppLocalizations.of(context);
    return switch (frequency) {
      CloudBackupFrequency.daily => l10n.cloudBackupFrequencyDaily,
      CloudBackupFrequency.weekly => l10n.cloudBackupFrequencyWeekly,
      CloudBackupFrequency.monthly => l10n.cloudBackupFrequencyMonthly,
    };
  }

  String _formatBackupMb(int bytes) => (bytes / 1000000).toStringAsFixed(2);

  void _publishBackupProgress(CloudBackupProgress progress) {
    if (!mounted) return;
    setState(() => _backupProgress = progress);
  }

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await _refresh();
      if (mounted && widget.autoConnect) await _connect();
    });
  }

  @override
  void didUpdateWidget(covariant _CloudBackupCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.autoConnect && widget.autoConnect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Future<void>.microtask(_connect);
      });
    }
  }

  Future<void> _refresh() async {
    final sync = await ref.read(cloudSyncProvider).status();
    if (!mounted) return;
    setState(() {
      _sync = sync;
      _message = sync.status == CloudSyncStatus.reconnectRequired ||
              widget.accountSnapshot.status ==
                  CloudAccountStatus.reconnectRequired
          ? AppLocalizations.of(context).accountProfileUnavailableDetail
          : widget.accountSnapshot.message ?? sync.message;
    });
  }

  Future<void> _connect() async {
    if (_busy || _settingsBusy || _backupBusy) return;
    final container = ProviderScope.containerOf(context, listen: false);
    final accountProvider = container.read(cloudAccountProvider);
    // Set the guard before opening the native picker to prevent duplicate
    // authentication dialogs from repeated taps.
    setState(() {
      _busy = true;
      _operationStage = _CloudAccountOperationStage.connecting;
      _message = null;
    });

    final previousWorkspaceId =
        container.read(accountSessionManagerProvider).activeLocalAccountId;
    var workspaceActivated = false;
    var initialBackupPendingMarked = false;
    var guestWorkspaceAdopted = false;
    String? initialBackupLocalAccountId;
    var googleWorkspaceExistedBefore = false;
    // This means the stable Google identity had no workspace before activation.
    var googleWorkspaceWasUninitialized = true;

    Future<void> restorePreviousWorkspace() async {
      if (!workspaceActivated || guestWorkspaceAdopted) return;
      try {
        final session = container.read(accountSessionManagerProvider);
        if (previousWorkspaceId == null) {
          await session.activateGuest();
          await refreshWorkspaceAfterRestoreContainer(container);
        } else if (session.activeLocalAccountId != previousWorkspaceId) {
          await session.activateLocalAccount(previousWorkspaceId);
          await refreshWorkspaceAfterRestoreContainer(container);
        }
        if (initialBackupPendingMarked) {
          await container
              .read(appDatabaseProvider)
              .clearPendingInitialCloudBackup(
                  localAccountId: initialBackupLocalAccountId);
          container.invalidate(initialCloudBackupPendingProvider);
          initialBackupPendingMarked = false;
        }
      } finally {
        workspaceActivated = false;
      }
    }

    try {
      final account = await traceAsyncStage(
        flow: 'account_screen',
        stage: 'google_sign_in_and_drive_authorization',
        action: accountProvider.signIn,
      );
      if (!mounted || account.wasCancelled) return;
      widget.onAccountChanged(account);
      if (!account.isConnected) {
        setState(() {
          _message = account.message ??
              AppLocalizations.of(context).cloudConnectionFailed;
          _sync = const CloudSyncSnapshot(
            status: CloudSyncStatus.failed,
            message: 'Google sign-in could not be completed.',
          );
        });
        return;
      }

      final stableAccountId = account.accountId?.trim();
      if (stableAccountId == null || stableAccountId.isEmpty) {
        setState(() {
          _message = AppLocalizations.of(context).cloudConnectionFailed;
        });
        return;
      }
      final targetWorkspaceId = googleLocalWorkspaceId(stableAccountId);
      initialBackupLocalAccountId = targetWorkspaceId;
      googleWorkspaceExistedBefore = await container
              .read(accountLocalStoreProvider)
              .getAccount(targetWorkspaceId) !=
          null;
      workspaceActivated = true;
      await traceAsyncStage(
        flow: 'account_screen',
        stage: 'activate_google_workspace',
        action: () => container
            .read(accountSessionManagerProvider)
            .activateGoogleAccount(stableAccountId),
      );
      final selectedWorkspaceId =
          container.read(accountSessionManagerProvider).activeLocalAccountId;
      googleWorkspaceWasUninitialized = !googleWorkspaceExistedBefore;
      final googleDisplayName = account.displayName?.trim();
      if (selectedWorkspaceId != null &&
          googleDisplayName != null &&
          googleDisplayName.isNotEmpty) {
        await container
            .read(accountLocalStoreProvider)
            .saveWorkspaceDisplayName(selectedWorkspaceId, googleDisplayName);
      }
      container.invalidate(appRouteProvider);
      container.invalidate(userProfileProvider);
      container.invalidate(progressSummaryProvider);
      container.invalidate(qazaRepositoryProvider);
      container.invalidate(qazaAdditionRepositoryProvider);
      container.invalidate(qazaPlanRevisionRepositoryProvider);

      final cloudSync = container.read(cloudSyncProvider);
      final discovery = await cloudSync.discoverBackup(
        allowInteractive: false,
      );
      if (!mounted) {
        await restorePreviousWorkspace();
        return;
      }
      CloudSyncSnapshot result;
      switch (discovery.status) {
        case CloudBackupDiscoveryStatus.noBackup:
          if (!googleWorkspaceExistedBefore &&
              isGuestLocalWorkspaceId(previousWorkspaceId) &&
              previousWorkspaceId != null) {
            await container
                .read(localBackupServiceProvider)
                .adoptGuestWorkspace(
                  sourceLocalAccountId: previousWorkspaceId,
                  targetGoogleLocalAccountId: targetWorkspaceId,
                  googleDisplayName: account.displayName?.trim() ?? '',
                );
            guestWorkspaceAdopted = true;
            // The ownership transfer has committed; never revert to the
            // now-archived Guest row just because an upload later fails.
            googleWorkspaceWasUninitialized = false;
            await container
                .read(appDatabaseProvider)
                .markInitialCloudBackupPending();
            initialBackupPendingMarked = true;
            container.invalidate(initialCloudBackupPendingProvider);
            container
                .read(skipPendingInitialCloudBackupForSessionProvider.notifier)
                .state = true;
            await refreshWorkspaceAfterRestoreContainer(container);
          }

          final localAccountId = container
              .read(accountSessionManagerProvider)
              .activeLocalAccountId;
          final profile = localAccountId == null
              ? null
              : await container
                  .read(accountLocalStoreProvider)
                  .loadProfile(localAccountId);

          if (profile == null) {
            // A newly connected account needs onboarding before its first
            // cloud snapshot. Do not upload an empty workspace and mistake it
            // for a completed backup.
            final database = container.read(appDatabaseProvider);
            await database.markInitialCloudBackupPending();
            initialBackupPendingMarked = true;
            container.invalidate(initialCloudBackupPendingProvider);
            result = await cloudSync.status();
            if (!mounted) {
              await restorePreviousWorkspace();
              return;
            }
            setState(() {
              _sync = result;
              _message = null;
              _backupProgress = null;
            });
            // This is an intentional transition into first-time setup rather
            // than a failed connection; keep the newly selected workspace.
            workspaceActivated = false;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute<void>(builder: (_) => const StartupGate()),
              (_) => false,
            );
            return;
          }

          result = await cloudSync.backupNow(
            onProgress: _publishBackupProgress,
          );
          if (guestWorkspaceAdopted &&
              result.status == CloudSyncStatus.synced &&
              !result.hasPendingChanges) {
            await container
                .read(localBackupServiceProvider)
                .markGuestAdoptionBackupVerified(initialBackupLocalAccountId);
            await container
                .read(appDatabaseProvider)
                .clearPendingInitialCloudBackup(
                    localAccountId: initialBackupLocalAccountId);
            initialBackupPendingMarked = false;
            container.invalidate(initialCloudBackupPendingProvider);
            container
                .read(skipPendingInitialCloudBackupForSessionProvider.notifier)
                .state = false;
          }
          if (result.status == CloudSyncStatus.conflict &&
              result.conflict != null) {
            final resolved = await _resolveConflict(result.conflict!);
            if (resolved == null) {
              if (googleWorkspaceWasUninitialized) {
                await restorePreviousWorkspace();
              }
              return;
            }
            result = resolved;
          }
          break;
        case CloudBackupDiscoveryStatus.backupFound:
          final conflict = discovery.conflict;
          if (conflict == null) {
            result = CloudSyncSnapshot(
              status: CloudSyncStatus.failed,
              message: discovery.message ??
                  AppLocalizations.of(context).cloudConnectionFailed,
            );
          } else {
            final database = container.read(appDatabaseProvider);
            final fresh = await database.isFreshInstallationForCloudRestore(
              localAccountId: container
                  .read(accountSessionManagerProvider)
                  .activeLocalAccountId,
            );
            final revision = await database.readDbRevision();
            if (fresh && conflict.localRevision == revision) {
              result = await cloudSync.resolveConflict(
                conflict: conflict,
                choice: CloudConflictChoice.useRemote,
                confirmed: true,
                onProgress: _publishBackupProgress,
              );
              if (!mounted) {
                await restorePreviousWorkspace();
                return;
              }
              if (result.status == CloudSyncStatus.synced &&
                  result.restoredRemoteBackup) {
                await refreshWorkspaceAfterRestoreContainer(container);
                if (!mounted) {
                  await restorePreviousWorkspace();
                  return;
                }
              }
            } else {
              final resolved = await _resolveConflict(conflict);
              if (resolved == null) {
                if (googleWorkspaceWasUninitialized) {
                  await restorePreviousWorkspace();
                }
                return;
              }
              result = resolved;
            }
          }
          break;
        case CloudBackupDiscoveryStatus.unavailable:
        case CloudBackupDiscoveryStatus.invalidBackup:
        case CloudBackupDiscoveryStatus.failed:
          result = CloudSyncSnapshot(
            status: CloudSyncStatus.failed,
            message: discovery.message ??
                AppLocalizations.of(context).cloudConnectionFailed,
          );
          break;
      }

      // A failed discovery must not leave the user inside a newly created,
      // empty Google workspace. An explicit "keep local" decision instead
      // enters that workspace's onboarding flow.
      if (googleWorkspaceWasUninitialized &&
          result.status == CloudSyncStatus.failed) {
        await restorePreviousWorkspace();
      }
      if (googleWorkspaceWasUninitialized &&
          result.status == CloudSyncStatus.synced &&
          !result.restoredRemoteBackup) {
        await container
            .read(appDatabaseProvider)
            .markInitialCloudBackupPending();
        initialBackupPendingMarked = true;
        container.invalidate(initialCloudBackupPendingProvider);
        if (!mounted) {
          // The route was abandoned before first-run setup could be shown.
          await restorePreviousWorkspace();
          return;
        }
        workspaceActivated = false;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: (_) => const StartupGate()),
          (_) => false,
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _sync = result;
        _message = result.message ??
            (result.status == CloudSyncStatus.synced
                ? AppLocalizations.of(context).cloudBackupSucceeded
                : account.message);
      });
    } catch (_) {
      if (workspaceActivated && googleWorkspaceWasUninitialized) {
        try {
          await restorePreviousWorkspace();
        } catch (_) {
          // Preserve the original connection error if recovery also fails.
        }
      }
      if (mounted) {
        setState(() {
          _message = AppLocalizations.of(context).cloudConnectionFailed;
        });
      }
    } finally {
      if (guestWorkspaceAdopted) {
        // The interactive backup attempt has finished. Let the account-scoped
        // background retry take over only if its marker is still pending.
        container
            .read(skipPendingInitialCloudBackupForSessionProvider.notifier)
            .state = false;
        container.invalidate(initialCloudBackupRetryProvider);
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _operationStage = null;
        });
      }
    }
  }

  Future<void> _disconnect() async {
    if (_busy || _settingsBusy || _backupBusy) return;
    setState(() {
      _busy = true;
      _operationStage = _CloudAccountOperationStage.checkingBackup;
      _message = null;
    });
    try {
      final cloudSync = ref.read(cloudSyncProvider);
      final status = await traceAsyncStage(
        flow: 'sign_out',
        stage: 'check_local_sync_status',
        action: cloudSync.status,
      );
      if (!mounted) return;
      setState(() => _sync = status);

      if (!status.hasPendingChanges) {
        await _finishSignOut();
        return;
      }

      // A read-only remote discovery differentiates a usable online Drive
      // session from a connection/authorization failure without uploading.
      final discovery = await traceAsyncStage(
        flow: 'sign_out',
        stage: 'discover_remote_backup',
        action: () => cloudSync.discoverBackup(allowInteractive: false),
      );
      if (!mounted) return;
      final canCheckRemote =
          discovery.status == CloudBackupDiscoveryStatus.noBackup ||
              discovery.status == CloudBackupDiscoveryStatus.backupFound;

      if (!canCheckRemote) {
        final signOutAnyway = await _confirmSignOutWithoutBackup();
        if (signOutAnyway == true && mounted) await _finishSignOut();
        return;
      }

      // On a reachable account, attempt backup immediately. Only ask the user
      // what to do if backup fails or an unresolved conflict blocks it.
      while (mounted) {
        setState(() {
          _operationStage = _CloudAccountOperationStage.backingUp;
          _backupProgress = const CloudBackupProgress.checking();
          _message = null;
        });
        var result = await traceAsyncStage(
          flow: 'sign_out',
          stage: 'backup_before_sign_out',
          action: () => cloudSync.backupNow(
            onProgress: _publishBackupProgress,
          ),
        );
        if (!mounted) return;
        if (result.status == CloudSyncStatus.conflict &&
            result.conflict != null) {
          result = await _resolveConflict(result.conflict!) ??
              await cloudSync.status();
        }
        if (!mounted) return;
        setState(() {
          _sync = result;
          _backupProgress = null;
          _message = result.message;
        });

        if (result.status == CloudSyncStatus.synced &&
            !result.hasPendingChanges) {
          await _finishSignOut();
          return;
        }

        final next = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              AppLocalizations.of(dialogContext).cloudSignOutPendingTitle,
            ),
            content: Text(
              result.message ??
                  AppLocalizations.of(dialogContext).cloudSignOutPendingMessage,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('cancel'),
                child: Text(AppLocalizations.of(dialogContext).commonCancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('sign_out'),
                child: Text(
                  AppLocalizations.of(dialogContext).cloudSignOutAnyway,
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop('retry'),
                child: Text(AppLocalizations.of(dialogContext).commonRetry),
              ),
            ],
          ),
        );
        if (!mounted || next == 'cancel' || next == null) return;
        if (next == 'sign_out') {
          await _finishSignOut();
          return;
        }
      }
    } catch (error, stack) {
      ref.read(diagnosticsProvider).recordFailure(
            DiagnosticArea.sync,
            'sign_out_flow_failed',
            error,
            stack: stack,
          );
      if (mounted) {
        setState(() {
          _message = AppLocalizations.of(context).cloudConnectionFailed;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _operationStage = null;
          _backupProgress = null;
        });
      }
    }
  }

  Future<bool?> _confirmSignOutWithoutBackup() {
    final l10n = AppLocalizations.of(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.cloudSignOutPendingTitle),
        content: Text(l10n.cloudSignOutPendingMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.cloudSignOutAnyway),
          ),
        ],
      ),
    );
  }

  Future<void> _finishSignOut() async {
    if (mounted) {
      setState(() {
        _operationStage = _CloudAccountOperationStage.signingOut;
      });
    }
    await traceAsyncStage(
      flow: 'sign_out',
      stage: 'disconnect_cloud_and_cancel_scheduled_work',
      action: () => ref.read(cloudAccountProvider).disconnect(),
    );
    // Switch away from the outgoing workspace without deleting its local data.
    await traceAsyncStage(
      flow: 'sign_out',
      stage: 'activate_local_workspace',
      action: () => ref.read(accountSessionManagerProvider).activateGuest(),
    );
    ref.invalidate(appRouteProvider);
    ref.invalidate(userProfileProvider);
    ref.invalidate(progressSummaryProvider);
    ref.invalidate(qazaRepositoryProvider);
    ref.invalidate(qazaAdditionRepositoryProvider);
    ref.invalidate(qazaPlanRevisionRepositoryProvider);
    await traceAsyncStage(
      flow: 'sign_out',
      stage: 'persist_returning_account_choice',
      action: () =>
          ref.read(appDatabaseProvider).markReturningAccountChoicePending(),
    );
    widget.onAccountChanged(const CloudAccountSnapshot.disconnected());
    ref.invalidate(cloudAccountStartupRestoreProvider);
    ref.read(startupWorkspaceRestoreSatisfiedProvider.notifier).state = false;
    ref.invalidate(returningAccountChoicePendingProvider);
    ref.invalidate(cloudSetupChoiceCompleteProvider);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const StartupGate()),
      (_) => false,
    );
  }

  Future<void> _backupNow() async {
    if (_busy || _settingsBusy || _backupBusy) return;
    setState(() {
      _backupBusy = true;
      _message = null;
      _backupProgress = const CloudBackupProgress.checking();
    });
    try {
      final result = await ref.read(cloudSyncProvider).backupNow(
            onProgress: _publishBackupProgress,
          );
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _sync = result;
        _message = result.backupAlreadyUpToDate
            ? l10n.cloudBackupUpToDate
            : result.message;
        _backupProgress = null;
      });
      if (result.status == CloudSyncStatus.conflict &&
          result.conflict != null) {
        await _resolveConflict(result.conflict!);
      } else if (result.status == CloudSyncStatus.synced && mounted) {
        setState(() {
          _message = result.backupAlreadyUpToDate
              ? l10n.cloudBackupUpToDate
              : result.message ?? l10n.cloudBackupSucceeded;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _backupBusy = false;
          _backupProgress = null;
        });
      }
    }
  }

  Future<CloudSyncSnapshot?> _resolveConflict(
      CloudConflictInfo conflict) async {
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
          TextButton(
            onPressed: () =>
                Navigator.pop(context, CloudConflictChoice.keepBoth),
            child: const Text('Keep Both'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, CloudConflictChoice.useRemote),
            child: Text(l10n.cloudUseRemote),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return null;

    final useRemote = choice == CloudConflictChoice.useRemote;
    final keepBoth = choice == CloudConflictChoice.keepBoth;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          useRemote
              ? l10n.cloudUseRemoteConfirmTitle
              : l10n.cloudKeepLocalConfirmTitle,
        ),
        content: keepBoth
            ? const Text(
                'The cloud version will first be saved as a separate local '
                'Recovery Copy. Your current local workspace will remain active. '
                'Only after the copy is verified will the local version be '
                'uploaded to Drive.',
              )
            : Text(
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
    if (confirmed != true || !mounted) return null;
    final result = await ref.read(cloudSyncProvider).resolveConflict(
          conflict: conflict,
          choice: choice,
          confirmed: true,
          onProgress: _publishBackupProgress,
        );
    if (!mounted) return null;
    if (useRemote && result.status == CloudSyncStatus.synced) {
      await _refreshAfterRestore();
      if (!mounted) return null;
    }
    setState(() {
      _sync = result;
      _message = result.status == CloudSyncStatus.synced
          ? l10n.cloudBackupSucceeded
          : result.message;
    });
    return result;
  }

  Future<void> _refreshAfterRestore() async {
    await refreshWorkspaceAfterRestore(ref);
  }

  Future<void> _toggleAutomaticBackup(bool enabled) async {
    if (_busy || _settingsBusy || _backupBusy) return;
    setState(() {
      _settingsBusy = true;
      _message = null;
    });
    try {
      final result =
          await ref.read(cloudSyncProvider).setAutomaticSyncEnabled(enabled);
      if (!mounted) return;
      setState(() {
        _sync = result;
        _message = result.message;
      });
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _settingsBusy = false);
    }
  }

  Future<void> _changeBackupFrequency(CloudBackupFrequency frequency) async {
    if (_busy || _settingsBusy || _backupBusy) return;
    setState(() {
      _settingsBusy = true;
      _message = null;
    });
    try {
      final result = await ref
          .read(cloudSyncProvider)
          .setAutomaticBackupFrequency(frequency);
      if (!mounted) return;
      setState(() {
        _sync = result;
        _message = result.message;
      });
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _settingsBusy = false);
    }
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
    try {
      final result = await ref
          .read(cloudSyncProvider)
          .restoreLocalRecoverySnapshot(confirmed: true);
      if (result.status == CloudSyncStatus.synced) {
        await _refreshAfterRestore();
      }
      if (!mounted) return;
      setState(() {
        _sync = result;
        _message = result.status == CloudSyncStatus.synced
            ? l10n.cloudBackupSucceeded
            : result.message;
      });
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                            : _sync.status == CloudSyncStatus.reconnectRequired
                                ? l10n.cloudNotConnected
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
            else if (_sync.status == CloudSyncStatus.reconnectRequired ||
                !connected)
              FilledButton.icon(
                onPressed: _busy ? null : _connect,
                icon: const Icon(Icons.login_rounded),
                label: Text(l10n.cloudConnect),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (_busy || _settingsBusy || _backupBusy)
                      ? null
                      : _backupNow,
                  icon: _backupBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.backup_rounded),
                  label: Text(
                    _backupBusy ? l10n.cloudBackupWorking : l10n.cloudBackupNow,
                  ),
                ),
              ),
              if (_backupBusy && _backupProgress != null) ...[
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final progress = _backupProgress!;
                    final checking =
                        progress.stage == CloudBackupProgressStage.checking;
                    final preparing =
                        progress.stage == CloudBackupProgressStage.preparing;
                    final completed =
                        progress.stage == CloudBackupProgressStage.completed;
                    final fraction =
                        checking || preparing || progress.totalBytes <= 0
                            ? 0.0
                            : (progress.sentBytes / progress.totalBytes)
                                .clamp(0.0, completed ? 1.0 : 0.99)
                                .toDouble();
                    final percent =
                        checking || preparing || progress.totalBytes <= 0
                            ? 0
                            : (progress.sentBytes * 100 / progress.totalBytes)
                                .floor()
                                .clamp(0, completed ? 100 : 99);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          checking
                              ? l10n.cloudBackupChecking
                              : preparing
                                  ? l10n.cloudBackupPreparing
                                  : completed
                                      ? l10n.cloudBackupCompleted
                                      : l10n.cloudBackupUploading,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: checking || preparing ? null : fraction,
                        ),
                        if (!checking && !preparing) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${_formatBackupMb(progress.sentBytes)} MB / '
                            '${_formatBackupMb(progress.totalBytes)} MB · '
                            '$percent%',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
              SwitchListTile(
                key: const Key('account_daily_cloud_backup'),
                contentPadding: EdgeInsets.zero,
                value: _sync.automaticSyncEnabled,
                onChanged: (_busy || _settingsBusy || _backupBusy)
                    ? null
                    : _toggleAutomaticBackup,
                title: Text(l10n.cloudAutomaticBackup),
              ),
              if (_sync.automaticSyncEnabled) ...[
                const SizedBox(height: 4),
                DropdownButtonFormField<CloudBackupFrequency>(
                  key: const Key('account_cloud_backup_frequency'),
                  initialValue: _sync.backupFrequency,
                  decoration: InputDecoration(
                    labelText: l10n.cloudBackupFrequencyLabel,
                  ),
                  items: CloudBackupFrequency.values
                      .map(
                        (frequency) => DropdownMenuItem<CloudBackupFrequency>(
                          value: frequency,
                          child: Text(_frequencyLabel(frequency)),
                        ),
                      )
                      .toList(),
                  onChanged: (_busy || _settingsBusy || _backupBusy)
                      ? null
                      : (frequency) {
                          if (frequency != null &&
                              frequency != _sync.backupFrequency) {
                            _changeBackupFrequency(frequency);
                          }
                        },
                ),
              ],
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
            if (_busy && _operationStage != null) ...[
              const SizedBox(height: 12),
              Container(
                key: const Key('account_cloud_operation_progress'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            switch (_operationStage!) {
                              _CloudAccountOperationStage.connecting =>
                                l10n.cloudRestoreConnectingTitle,
                              _CloudAccountOperationStage.checkingBackup =>
                                l10n.cloudBackupChecking,
                              _CloudAccountOperationStage.backingUp =>
                                l10n.cloudBackupUploading,
                              _CloudAccountOperationStage.signingOut =>
                                '${l10n.cloudDisconnect}…',
                            },
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const LinearProgressIndicator(),
                    if (_operationStage ==
                        _CloudAccountOperationStage.signingOut) ...[
                      const SizedBox(height: 6),
                      Text(
                        l10n.accountSignOutExplanation,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
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
