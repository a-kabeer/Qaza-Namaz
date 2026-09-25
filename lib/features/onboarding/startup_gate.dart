
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
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