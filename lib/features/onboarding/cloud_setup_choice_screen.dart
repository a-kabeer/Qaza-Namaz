import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/errors/app_error.dart';
import '../../core/errors/app_error_messages.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_theme_labels.dart';
import '../../core/widgets/language_selector.dart';
import '../../domain/services/cloud_sync_contracts.dart';
import '../../domain/entities/local_account.dart';
import '../account/guest_workspace_label.dart';
import '../../l10n/app_localizations.dart';

class CloudSetupChoiceScreen extends ConsumerStatefulWidget {
  const CloudSetupChoiceScreen({super.key});

  @override
  ConsumerState<CloudSetupChoiceScreen> createState() =>
      _CloudSetupChoiceScreenState();
}

class _CloudSetupChoiceScreenState
    extends ConsumerState<CloudSetupChoiceScreen> {
  late Locale _selectedLocale;
  Future<void> _languagePersistence = Future<void>.value();
  bool _working = false;
  bool _accountConnected = false;
  bool _cloudAttempted = false;
  bool _driveDiscoveryUnverified = false;
  bool _driveBackupInvalid = false;
  final List<_QueuedCloudErrorDialog> _queuedErrorDialogs = [];
  bool _errorDialogShowing = false;
  bool _errorDialogScheduled = false;
  CloudBackupDiscoverySnapshot? _discovery;
  bool _restoring = false;
  CloudBackupProgress? _restoreProgress;
  bool _googleWorkspaceMayAdoptGuest = false;
  String? _connectedGoogleWorkspaceId;
  String _connectedGoogleDisplayName = '';
  static const String _startFreshChoice = '__start_fresh__';

  @override
  void initState() {
    super.initState();
    _selectedLocale = ref.read(localeProvider);
    Future<void>.microtask(_restoreExistingAccount);
  }

  void _selectLanguage(Locale locale) {
    if (_working || locale == _selectedLocale) {
      return;
    }
    setState(() {
      _selectedLocale = locale;
    });
    // Update MaterialApp immediately; serialize writes so rapid language
    // changes cannot complete out of order in SharedPreferences.
    ref.read(localeProvider.notifier).preview(locale);
    _languagePersistence = _languagePersistence
        .then((_) => ref.read(localeProvider.notifier).persist(locale))
        .catchError((Object error) {
      if (!mounted) return;
      _showErrorDialog(
        message: AppError.from(error).message(context),
      );
    });
  }

  Future<void> _persistSelectedLanguage() async {
    await _languagePersistence;
    await ref.read(localeProvider.notifier).set(_selectedLocale);
  }

  Future<void> _restoreExistingAccount() async {
    if (!mounted || _working) return;
    setState(() => _working = true);
    try {
      final account = await ref.read(cloudAccountStartupRestoreProvider.future);
      if (!mounted) return;
      if (account.isConnected) {
        final stableId = account.accountId?.trim();
        final workspaceId = stableId == null || stableId.isEmpty
            ? null
            : googleLocalWorkspaceId(stableId);
        final existed = workspaceId != null &&
            await ref.read(accountLocalStoreProvider).getAccount(workspaceId) !=
                null;
        await _activateGoogleWorkspace(account);
        _accountConnected = true;
        _googleWorkspaceMayAdoptGuest = !existed;
        _connectedGoogleWorkspaceId = workspaceId;
        _connectedGoogleDisplayName = account.displayName?.trim() ?? '';
        await _discoverBackup(
          allowGuestAdoptionChoice: !existed,
          googleWorkspaceId: workspaceId,
          googleDisplayName: _connectedGoogleDisplayName,
        );
      } else if (account.status == CloudAccountStatus.reconnectRequired) {
        // There is an existing cloud opt-in, even though this process has no
        // resolved account. If the user explicitly chooses local-only setup,
        // _continueLocally must also stop that existing scheduled sync.
        _cloudAttempted = true;
      } else if (account.status == CloudAccountStatus.failed) {
        _cloudAttempted = true;
        _showFailure(
          error: account.message,
          fallbackMessage: AppLocalizations.of(context).cloudConnectionFailed,
          onRetry: _restoreExistingAccount,
        );
      }
    } catch (error) {
      _cloudAttempted = true;
      if (mounted) {
        _showFailure(
          error: error,
          fallbackMessage: AppLocalizations.of(context).cloudConnectionFailed,
          onRetry: _restoreExistingAccount,
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _activateGoogleWorkspace(CloudAccountSnapshot account) async {
    final stableAccountId = account.accountId?.trim();
    if (stableAccountId == null || stableAccountId.isEmpty) {
      throw StateError(
        'Google could not verify this account. Please try signing in again.',
      );
    }
    await ref
        .read(accountSessionManagerProvider)
        .activateGoogleAccount(stableAccountId);
    final localAccountId =
        ref.read(accountSessionManagerProvider).activeLocalAccountId;
    final googleName = account.displayName?.trim();
    if (localAccountId != null && googleName != null && googleName.isNotEmpty) {
      await ref.read(accountLocalStoreProvider).saveWorkspaceDisplayName(
            localAccountId,
            googleName,
          );
    }
    ref.invalidate(appRouteProvider);
    ref.invalidate(userProfileProvider);
    ref.invalidate(progressSummaryProvider);
    ref.invalidate(qazaRepositoryProvider);
    ref.invalidate(qazaAdditionRepositoryProvider);
    ref.invalidate(qazaPlanRevisionRepositoryProvider);
  }

  Future<void> _completeChoice() async {
    final database = ref.read(appDatabaseProvider);
    await database.clearReturningAccountChoicePending();
    await database.markCloudSetupChoiceComplete();
    ref.read(startupWorkspaceRestoreSatisfiedProvider.notifier).state = true;
    ref.invalidate(startupAccountWorkspaceRestoreProvider);
    ref.invalidate(returningAccountChoicePendingProvider);
    ref.invalidate(cloudSetupChoiceCompleteProvider);
  }

  Future<void> _discoverBackup({
    bool allowInteractive = false,
    bool? allowGuestAdoptionChoice,
    String? googleWorkspaceId,
    String? googleDisplayName,
  }) async {
    final mayAdoptGuest =
        allowGuestAdoptionChoice ?? _googleWorkspaceMayAdoptGuest;
    final targetWorkspaceId = googleWorkspaceId ?? _connectedGoogleWorkspaceId;
    final targetGoogleName = googleDisplayName ?? _connectedGoogleDisplayName;
    final result = await ref.read(cloudSyncProvider).discoverBackup(
          allowInteractive: allowInteractive,
        );
    if (!mounted) return;

    switch (result.status) {
      case CloudBackupDiscoveryStatus.unavailable:
      case CloudBackupDiscoveryStatus.failed:
        _driveDiscoveryUnverified = true;
        _driveBackupInvalid = false;
        setState(() => _discovery = null);
        _showFailure(
          error: result.message,
          fallbackMessage: AppLocalizations.of(context).cloudConnectionFailed,
          onRetry: _retry,
        );
        return;
      case CloudBackupDiscoveryStatus.invalidBackup:
        _driveDiscoveryUnverified = true;
        _driveBackupInvalid = true;
        setState(() => _discovery = null);
        _showFailure(
          error: result.message,
          fallbackMessage:
              AppLocalizations.of(context).cloudSetupBackupUnreadableMessage,
          onRetry: _retry,
          invalidBackup: true,
        );
        return;
      case CloudBackupDiscoveryStatus.noBackup:
        _driveDiscoveryUnverified = false;
        _driveBackupInvalid = false;
        setState(() => _discovery = result);
        var adoptedGuestWorkspace = false;
        if (_accountConnected && mayAdoptGuest && targetWorkspaceId != null) {
          final guests =
              await ref.read(accountLocalStoreProvider).listGuestWorkspaces();
          if (guests.isNotEmpty) {
            final choice = await _chooseGuestWorkspace(guests);
            if (!mounted || choice == null) return;
            if (choice != _startFreshChoice) {
              await ref.read(localBackupServiceProvider).adoptGuestWorkspace(
                    sourceLocalAccountId: choice,
                    targetGoogleLocalAccountId: targetWorkspaceId,
                    googleDisplayName: targetGoogleName,
                  );
              await ref.read(accountSessionManagerProvider).refresh();
              ref.invalidate(appRouteProvider);
              ref.invalidate(userProfileProvider);
              ref.invalidate(progressSummaryProvider);
              ref.invalidate(qazaRepositoryProvider);
              ref.invalidate(qazaAdditionRepositoryProvider);
              ref.invalidate(qazaPlanRevisionRepositoryProvider);
              adoptedGuestWorkspace = true;
            }
          }
        }
        // A failed first upload must leave the adopted local workspace usable.
        // Keep a durable retry marker, but do not block Home for this session.
        if (_accountConnected) {
          final database = ref.read(appDatabaseProvider);
          await database.markInitialCloudBackupPending();
          ref.invalidate(initialCloudBackupPendingProvider);
          if (adoptedGuestWorkspace) {
            ref
                .read(skipPendingInitialCloudBackupForSessionProvider.notifier)
                .state = false;
            var uploaded = false;
            try {
              final backup = await ref.read(cloudSyncProvider).backupNow();
              uploaded = backup.status == CloudSyncStatus.synced &&
                  !backup.hasPendingChanges;
            } catch (_) {
              // The local workspace and pending marker remain intact.
            }
            if (uploaded) {
              if (_connectedGoogleWorkspaceId != null) {
                await ref
                    .read(localBackupServiceProvider)
                    .markGuestAdoptionBackupVerified(
                      _connectedGoogleWorkspaceId!,
                    );
              }
              await database.clearPendingInitialCloudBackup(
                localAccountId: _connectedGoogleWorkspaceId == null
                    ? null
                    : googleLocalWorkspaceId(
                        _connectedGoogleWorkspaceId!,
                      ),
              );
              ref.invalidate(initialCloudBackupPendingProvider);
            } else {
              // Home remains available; retain the pending marker for a later
              // account-scoped retry or app restart.
              ref
                  .read(
                      skipPendingInitialCloudBackupForSessionProvider.notifier)
                  .state = false;
            }
          }
        }
        await _completeChoice();
        return;
      case CloudBackupDiscoveryStatus.backupFound:
        _driveDiscoveryUnverified = false;
        _driveBackupInvalid = false;
        setState(() {
          _discovery = result;
        });
        final conflict = result.conflict;
        final localAccountId =
            ref.read(accountSessionManagerProvider).activeLocalAccountId;
        if (conflict != null &&
            localAccountId != null &&
            await ref
                .read(appDatabaseProvider)
                .isFreshInstallationForCloudRestore(
                  localAccountId: localAccountId,
                ) &&
            conflict.localRevision ==
                await ref.read(appDatabaseProvider).readDbRevision()) {
          // Automatic replacement is permitted only when the database itself
          // proves this is a fresh install, not merely an incomplete profile.
          await _restoreBackupAutomatically(conflict);
        }
        return;
    }
  }

  Future<String?> _chooseGuestWorkspace(
    List<LocalAccount> guests,
  ) {
    final l10n = AppLocalizations.of(context);
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.accountTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.accountChoiceGuestDescription),
              const SizedBox(height: 8),
              for (final guest in guests)
                ListTile(
                  key: Key('guest_workspace_choice_${guest.localAccountId}'),
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(
                    guestWorkspaceDisplayLabel(
                      guest,
                      guests,
                      fallbackName: l10n.accountGuest,
                    ),
                  ),
                  subtitle: Text(
                    guest.lifecycleState == AccountLifecycleState.draft
                        ? 'Setup in progress · Continue this workspace'
                        : l10n.accountChoiceGuestDescription,
                  ),
                  onTap: () =>
                      Navigator.of(dialogContext).pop(guest.localAccountId),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            key: const Key('guest_workspace_start_fresh'),
            onPressed: () => Navigator.of(dialogContext).pop(_startFreshChoice),
            child: const Text('Start Fresh'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectGoogle() async {
    if (_working) return;
    setState(() {
      _working = true;
      _discovery = null;
    });
    try {
      await _persistSelectedLanguage();
      if (!mounted) return;
      final accountProvider = ref.read(cloudAccountProvider);
      _cloudAttempted = true;
      final account = await accountProvider.signIn();
      if (!mounted || account.wasCancelled) return;
      if (!account.isConnected) {
        _accountConnected = false;
        _showFailure(
          error: account.message,
          fallbackMessage: AppLocalizations.of(context).cloudConnectionFailed,
          onRetry: _connectGoogle,
        );
        return;
      }
      final stableId = account.accountId?.trim();
      final workspaceId = stableId == null || stableId.isEmpty
          ? null
          : googleLocalWorkspaceId(stableId);
      final existed = workspaceId != null &&
          await ref.read(accountLocalStoreProvider).getAccount(workspaceId) !=
              null;
      await _activateGoogleWorkspace(account);
      _accountConnected = true;
      _googleWorkspaceMayAdoptGuest = !existed;
      _connectedGoogleWorkspaceId = workspaceId;
      _connectedGoogleDisplayName = account.displayName?.trim() ?? '';
      // The explicit Google action establishes the identity. Backup discovery
      // then decides whether to adopt Guest data, restore, or start fresh.
      await _discoverBackup(
        allowInteractive: true,
        allowGuestAdoptionChoice: !existed,
        googleWorkspaceId: workspaceId,
        googleDisplayName: _connectedGoogleDisplayName,
      );
    } catch (error) {
      if (mounted) {
        _showFailure(
          error: error,
          fallbackMessage: AppLocalizations.of(context).cloudConnectionFailed,
          onRetry: _connectGoogle,
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _continueLocally() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await _persistSelectedLanguage();
      if (_accountConnected &&
          _connectedGoogleWorkspaceId != null &&
          _driveDiscoveryUnverified) {
        // Drive failure is not proof that no backup exists. Keep the verified
        // Google workspace local and usable, but persist a block that prevents
        // both foreground and scheduled uploads until discovery succeeds.
        final workspaceId = _connectedGoogleWorkspaceId!;
        final database = ref.read(appDatabaseProvider);
        await database.writeWorkspaceSyncState(
          workspaceId,
          _driveBackupInvalid ? 'legacy_unverified' : 'cloud_unverified',
          localRevision: await database.readWorkspaceRevision(workspaceId),
        );
        ref.invalidate(appRouteProvider);
        ref.invalidate(userProfileProvider);
        ref.invalidate(progressSummaryProvider);
        ref.invalidate(qazaRepositoryProvider);
        ref.invalidate(qazaAdditionRepositoryProvider);
        ref.invalidate(qazaPlanRevisionRepositoryProvider);
        await _completeChoice();
        return;
      }
      // A definite no-backup result or an explicit, resolved backup choice is
      // required before leaving the verified Google workspace for Guest.
      if (_accountConnected || _cloudAttempted) {
        try {
          await ref.read(cloudAccountProvider).disconnect();
        } catch (_) {
          // Failed interactive sign-in must not trap the user on this screen.
          // If a session had actually connected, require disconnect to finish.
          if (_accountConnected) rethrow;
        }
        _accountConnected = false;
      }
      final accountStore = ref.read(accountLocalStoreProvider);
      final guests = await accountStore.listGuestWorkspaces();
      String selectedGuestId;
      if (guests.isEmpty) {
        selectedGuestId = await accountStore.createGuestWorkspace(draft: true);
      } else {
        final choice = await _chooseGuestWorkspace(guests);
        if (!mounted || choice == null) return;
        selectedGuestId = choice == _startFreshChoice
            ? await accountStore.createGuestWorkspace(draft: true)
            : choice;
      }
      // AccountLocalStore creates workspaces durably; activate through the
      // session manager too so Riverpod and every workspace-scoped provider
      // receive the new identity before StartupGate renders a destination.
      await ref
          .read(accountSessionManagerProvider)
          .activateLocalAccount(selectedGuestId);
      ref.invalidate(appRouteProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(progressSummaryProvider);
      ref.invalidate(qazaRepositoryProvider);
      ref.invalidate(qazaAdditionRepositoryProvider);
      ref.invalidate(qazaPlanRevisionRepositoryProvider);
      ref.read(skipPendingInitialCloudBackupForSessionProvider.notifier).state =
          false;
      await _completeChoice();
    } catch (error) {
      if (mounted) {
        _showFailure(
          error: error,
          fallbackMessage: AppLocalizations.of(context).errorUnknown,
          onRetry: _continueLocally,
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restoreBackupAutomatically(
    CloudConflictInfo conflict,
  ) async {
    if (!mounted) return;
    setState(() {
      _restoring = true;
      _restoreProgress = const CloudBackupProgress.checking();
    });
    try {
      final result = await ref.read(cloudSyncProvider).resolveConflict(
            conflict: conflict,
            choice: CloudConflictChoice.useRemote,
            // This is safe only after the fresh-install database predicate and
            // unchanged revision were verified immediately before this call.
            confirmed: true,
            onProgress: (progress) {
              if (mounted) setState(() => _restoreProgress = progress);
            },
          );
      if (!mounted) return;
      if (result.status != CloudSyncStatus.synced ||
          !result.restoredRemoteBackup) {
        _showFailure(
          error: result.message,
          fallbackMessage:
              AppLocalizations.of(context).cloudRestoreFailedMessage,
          onRetry: _retry,
          restoreFailure: true,
        );
        return;
      }

      final database = ref.read(appDatabaseProvider);
      await database.clearPendingInitialCloudBackup();
      ref.invalidate(initialCloudBackupPendingProvider);
      await ref.read(accountSessionManagerProvider).refresh();
      ref.invalidate(appRouteProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(progressSummaryProvider);
      ref.invalidate(qazaRepositoryProvider);
      ref.invalidate(qazaAdditionRepositoryProvider);
      ref.invalidate(qazaPlanRevisionRepositoryProvider);
      await _completeChoice();
    } catch (error) {
      if (mounted) {
        _showFailure(
          error: error,
          fallbackMessage:
              AppLocalizations.of(context).cloudRestoreFailedMessage,
          onRetry: _retry,
          restoreFailure: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _restoring = false;
          _restoreProgress = null;
        });
      }
    }
  }

  Future<void> _restoreBackup() async {
    final conflict = _discovery?.conflict;
    if (_working || conflict == null) return;

    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cloudUseRemoteConfirmTitle),
        content: Text(l10n.cloudUseRemoteConfirmMessage),
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
      _working = true;
      _restoring = true;
      _restoreProgress = const CloudBackupProgress.checking();
    });
    try {
      final result = await ref.read(cloudSyncProvider).resolveConflict(
            conflict: conflict,
            choice: CloudConflictChoice.useRemote,
            confirmed: true,
            onProgress: (progress) {
              if (mounted) setState(() => _restoreProgress = progress);
            },
          );
      if (!mounted) return;

      if (result.status != CloudSyncStatus.synced ||
          !result.restoredRemoteBackup) {
        if (result.status == CloudSyncStatus.synced) {
          // A stale conflict may have been recomputed into an upload/no-op.
          // Rediscover instead of treating that as a successful restoration.
          await _discoverBackup();
        } else if (mounted) {
          _showFailure(
            error: result.message,
            fallbackMessage: l10n.cloudRestoreFailedMessage,
            onRetry: _restoreBackup,
            restoreFailure: true,
          );
        }
        return;
      }

      // Backup import replaces local account/session/profile rows. Clear
      // any stale initial-backup marker, then reload before StartupGate routes.
      await ref.read(appDatabaseProvider).clearPendingInitialCloudBackup();
      ref.invalidate(initialCloudBackupPendingProvider);
      await ref.read(accountSessionManagerProvider).refresh();
      ref.invalidate(appRouteProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(progressSummaryProvider);
      ref.invalidate(qazaRepositoryProvider);
      ref.invalidate(qazaAdditionRepositoryProvider);
      ref.invalidate(qazaPlanRevisionRepositoryProvider);
      await _completeChoice();
    } catch (error) {
      if (mounted) {
        _showFailure(
          error: error,
          fallbackMessage: l10n.cloudRestoreFailedMessage,
          onRetry: _restoreBackup,
          restoreFailure: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _working = false;
          _restoring = false;
          _restoreProgress = null;
        });
      }
    }
  }

  Future<void> _retry() async {
    if (_working) return;
    if (!_accountConnected) {
      await _connectGoogle();
      return;
    }

    setState(() {
      _working = true;
    });
    try {
      await _persistSelectedLanguage();
      await _discoverBackup(allowInteractive: true);
    } catch (error) {
      if (mounted) {
        _showFailure(
          error: error,
          fallbackMessage: AppLocalizations.of(context).cloudConnectionFailed,
          onRetry: _retry,
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _chooseAnotherGoogleAccount() async {
    if (_working) return;

    if (_accountConnected) {
      setState(() => _working = true);
      try {
        await ref.read(cloudAccountProvider).disconnect();
        _accountConnected = false;
        _cloudAttempted = false;
        _discovery = null;
      } catch (error) {
        if (mounted) {
          _showFailure(
            error: error,
            fallbackMessage: AppLocalizations.of(context).cloudConnectionFailed,
            onRetry: _chooseAnotherGoogleAccount,
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _working = false);
      }
    }

    if (mounted) await _connectGoogle();
  }

  void _showFailure({
    required Object? error,
    required String fallbackMessage,
    required Future<void> Function() onRetry,
    bool invalidBackup = false,
    bool restoreFailure = false,
  }) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final detail = error?.toString() ?? '';
    final normalized = detail.toLowerCase();
    final incompatibleBackup = invalidBackup ||
        normalized.contains('schema') ||
        normalized.contains('unsupported backup') ||
        normalized.contains('invalid backup') ||
        normalized.contains('backup is corrupt') ||
        normalized.contains('malformed backup') ||
        normalized.contains('corrupt backup');

    if (incompatibleBackup) {
      _showErrorDialog(
        message: l10n.cloudSetupBackupUnreadableMessage,
        actionLabel: l10n.cloudSetupChooseAnotherAccount,
        onAction: _chooseAnotherGoogleAccount,
      );
      return;
    }

    final googleConfigurationFailure =
        normalized.contains('clientconfigurationerror') ||
            normalized.contains('providerconfigurationerror') ||
            normalized.contains('invalid_client') ||
            normalized.contains('client configuration') ||
            normalized.contains('provider configuration');
    if (googleConfigurationFailure) {
      _showErrorDialog(
        message: l10n.cloudSetupGoogleConfigurationMessage,
        actionLabel: l10n.cloudSetupContinueLocal,
        onAction: _continueLocally,
      );
      return;
    }

    final accountMismatch = normalized.contains('did not match') ||
        normalized.contains('does not match') ||
        normalized.contains('no longer available') ||
        normalized.contains('usermismatch');
    if (accountMismatch) {
      _showErrorDialog(
        message: l10n.cloudConnectionFailed,
        actionLabel: l10n.cloudSetupChooseAnotherAccount,
        onAction: _chooseAnotherGoogleAccount,
      );
      return;
    }

    final classified = AppError.from(error ?? Exception(fallbackMessage));
    final message = restoreFailure
        ? l10n.cloudRestoreFailedMessage
        : classified.kind == AppErrorKind.unknown
            ? fallbackMessage
            : classified.message(context);
    _showErrorDialog(
      message: message,
      actionLabel: classified.isRetryable ? l10n.commonRetry : null,
      onAction: classified.isRetryable ? onRetry : null,
    );
  }

  void _showErrorDialog({
    required String message,
    String? actionLabel,
    Future<void> Function()? onAction,
  }) {
    if (!mounted) return;
    _queuedErrorDialogs.add(
      _QueuedCloudErrorDialog(
        message: message,
        actionLabel: actionLabel,
        onAction: onAction,
      ),
    );
    _scheduleNextErrorDialog();
  }

  void _scheduleNextErrorDialog() {
    if (!mounted ||
        _errorDialogScheduled ||
        _errorDialogShowing ||
        _queuedErrorDialogs.isEmpty) {
      return;
    }
    _errorDialogScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _errorDialogScheduled = false;
      if (!mounted || _errorDialogShowing || _queuedErrorDialogs.isEmpty) {
        return;
      }
      final next = _queuedErrorDialogs.removeAt(0);
      unawaited(_presentErrorDialog(next));
    });
  }

  Future<void> _presentErrorDialog(_QueuedCloudErrorDialog request) async {
    if (!mounted) return;
    _errorDialogShowing = true;
    var invokeAction = false;
    final l10n = AppLocalizations.of(context);
    try {
      invokeAction = await showDialog<bool>(
            context: context,
            barrierDismissible: true,
            builder: (dialogContext) => AlertDialog(
              title: Text(l10n.stateErrorTitle),
              content: Text(request.message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.commonCancel),
                ),
                if (request.actionLabel != null && request.onAction != null)
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(request.actionLabel!),
                  ),
              ],
            ),
          ) ??
          false;
    } finally {
      _errorDialogShowing = false;
    }

    if (!mounted) return;
    if (invokeAction && request.onAction != null) {
      await request.onAction!();
    }
    _scheduleNextErrorDialog();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final themeMode = ref.watch(themeModeProvider);
    PopupMenuItem<AppThemeMode> themeModeItem(
      AppThemeMode mode,
      String label,
    ) =>
        PopupMenuItem<AppThemeMode>(
          key: Key('cloud_setup_theme_option_${mode.name}'),
          value: mode,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              if (mode == themeMode)
                Icon(Icons.check_rounded, color: scheme.primary, size: 18)
              else
                const SizedBox(width: 18),
            ],
          ),
        );
    final backupFound =
        _discovery?.status == CloudBackupDiscoveryStatus.backupFound;
    final restoreProgress = _restoreProgress;
    final restoreTotalBytes = restoreProgress?.totalBytes ?? 0;
    final restoreReceivedBytes = restoreProgress?.sentBytes ?? 0;
    final hasRestoreByteProgress = _restoring &&
        restoreProgress?.stage == CloudBackupProgressStage.downloading &&
        restoreReceivedBytes > 0;
    final restoreRatio = hasRestoreByteProgress && restoreTotalBytes > 0
        ? (restoreReceivedBytes / restoreTotalBytes).clamp(0.0, 1.0).toDouble()
        : null;
    final visibleRestoreRatio =
        restoreRatio == null ? null : (restoreRatio >= 1 ? 0.99 : restoreRatio);
    final visibleRestorePercent = visibleRestoreRatio == null
        ? null
        : (visibleRestoreRatio * 100).round();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const SizedBox.shrink(),
        actions: [
          PopupMenuButton<AppThemeMode>(
            key: const Key('cloud_setup_theme_selector'),
            tooltip: l10n.settingsThemeSelector,
            onSelected: ref.read(themeModeProvider.notifier).set,
            itemBuilder: (context) => [
              themeModeItem(AppThemeMode.system, l10n.settingsThemeSystem),
              themeModeItem(AppThemeMode.light, l10n.settingsThemeLight),
              themeModeItem(AppThemeMode.dark, l10n.settingsThemeDark),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${l10n.settingsThemeSelector}: ${appThemeModeLabel(l10n, themeMode)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall,
                  ),
                  const Icon(Icons.expand_more_rounded, size: 18),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: LanguageSelector<Locale>(
              key: const Key('cloud_setup_language_selector'),
              options: AppLocalizations.supportedLocales
                  .map(
                    (locale) => LanguageOption<Locale>(
                      value: locale,
                      languageCode: locale.languageCode,
                      scriptCode: locale.scriptCode,
                    ),
                  )
                  .toList(growable: false),
              value: _selectedLocale,
              layout: LanguageSelectorLayout.compact,
              semanticLabel: l10n.profileLanguageTitle,
              optionKeyPrefix: 'cloud_setup_language',
              enabled: !_working,
              onChanged: _selectLanguage,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              shrinkWrap: true,
              children: [
                Center(
                  child: Image.asset(
                    'assets/branding/qaza_namaz_logo.png',
                    width: 88,
                    height: 88,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.cloudSetupChoiceTitle,
                  style: theme.textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.cloudSetupChoiceDescription,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (backupFound) ...[
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.cloud_download_outlined,
                            size: 30,
                            color: scheme.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.cloudBackupConflictTitle,
                            style: theme.textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.cloudBackupConflictMessage,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              key: const Key('cloud_setup_restore_backup'),
                              onPressed: _working ? null : _restoreBackup,
                              icon: const Icon(Icons.cloud_download_outlined),
                              label: Text(l10n.cloudUseRemote),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (_working) ...[
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _restoring
                                ? switch (_restoreProgress?.stage) {
                                    CloudBackupProgressStage.downloading =>
                                      l10n.cloudRestoreStageTransferring,
                                    CloudBackupProgressStage.preparing =>
                                      l10n.cloudRestoreStageRestoring,
                                    CloudBackupProgressStage.uploading =>
                                      l10n.cloudRestoreStageTransferring,
                                    CloudBackupProgressStage.completed =>
                                      l10n.cloudRestoreStageFinishing,
                                    _ => l10n.cloudRestoreStageChecking,
                                  }
                                : l10n.cloudRestoreConnectingTitle,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _restoring
                                ? l10n.cloudRestoreProgressBody
                                : l10n.cloudRestoreConnectingBody,
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(
                            value: visibleRestoreRatio,
                          ),
                          if (hasRestoreByteProgress) ...[
                            const SizedBox(height: 8),
                            Text(
                              restoreTotalBytes > 0
                                  ? '${(restoreReceivedBytes / (1024 * 1024)).toStringAsFixed(2)} MB / '
                                      '${(restoreTotalBytes / (1024 * 1024)).toStringAsFixed(2)} MB'
                                      ' · ${visibleRestorePercent ?? 0}%'
                                  : '${(restoreReceivedBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: OutlinedButton(
                    key: const Key('cloud_setup_connect_google'),
                    onPressed: _working ? null : _connectGoogle,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: scheme.surface,
                      foregroundColor: scheme.onSurface,
                      side: BorderSide(color: scheme.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_working)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const _GoogleGMark(),
                        const SizedBox(width: 12),
                        Text(l10n.cloudSetupUseGoogle),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('cloud_setup_continue_local'),
                    onPressed: _working ? null : _continueLocally,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(l10n.cloudSetupContinueLocal),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Google sign-in mark drawn with the four Google brand colors. Drawing the
/// mark locally avoids a platform-specific monochrome icon or white asset.
class _GoogleGMark extends StatelessWidget {
  const _GoogleGMark();

  @override
  Widget build(BuildContext context) => const CustomPaint(
        key: Key('google_g_mark'),
        size: Size(24, 24),
        painter: _GoogleGMarkPainter(),
      );
}

class _GoogleGMarkPainter extends CustomPainter {
  const _GoogleGMarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 4.0;
    final radius = size.shortestSide / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: radius,
    );

    void arc(Color color, double start, double sweep) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(rect, start, sweep, false, paint);
    }

    const gap = 0.12;
    arc(const Color(0xFFEA4335), -math.pi / 2 + gap, math.pi / 2 - gap * 2);
    arc(const Color(0xFF4285F4), gap, math.pi / 2 - gap * 2);
    arc(const Color(0xFF34A853), math.pi / 2 + gap, math.pi / 2 - gap * 2);
    arc(const Color(0xFFFBBC05), math.pi + gap, math.pi / 2 - gap * 2);

    final bar = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(
      Offset(size.width / 2, size.height / 2),
      Offset(size.width - 1, size.height / 2),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleGMarkPainter oldDelegate) => false;
}

class _QueuedCloudErrorDialog {
  const _QueuedCloudErrorDialog({
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? actionLabel;
  final Future<void> Function()? onAction;
}
