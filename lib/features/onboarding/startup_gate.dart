import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/state_widgets.dart';
import '../../domain/entities/local_account.dart';
import '../../domain/services/profile_rules.dart';
import '../../l10n/app_localizations.dart';
import '../shell/workspace_shell.dart';
import 'cloud_setup_choice_screen.dart';
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
    final session = ref.watch(accountSessionManagerProvider);

    if (session.state.phase == AccountSessionPhase.loading) {
      return const SplashScreen();
    }

    if (session.state.phase == AccountSessionPhase.error) {
      return StartupSessionErrorBoundary(
        message: session.state.message,
        onRetry: () =>
            ref.read(accountSessionManagerProvider.notifier).initialize(),
      );
    }

    final cloudEnabled = ref.watch(cloudAccountProvider).isSupported &&
        ref.watch(cloudSyncProvider).isSupported;

    if (cloudEnabled) {
      final choice = ref.watch(cloudSetupChoiceCompleteProvider);
      return choice.when(
        loading: () => const SplashScreen(),
        error: (_, __) => StartupProfileLoadErrorBoundary(
          key: const Key('startup_cloud_setup_choice_error'),
          onRetry: () => ref.invalidate(cloudSetupChoiceCompleteProvider),
        ),
        data: (completed) => completed
            ? _profileDestination(ref, cloudEnabled: true)
            : const CloudSetupChoiceScreen(),
      );
    }

    return _profileDestination(ref, cloudEnabled: false);
  }

  Widget _profileDestination(
    WidgetRef ref, {
    required bool cloudEnabled,
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
                return cloudEnabled
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
              return cloudEnabled
                  ? ProfileSetupScreen(
                      languageCode: ref.read(localeProvider).languageCode,
                    )
                  : const LanguageSelectionScreen();
            }

            final validation = ProfileRules.validate(
              profile,
              today: DateTime.now(),
            );
            if (!profile.isComplete || !validation.isValid) {
              return ProfileSetupScreen(
                languageCode: ref.read(localeProvider).languageCode,
                initialProfile: profile,
              );
            }

            if (cloudEnabled) {
              // Restore the saved cloud session before entering the workspace.
              // The gateway serializes restoration with interactive auth.
              final restoration = ref.watch(cloudAccountStartupRestoreProvider);
              return restoration.when(
                loading: () => const SplashScreen(),
                error: (_, __) => const WorkspaceShell(),
                data: (_) => const WorkspaceShell(),
              );
            }

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
          message: message ?? l10n.startupProfileLoadErrorMessage,
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
