import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/services/profile_rules.dart';
import '../account/account_choice_screen.dart';
import '../shell/workspace_shell.dart';
import 'language_selection_screen.dart';
import 'profile_setup_screen.dart';
import 'splash_screen.dart';

class StartupGate extends ConsumerWidget {
  const StartupGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(accountSessionManagerProvider);

    // Startup initialization is owned by the app lifecycle, never by build.
    // The static splash is shown only while required local/session state is
    // being prepared.
    if (session.state.phase == AccountSessionPhase.loading ||
        session.state.phase == AccountSessionPhase.connecting) {
      return const SplashScreen();
    }

    final activeAccount = session.activeAccount;
    if (activeAccount == null && session.initialChoiceRequired) {
      return const AccountChoiceScreen();
    }

    if (activeAccount == null) {
      // An unexpected local session failure must not fabricate an account or
      // expose account-scoped repositories. Keep the user at the safe
      // account-selection boundary.
      return const AccountChoiceScreen();
    }

    final profileAsync = ref.watch(userProfileProvider);
    return profileAsync.when(
      loading: () => const SplashScreen(),
      error: (_, __) => const LanguageSelectionScreen(),
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
