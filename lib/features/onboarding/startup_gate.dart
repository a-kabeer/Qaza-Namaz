import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/time/local_date_service.dart';
import '../../core/widgets/state_widgets.dart';
import '../../data/auth/supabase_auth_service.dart';
import '../../domain/entities/local_account.dart';
import '../../domain/services/profile_rules.dart';
import '../../l10n/app_localizations.dart';
import '../shell/workspace_shell.dart';
import 'profile_setup_screen.dart';
import 'splash_screen.dart';
import 'welcome_auth_screen.dart';

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
    // A signed-in cloud user must never be blocked by a sign-out marker.
    final supabaseAuth = ref.watch(supabaseAuthServiceProvider);
    if (supabaseAuth.isSignedIn) {
      return _buildAfterSessionRestore(ref);
    }

    // A durable sign-out marker directs unauthenticated users to the welcome recovery screen.
    final returningChoice = ref.watch(returningAccountChoicePendingProvider);
    return returningChoice.when(
      loading: () => const SplashScreen(),
      error: (_, __) => StartupProfileLoadErrorBoundary(
        key: const Key('startup_returning_account_choice_error'),
        onRetry: () => ref.invalidate(returningAccountChoicePendingProvider),
      ),
      data: (required) {
        if (required) return const WelcomeAuthScreen();
        return _buildAfterSessionRestore(ref);
      },
    );
  }

  Widget _buildAfterSessionRestore(WidgetRef ref) {
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

    final choice = ref.watch(accountChoiceCompleteProvider);
    return choice.when(
      loading: () => const SplashScreen(),
      error: (_, __) => StartupProfileLoadErrorBoundary(
        key: const Key('startup_cloud_setup_choice_error'),
        onRetry: () => ref.invalidate(accountChoiceCompleteProvider),
      ),
      data: (completed) =>
          completed ? _profileDestination(ref) : const WelcomeAuthScreen(),
    );
  }

  Widget _profileDestination(WidgetRef ref) {
    final routeAsync = ref.watch(appRouteProvider);
    return routeAsync.when(
      skipLoadingOnReload: true,
      loading: () => const SplashScreen(),
      error: (_, __) => StartupProfileLoadErrorBoundary(
        key: const Key('startup_route_load_error'),
        onRetry: () => ref.invalidate(appRouteProvider),
      ),
      data: (route) {
        final profileAsync = ref.watch(userProfileProvider);
        return profileAsync.when(
          skipLoadingOnReload: true,
          loading: () => const SplashScreen(),
          error: (_, __) => StartupProfileLoadErrorBoundary(
            key: const Key('startup_profile_load_error'),
            onRetry: () => ref.invalidate(userProfileProvider),
          ),
          data: (profile) {
            if (profile != null && profile.isComplete) {
              final validation = ProfileRules.validate(
                profile,
                today: LocalDateService.today(),
              );
              if (validation.isValid) {
                // Ensure the database completion flag is kept synchronized
                if (route == AppRoute.onboarding) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref
                        .read(appDatabaseProvider)
                        .setOnboardingCompletedInTransaction(true);
                  });
                }
                return const WorkspaceShell();
              }
            }

            return ProfileSetupScreen(
              languageCode: ref.read(localeProvider).languageCode,
              initialProfile: profile,
            );
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
