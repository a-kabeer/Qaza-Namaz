import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/settings_components.dart';
import '../../data/auth/google_sign_in_identity_provider.dart';
import '../../data/auth/supabase_auth_service.dart';
import '../../domain/entities/local_account.dart';
import '../../domain/services/google_identity_contracts.dart';
import '../../l10n/app_localizations.dart';
import '../data_management/qaza_data_management_screen.dart';
import '../onboarding/welcome_auth_screen.dart';
import '../settings/qaza_reset_controller.dart';
import 'guest_workspace_management_screen.dart';
import 'supabase_auth_dialog.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.autoConnect = false});

  final bool autoConnect;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  GoogleIdentitySnapshot _identity = const GoogleIdentitySnapshot.unavailable();
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
      final l10n = AppLocalizations.of(context);
      final googleIdentity = ref.read(googleIdentityProvider);
      if (googleIdentity is GoogleSignInIdentityProvider) {
        final result = await googleIdentity.signInWithTokens();
        if (!mounted ||
            result.snapshot.status == GoogleIdentityStatus.cancelled) {
          return;
        }
        if (result.snapshot.status == GoogleIdentityStatus.signedIn) {
          final idToken = result.idToken;
          if (idToken == null) {
            setState(() => _error = l10n.accountChoiceGoogleFailed);
            return;
          }

          final authService = ref.read(supabaseAuthServiceProvider);
          final authResult =
              await authService.signInWithGoogleNative(idToken: idToken);

          if (!authResult.isSuccess || authResult.user == null) {
            if (mounted) {
              setState(() {
                _error = _mapFriendlyGoogleError(l10n, authResult.errorMessage);
              });
            }
            return;
          }

          final user = authResult.user!;
          final sessionManager = ref.read(accountSessionManagerProvider);
          final targetWorkspaceId = supabaseLocalWorkspaceId(user.id);

          await sessionManager.activateSupabaseAccount(user.id);
          final displayName = result.snapshot.displayName?.trim() ??
              (user.userMetadata?['full_name'] as String?)?.trim();
          if (displayName != null && displayName.isNotEmpty) {
            await ref.read(accountLocalStoreProvider).saveWorkspaceDisplayName(
                  targetWorkspaceId,
                  displayName,
                );
          }
          ref.read(startupWorkspaceRestoreSatisfiedProvider.notifier).state =
              true;

          try {
            await ref.read(appRouteProvider.future);
          } catch (_) {}
          try {
            await ref.read(userProfileProvider.future);
          } catch (_) {}

          if (!mounted) return;
          Navigator.of(context).popUntil((route) => route.isFirst);

          ref.read(appSnackbarServiceProvider).success(
                l10n.accountConnectedSuccess,
              );
          return;
        }
      }

      final identity = await ref.read(googleIdentityProvider).signIn();
      if (!mounted || identity.status == GoogleIdentityStatus.cancelled) return;
      if (!identity.isSignedIn) {
        setState(() => _error = identity.message ??
            AppLocalizations.of(context).accountChoiceGoogleFailed);
        return;
      }
      await _activateGoogleWorkspace(identity);
      if (mounted) setState(() => _identity = identity);
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = AppLocalizations.of(context).accountChoiceGoogleFailed);
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
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    await ref
        .read(accountSessionManagerProvider)
        .activateGoogleAccount(accountId);
    final workspaceId =
        ref.read(accountSessionManagerProvider).activeLocalAccountId;
    final displayName = identity.displayName?.trim();
    if (workspaceId != null && displayName != null && displayName.isNotEmpty) {
      await ref
          .read(accountLocalStoreProvider)
          .saveWorkspaceDisplayName(workspaceId, displayName);
    }
    ref.read(startupWorkspaceRestoreSatisfiedProvider.notifier).state = true;
  }

  Future<void> _signOut() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.accountSignOutConfirmTitle),
        content: Text(l10n.accountSignOutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.accountSignOutConfirmAction),
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
      await ref.read(supabaseAuthServiceProvider).signOut();
      ref.invalidate(supabaseAuthStateStreamProvider);

      // Reset local session back to guest
      await ref.read(accountSessionManagerProvider).activateGuest();

      // Mark sign-out state so restart or gate goes to Welcome screen
      await ref.read(appDatabaseProvider).markReturningAccountChoicePending();
      ref.read(startupWorkspaceRestoreSatisfiedProvider.notifier).state = false;
      ref.invalidate(returningAccountChoicePendingProvider);
      ref.invalidate(accountChoiceCompleteProvider);
      ref.invalidate(userProfileProvider);
      ref.invalidate(appRouteProvider);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const WelcomeAuthScreen()),
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
    ref.invalidate(accountChoiceCompleteProvider);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const WelcomeAuthScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = ref.watch(googleIdentityProvider);
    final supabaseAuth = ref.watch(supabaseAuthServiceProvider);
    final supabaseUser = supabaseAuth.currentUser;
    final activeAccount =
        ref.watch(accountSessionManagerProvider).activeAccount;
    final isGuest = isGuestLocalWorkspaceId(activeAccount?.localAccountId);
    final activeGoogleWorkspace =
        activeAccount?.localAccountId.startsWith('google_') ?? false;

    // Single unified connection state
    final connected = _identity.isSignedIn || supabaseAuth.isSignedIn;

    final rawName = _identity.displayName?.trim() ??
        (supabaseUser?.userMetadata?['full_name'] as String?)?.trim();
    final rawEmail = _identity.email?.trim() ?? supabaseUser?.email?.trim();
    final displayName = rawName?.isNotEmpty == true
        ? rawName!
        : rawEmail?.isNotEmpty == true
            ? rawEmail!
            : l10n.accountGuest;
    final email = rawEmail?.isNotEmpty == true && rawEmail != displayName
        ? rawEmail
        : null;
    final photoUrl = _safeGooglePhotoUrl(_identity.photoUrl) ??
        _safeGooglePhotoUrl(
            supabaseUser?.userMetadata?['avatar_url'] as String?);

    void open(Widget screen) {
      Navigator.push(context, MaterialPageRoute<void>(builder: (_) => screen));
    }

    return AppScaffold(
      title: l10n.accountTitle,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          // 1. Unified Profile Header Card
          Card(
            key: const Key('account_google_profile_card'),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: connected && photoUrl != null
                        ? NetworkImage(photoUrl)
                        : null,
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
                                      ? (activeAccount?.displayName
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                          ? activeAccount!.displayName!
                                          : l10n.accountGoogle)
                                      : l10n.accountGuest,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (connected && email != null) ...[
                          const SizedBox(height: 2),
                          Text(email,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                        const SizedBox(height: 6),
                        if (connected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.green,
                                  size: 14,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  l10n.accountStatusProtected,
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Text(
                            l10n.accountGuestDeviceOnly,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Options to Connect Account (Only for Guest)
          if (!connected) ...[
            Card(
              key: const Key('account_supabase_cloud_card'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.accountProtectRecordsTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.accountProtectRecordsSubtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                    if (provider.isSupported) ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('account_google_login'),
                          onPressed: _working || _loading ? null : _signIn,
                          icon: const Icon(Icons.login_rounded),
                          label: Text(l10n.accountChoiceContinueGoogle),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.tonalIcon(
                        key: const Key('account_supabase_connect'),
                        icon: const Icon(Icons.email_outlined),
                        label: Text(l10n.accountConnectEmail),
                        onPressed: () async {
                          final success =
                              await SupabaseAuthDialog.show(context);
                          if (success == true && mounted) {
                            ref.read(appSnackbarServiceProvider).success(
                                  l10n.accountConnectedSuccess,
                                );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: SettingsNavRow(
                key: const Key('account_guest_workspace_management'),
                icon: Icons.people_outline_rounded,
                title: l10n.accountGuestProfilesTitle,
                subtitle: l10n.accountGuestProfilesSubtitle,
                onTap: () => open(const GuestWorkspaceManagementScreen()),
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_working) ...[
            const SizedBox(height: 8),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 8),
          ],

          // 3. Data & Backup Section (Clean, Human & Non-technical)
          Card(
            child: Column(
              children: [
                SettingsNavRow(
                  key: const Key('account_data_management'),
                  icon: Icons.inventory_2_outlined,
                  title: l10n.dataBackupAndRestoreTitle,
                  subtitle: l10n.dataBackupAndRestoreSubtitle,
                  onTap: () => open(const QazaDataManagementScreen()),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                const _ResetQazaCounterRow(),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 4. Bottom Action: Sign Out (when connected) or Return to Welcome (when guest)
          if (connected)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const Key('account_google_sign_out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(
                    color: Theme.of(context)
                        .colorScheme
                        .error
                        .withValues(alpha: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _working ? null : _signOut,
                icon: const Icon(Icons.logout_rounded),
                label: Text(
                  l10n.accountSignOut,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            )
          else if (isGuest)
            Center(
              child: TextButton.icon(
                key: const Key('account_guest_account_choice'),
                onPressed: _working ? null : _returnToAccountChoice,
                icon: const Icon(Icons.arrow_back_rounded),
                label: Text(l10n.accountReturnToWelcome),
              ),
            ),
        ],
      ),
    );
  }
}

String _mapFriendlyGoogleError(AppLocalizations l10n, String? raw) {
  if (raw == null || raw.isEmpty) {
    return l10n.accountChoiceGoogleFailed;
  }
  final lower = raw.toLowerCase();
  if (lower.contains('unacceptable audience') ||
      lower.contains('audience') ||
      lower.contains('client_id')) {
    return l10n.cloudSetupGoogleConfigurationMessage;
  }
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network') ||
      lower.contains('client is not initialized')) {
    return l10n.authErrorNetwork;
  }
  return l10n.accountConnectFailed;
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
