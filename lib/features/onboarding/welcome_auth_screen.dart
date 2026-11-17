import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/language_selector.dart';
import '../../data/auth/google_sign_in_identity_provider.dart';
import '../../data/auth/supabase_auth_service.dart';
import '../../domain/entities/local_account.dart';
import '../../domain/services/google_identity_contracts.dart';
import '../../l10n/app_localizations.dart';
import '../account/guest_workspace_label.dart';
import '../account/supabase_auth_dialog.dart';
import 'startup_gate.dart';

/// First-run entry screen presenting global language & theme selection,
/// alongside Authentication choices (Google, Email, Guest).
class WelcomeAuthScreen extends ConsumerStatefulWidget {
  const WelcomeAuthScreen({super.key});

  @override
  ConsumerState<WelcomeAuthScreen> createState() => _WelcomeAuthScreenState();
}

class _WelcomeAuthScreenState extends ConsumerState<WelcomeAuthScreen> {
  bool _loading = false;
  String? _errorMessage;

  Future<void> _continueWithGoogle() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final googleIdentity = ref.read(googleIdentityProvider);
      String? googleId;

      if (googleIdentity is GoogleSignInIdentityProvider) {
        final result = await googleIdentity.signInWithTokens();
        debugPrint(
            '[WelcomeAuthScreen] GoogleSignIn status: ${result.snapshot.status}, message: ${result.snapshot.message}, hasToken: ${result.idToken != null}');
        if (result.snapshot.status == GoogleIdentityStatus.cancelled) {
          if (mounted) setState(() => _loading = false);
          return;
        }

        if (result.snapshot.status == GoogleIdentityStatus.signedIn) {
          googleId = result.snapshot.accountId;
          final idToken = result.idToken;
          if (idToken != null) {
            final authService = ref.read(supabaseAuthServiceProvider);
            final authResult = await authService.signInWithGoogleNative(
              idToken: idToken,
            );
            if (authResult.isSuccess && authResult.user != null) {
              final sessionManager = ref.read(accountSessionManagerProvider);
              await sessionManager.activateSupabaseAccount(authResult.user!.id);
              await _completeAndProceed();
              return;
            } else {
              if (mounted) {
                final l10n = AppLocalizations.of(context);
                setState(() {
                  _errorMessage = _mapFriendlyGoogleError(
                    l10n,
                    authResult.errorMessage,
                  );
                });
              }
              return;
            }
          }
        }
      } else {
        // Fallback for tests or standard mock harness
        final snapshot = await googleIdentity.signIn();
        if (snapshot.status == GoogleIdentityStatus.cancelled) {
          if (mounted) setState(() => _loading = false);
          return;
        }
        if (snapshot.status == GoogleIdentityStatus.signedIn) {
          googleId = snapshot.accountId;
        }
      }

