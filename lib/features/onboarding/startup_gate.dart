import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/local_account.dart';
import '../../domain/services/profile_rules.dart';
import '../shell/workspace_shell.dart';
import '../account/account_choice_screen.dart';
import 'language_selection_screen.dart';
import 'profile_setup_screen.dart';
import 'splash_screen.dart';

class StartupGate extends ConsumerWidget {
  const StartupGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      loading: () => const SplashScreen(),
      error: (_, __) => const LanguageSelectionScreen(),
      data: (profile) {
        if (profile == null) {
          final session = ref.watch(accountSessionManagerProvider);
          Future.microtask(session.initialize);
          if (session.state.phase == AccountSessionPhase.loading) {
            return const SplashScreen();
          }
          if (session.activeAccount == null && session.initialChoiceRequired) {
            return const AccountChoiceScreen();
          }
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
