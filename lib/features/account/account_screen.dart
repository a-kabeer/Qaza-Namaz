import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/local_account.dart';
import '../../domain/services/google_identity_contracts.dart';
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
  GoogleIdentitySnapshot _identity =
      const GoogleIdentitySnapshot.unavailable();
  bool _loading = true;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_restoreIdentity);
  }

  Future<void> _restoreIdentity() async {
    try {
      final identity = await ref.read(googleIdentityProvider).restore();
      if (!mounted) return;
      setState(() {
        _identity = identity;
        _loading = false;
      });
      if (widget.autoConnect && !identity.isSignedIn) {
        await _signIn();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _identity = const GoogleIdentitySnapshot.signedOut();
        _loading = false;
      });
    }
  }

  Future<void> _signIn() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final identity = await ref.read(googleIdentityProvider).signIn();
      if (!mounted || identity.status == GoogleIdentityStatus.cancelled) return;
      if (!identity.isSignedIn) {
        setState(() => _error =
            identity.message ?? AppLocalizations.of(context).accountChoiceGoogleFailed);
        return;
      }
      await _activateGoogleWorkspace(identity);
      if (mounted) setState(() => _identity = identity);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            AppLocalizations.of(context).accountChoiceGoogleFailed);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _activateGoogleWorkspace(
    GoogleIdentitySnapshot identity,
  ) async {
    final accountId = identity.accountId?.trim();
    if (accountId == null || accountId.isEmpty) {
      throw StateError('Google returned an empty account identifier.');
    }
    await ref.read(accountSessionManagerProvider).activateGoogleAccount(accountId);
    final workspaceId =
        ref.read(accountSessionManagerProvider).activeLocalAccountId;
    final displayName = identity.displayName?.trim();
    if (workspaceId != null &&
        displayName != null &&
        displayName.isNotEmpty) {
      await ref
          .read(accountLocalStoreProvider)
          .saveWorkspaceDisplayName(workspaceId, displayName);
    }
    ref.read(startupWorkspaceRestoreSatisfiedProvider.notifier).state = true;
    ref.invalidate(appRouteProvider);
  }

  Future<void> _signOut() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.accountSignOutPrompt),
        content: Text(l10n.accountSignOutExplanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.accountSignOut),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _working) return;

    setState(() {
      _working = true;
      _error = null;
    });
    try {
      if (ref.read(googleIdentityProvider).isSupported) {
        await ref.read(googleIdentityProvider).signOut();
      }
      // Sign-out changes identity selection only. The local database and all
      // Google/Guest workspaces remain untouched.
      await ref.read(appDatabaseProvider).markReturningAccountChoicePending();
      ref.read(startupWorkspaceRestoreSatisfiedProvider.notifier).state = false;
      ref.invalidate(returningAccountChoicePendingProvider);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const StartupGate()),
        (_) => false,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = l10n.accountProfileUnavailableDetail);
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _returnToAccountChoice() async {
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
    final provider = ref.watch(googleIdentityProvider);
    final activeAccount =
        ref.watch(accountSessionManagerProvider).activeAccount;
    final isGuest = isGuestLocalWorkspaceId(activeAccount?.localAccountId);
    final activeGoogleWorkspace =
        activeAccount?.localAccountId.startsWith('google_') ?? false;
    final connected = _identity.isSignedIn;
    final rawName = _identity.displayName?.trim();
    final rawEmail = _identity.email?.trim();
    final displayName = rawName?.isNotEmpty == true
        ? rawName!
        : rawEmail?.isNotEmpty == true
            ? rawEmail!
            : l10n.accountNotAvailable;
    final email = rawEmail?.isNotEmpty == true && rawEmail != displayName
        ? rawEmail
        : null;
    final photoUrl = _safeGooglePhotoUrl(_identity.photoUrl);

    void open(Widget screen) {
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
    }

    return AppScaffold(
      title: l10n.accountTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Card(
            key: const Key('account_google_profile_card'),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage:
                        connected && photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: !connected || photoUrl == null
                        ? const Icon(Icons.person_outline_rounded, size: 30)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loading
                              ? l10n.accountProfileChecking
                              : connected
                                  ? displayName
                                  : activeGoogleWorkspace
                                      ? (activeAccount?.displayName?.trim().isNotEmpty == true
                                          ? activeAccount!.displayName!
                                          : l10n.accountGoogle)
                                      : l10n.accountGuest,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (connected && email != null)
                          Text(email, style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text(
                          connected
                              ? l10n.accountSignedInWithGoogle
                              : activeGoogleWorkspace
                                  ? l10n.accountProfileUnavailableDetail
                                  : l10n.accountChoiceGuestDescription,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (provider.isSupported)
            SizedBox(
              width: double.infinity,
              child: connected
                  ? OutlinedButton.icon(
                      key: const Key('account_google_sign_out'),
                      onPressed: _working ? null : _signOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(l10n.accountSignOut),
                    )
                  : FilledButton.icon(
                      key: const Key('account_google_login'),
                      onPressed: _working || _loading ? null : _signIn,
                      icon: const Icon(Icons.login_rounded),
                      label: Text(l10n.accountChoiceContinueGoogle),
                    ),
            ),
          if (isGuest && provider.isSupported && !connected) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('account_guest_account_choice'),
              onPressed: _working ? null : _returnToAccountChoice,
              child: Text(l10n.accountChoiceContinueGuest),
            ),
          ],
          if (_working) ...[
            const SizedBox(height: 12),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            child: SettingsNavRow(
              key: const Key('account_guest_workspace_management'),
              icon: Icons.manage_accounts_outlined,
              title: l10n.accountGuestTitle,
              subtitle: l10n.accountGuestLocalDataSubtitle,
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

String? _safeGooglePhotoUrl(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty) {
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
