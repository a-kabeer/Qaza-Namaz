import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/state_widgets.dart';
import '../../domain/entities/local_account.dart';
import '../../domain/services/profile_rules.dart';
import '../../core/time/local_date_service.dart';
import '../../l10n/app_localizations.dart';
import '../shell/workspace_shell.dart';
import 'account_choice_screen.dart';
import 'language_selection_screen.dart';
import 'profile_setup_screen.dart';
import 'splash_screen.dart';

class StartupGate extends ConsumerWidget {
  const StartupGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localeRestore = ref.watch(localeRestorationProvider);
    return localeRestore.when(
      loading: () => const SplashScreen(),
      error: (_, __) => StartupProfileLoadErrorBoundary(
        key: const Key('startup_locale_restore_error'),
        onRetry: () => ref.invalidate(localeRestorationProvider),
      ),
      data: (_) => _buildAfterLocaleRestore(ref),
    );
  }

  Widget _buildAfterLocaleRestore(WidgetRef ref) {
    final identityEnabled = ref.watch(googleIdentityProvider).isSupported;

    if (identityEnabled) {
      // A durable sign-out marker must take priority over session restoration.
      // The account-choice screen is the recovery destination after sign-out,
      // so don't keep it hidden behind a session initializer that may be slow
      // or stuck after process recreation.
      final returningChoice = ref.watch(returningAccountChoicePendingProvider);
      return returningChoice.when(
        loading: () => const SplashScreen(),
        error: (_, __) => StartupProfileLoadErrorBoundary(
          key: const Key('startup_returning_account_choice_error'),
          onRetry: () => ref.invalidate(returningAccountChoicePendingProvider),
        ),
        data: (required) {
          if (required) return const AccountChoiceScreen();
          return _buildAfterSessionRestore(ref, identityEnabled: true);
        },
      );
    }

    return _buildAfterSessionRestore(ref, identityEnabled: false);
  }

  Widget _buildAfterSessionRestore(
    WidgetRef ref, {
    required bool identityEnabled,
  }) {
    final session = ref.watch(accountSessionManagerProvider);

    if (session.state.phase == AccountSessionPhase.loading) {
      return const SplashScreen();
    }

    if (session.state.phase == AccountSessionPhase.error) {
      return StartupSessionErrorBoundary(
        message: session.state.message,
        onRetry: () => ref.read(accountSessionManagerProvider.notifier).retry(),
      );
    }

    if (identityEnabled) {
      final choice = ref.watch(accountChoiceCompleteProvider);
      return choice.when(
        loading: () => const SplashScreen(),
        error: (_, __) => StartupProfileLoadErrorBoundary(
          key: const Key('startup_cloud_setup_choice_error'),
          onRetry: () => ref.invalidate(accountChoiceCompleteProvider),
        ),
        data: (completed) => completed
            ? _restoredWorkspaceDestination(ref)
            : const AccountChoiceScreen(),
      );
    }

    return _profileDestination(ref, identityEnabled: false);
  }

  Widget _restoredWorkspaceDestination(WidgetRef ref) {
    final workspace = ref.watch(startupAccountWorkspaceRestoreProvider);
    return workspace.when(
      loading: () => const SplashScreen(),
      error: (_, __) => StartupProfileLoadErrorBoundary(
        key: const Key('startup_account_workspace_restore_error'),
        onRetry: () => ref.invalidate(startupAccountWorkspaceRestoreProvider),
      ),
      data: (_) => _profileDestination(ref, identityEnabled: true),
    );
  }

  Widget _profileDestination(
    WidgetRef ref, {
    required bool identityEnabled,
  }) {
    final routeAsync = ref.watch(appRouteProvider);
    return routeAsync.when(
      loading: () => const SplashScreen(),
      error: (_, __) => StartupProfileLoadErrorBoundary(
        key: const Key('startup_route_load_error'),
        onRetry: () => ref.invalidate(appRouteProvider),
      ),
      data: (route) {
        final profileAsync = ref.watch(userProfileProvider);
        return profileAsync.when(
          loading: () => const SplashScreen(),
          error: (_, __) => StartupProfileLoadErrorBoundary(
            key: const Key('startup_profile_load_error'),
            onRetry: () => ref.invalidate(userProfileProvider),
          ),
          data: (profile) {
            if (route == AppRoute.onboarding) {
              if (profile == null) {
                return identityEnabled
                    ? ProfileSetupScreen(
                        languageCode: ref.read(localeProvider).languageCode,
                      )
                    : const LanguageSelectionScreen();
              }
              return ProfileSetupScreen(
                languageCode: ref.read(localeProvider).languageCode,
                initialProfile: profile,
              );
            }

            if (profile == null) {
              return identityEnabled
                  ? ProfileSetupScreen(
                      languageCode: ref.read(localeProvider).languageCode,
                    )
                  : const LanguageSelectionScreen();
            }

            final validation = ProfileRules.validate(
              profile,
              today: LocalDateService.today(),
            );
            if (!profile.isComplete || !validation.isValid) {
              return ProfileSetupScreen(
                languageCode: ref.read(localeProvider).languageCode,
                initialProfile: profile,
              );
            }

            // Google identity selects a local workspace only. Home is never
            // gated by cloud authorization, backup, or synchronization.
            return const WorkspaceShell();
          },
        );
      },
    );
  }
}

class StartupSessionErrorBoundary extends StatelessWidget {
  const StartupSessionErrorBoundary({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: ErrorState(
          title: l10n.startupProfileLoadErrorTitle,
          message: message?.trim().isNotEmpty == true
              ? message!.trim()
              : l10n.startupProfileLoadErrorMessage,
          onRetry: onRetry,
          icon: Icons.storage_rounded,
        ),
      ),
    );
  }
}

class StartupProfileLoadErrorBoundary extends StatelessWidget {
  const StartupProfileLoadErrorBoundary({
    super.key,
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: ErrorState(
          title: l10n.startupProfileLoadErrorTitle,
          message: l10n.startupProfileLoadErrorMessage,
          onRetry: onRetry,
          icon: Icons.storage_rounded,
        ),
      ),
    );
  }
}
