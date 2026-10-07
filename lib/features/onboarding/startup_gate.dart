import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/state_widgets.dart';
import '../../domain/services/profile_rules.dart';
import '../../l10n/app_localizations.dart';
import '../shell/workspace_shell.dart';
import 'language_selection_screen.dart';
import 'profile_setup_screen.dart';
import 'splash_screen.dart';

class StartupGate extends ConsumerWidget {
  const StartupGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final profileAsync = ref.watch(userProfileProvider);
    return profileAsync.when(
      loading: () => const SplashScreen(),
      error: (_, __) => StartupProfileLoadErrorBoundary(
        key: const Key('startup_profile_load_error'),
        onRetry: () => ref.invalidate(userProfileProvider),
      ),
      data: (profile) {
        if (profile == null) {
          return const LanguageSelectionScreen();
        }

        final locale = LocaleNotifier.resolve(profile.languageCode);
        if (locale != null &&
            ref.read(localeProvider).languageCode != locale.languageCode) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              ref.read(localeProvider.notifier).set(locale);
            }
          });
        }

        final validation = ProfileRules.validate(
          profile,
          today: DateTime.now(),
        );
        if (!profile.isComplete || !validation.isValid) {
          return ProfileSetupScreen(
            languageCode: profile.languageCode,
            initialProfile: profile,
          );
        }

        return const WorkspaceShell();
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
