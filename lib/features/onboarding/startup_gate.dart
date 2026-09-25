
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../auth/auth_startup_state.dart';
import '../auth/authentication_screen.dart';
import '../auth/guest_upgrade_controller.dart';
import '../../domain/services/profile_rules.dart';
import '../prayer_times/presentation/prayer_times_setup_prompt.dart';
import '../settings/app_lock_gate.dart';
import '../shell/workspace_shell.dart';
import 'language_selection_screen.dart';
import 'profile_setup_screen.dart';
import 'splash_screen.dart';

class StartupGate extends ConsumerWidget {
  const StartupGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    return authAsync.when(
      loading: () => const SplashScreen(),
      error: (_, __) => _buildSignedOut(context, ref),
      data: (user) {
        if (user == null) return _buildSignedOut(context, ref);

        final upgrade = ref.watch(guestUpgradeControllerProvider);
        if (upgrade.restoring || upgrade.running) {
          // Do not decide the destination from the transient Firebase auth
          // emission. Google sign-in can update authState before the startup
          // controller has recorded whether the account is new or established.
          return const SplashScreen();
        }
        if (upgrade.awaitingDecision) {
          return const AuthenticationScreen(closeWhenDecided: true);
        }

        if (upgrade.newAccount) {
          final profile = ref.watch(userProfileProvider).valueOrNull;
          final languageCode =
              profile?.languageCode ?? ref.read(localeProvider).languageCode;
          return ProfileSetupScreen(
            languageCode: languageCode,
            initialProfile: profile,
          );
        }

        final pendingOnboarding =
            ref.watch(pendingNewGoogleUserProvider(user.id));

        return pendingOnboarding.when(
          loading: () => const SplashScreen(),
          error: (_, __) => const AppLockGate(
            child: PrayerTimesSetupPromptGate(child: WorkspaceShell()),
          ),
          data: (isPending) {
            if (!isPending) {
              // An authenticated established account is authoritative at
              // startup. Do not let an old/incomplete local guest profile
              // strand the user on onboarding.
              return const AppLockGate(
                child: PrayerTimesSetupPromptGate(child: WorkspaceShell()),
              );
            }

            final profile = ref.watch(userProfileProvider).valueOrNull;
            final languageCode = profile?.languageCode ??
                ref.read(localeProvider).languageCode;
            return ProfileSetupScreen(
              languageCode: languageCode,
              initialProfile: profile,
            );
          },
        );
      },
    );
  }

  Widget _buildSignedOut(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    return profileAsync.when(
      loading: () => const SplashScreen(),
      error: (_, __) => const LanguageSelectionScreen(),
      data: (profile) {
        if (profile == null) return const LanguageSelectionScreen();

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

        return const AppLockGate(
          child: PrayerTimesSetupPromptGate(child: WorkspaceShell()),
        );
      },
    );
  }
}