      if (googleId != null) {
        final sessionManager = ref.read(accountSessionManagerProvider);
        await sessionManager.activateGoogleAccount(googleId);
        await _completeAndProceed();
      } else {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        setState(() {
          _errorMessage = l10n.welcomeGoogleSelectFailed;
        });
      }
    } catch (e, st) {
      debugPrint('[WelcomeAuthScreen] Google Sign-In exception: $e\n$st');
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() => _errorMessage = l10n.welcomeGoogleInterrupted);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _continueWithEmail() async {
    if (_loading) return;
    final success = await SupabaseAuthDialog.show(context);
    if (success == true && mounted) {
      await _completeAndProceed();
    }
  }

  static const _startFreshChoice = '__start_fresh__';

  Future<void> _continueAsGuest() async {
    if (_loading) return;
    setState(() {
      _errorMessage = null;
    });

    try {
      final store = ref.read(accountLocalStoreProvider);
      final guests = await store.listGuestWorkspaces();

      if (guests.isEmpty) {
        // Case 1: No existing guest profiles -> Proceed straight to onboarding without popup.
        setState(() => _loading = true);
        final freshId = await store.startFreshGuestWorkspace();
        final sessionManager = ref.read(accountSessionManagerProvider);
        await sessionManager.activateLocalAccount(freshId);
        await _completeAndProceed();
        return;
      }

      // Case 2: One or more guest profiles exist -> Show selection bottom sheet.
      if (!mounted) return;
      final selectedChoice = await _showGuestProfileSelectionSheet(guests);
      if (!mounted || selectedChoice == null) return;

      setState(() => _loading = true);
      final sessionManager = ref.read(accountSessionManagerProvider);
      if (selectedChoice == _startFreshChoice) {
        final freshId = await store.startFreshGuestWorkspace();
        await sessionManager.activateLocalAccount(freshId);
      } else {
        await sessionManager.activateLocalAccount(selectedChoice);
      }
      await _completeAndProceed();
    } catch (e, st) {
      debugPrint('[WelcomeAuthScreen] Guest sign-in exception: $e\n$st');
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _showGuestProfileSelectionSheet(
    List<LocalAccount> guests,
  ) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.guestSelectionTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.guestSelectionSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.45,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: guests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final guest = guests[index];
                      final name = guestWorkspaceDisplayLabel(
                        guest,
                        guests,
                        fallbackName: l10n.accountGuest,
                      );
                      final isDraft =
                          guest.lifecycleState == AccountLifecycleState.draft;

                      return Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: theme.dividerColor.withAlpha(40),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: CircleAvatar(
                            backgroundColor:
                                theme.colorScheme.primary.withAlpha(30),
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            isDraft
                                ? l10n.guestSetupInProgress
                                : l10n.guestCreatedDate(
                                    MaterialLocalizations.of(context)
                                        .formatMediumDate(guest.createdAt),
                                  ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDraft
                                  ? theme.colorScheme.tertiary
                                  : isDark
                                      ? Colors.white60
                                      : Colors.black45,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                          ),
                          onTap: () =>
                              Navigator.pop(sheetContext, guest.localAccountId),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () =>
                      Navigator.pop(sheetContext, _startFreshChoice),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    l10n.guestCreateNewAction,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, null),
                  child: Text(l10n.commonCancel),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _completeAndProceed() async {
    final database = ref.read(appDatabaseProvider);
    await database.clearReturningAccountChoicePending();
    await database.markAccountChoiceComplete();
    ref.read(startupWorkspaceRestoreSatisfiedProvider.notifier).state = true;
    ref.invalidate(startupAccountWorkspaceRestoreProvider);
    ref.invalidate(returningAccountChoicePendingProvider);
    ref.invalidate(accountChoiceCompleteProvider);
    ref.invalidate(appRouteProvider);
    ref.invalidate(userProfileProvider);

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const StartupGate()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          key: const Key('welcome_theme_toggle_button'),
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
          tooltip: isDark ? l10n.settingsThemeLight : l10n.settingsThemeDark,
          onPressed: _loading
              ? null
              : () {
                  final next = isDark ? AppThemeMode.light : AppThemeMode.dark;
                  ref.read(themeModeProvider.notifier).set(next);
                },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: LanguageSelector<Locale>(
              key: const Key('welcome_language_selector'),
              options: AppLocalizations.supportedLocales
                  .map((loc) => LanguageOption<Locale>(
                        value: loc,
                        languageCode: loc.languageCode,
                        scriptCode: loc.scriptCode,
                      ))
                  .toList(growable: false),
              value: currentLocale,
              layout: LanguageSelectorLayout.compact,
              semanticLabel: l10n.profileLanguageTitle,
              enabled: !_loading,
              onChanged: (newLocale) {
                ref.read(localeProvider.notifier).set(newLocale);
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              children: [
                // 1. Branding Hero
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withAlpha(50),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Image.asset(
                      'assets/branding/qaza_namaz_logo.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.appTitle,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.welcomeHeadline,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Error message banner if any
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Option A: Google Sign-In
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    key: const Key('welcome_continue_google'),
                    onPressed: _loading ? null : _continueWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: Text(
                      l10n.authContinueWithGoogle,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Option B: Email Sign-In / Register
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    key: const Key('welcome_continue_email'),
                    onPressed: _loading ? null : _continueWithEmail,
                    icon: const Icon(Icons.email_outlined, size: 22),
                    label: Text(
                      l10n.welcomeContinueWithEmail,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Divider OR
                Row(
                  children: [
                    Expanded(child: Divider(color: theme.dividerColor)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        l10n.welcomeDividerOr,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: theme.dividerColor)),
                  ],
                ),
                const SizedBox(height: 18),

                // Option C: Continue as Guest
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    key: const Key('welcome_continue_guest'),
                    onPressed: _loading ? null : _continueAsGuest,
                    icon: const Icon(Icons.person_outline, size: 22),
                    label: Text(
                      l10n.authContinueAsGuest,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                if (_loading) ...[
                  const SizedBox(height: 24),
                  const Center(child: CircularProgressIndicator()),
                ],

                const SizedBox(height: 36),

                // Privacy Note Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 15,
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        l10n.welcomePrivacyNotice,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color:
                              theme.colorScheme.onSurfaceVariant.withAlpha(180),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
