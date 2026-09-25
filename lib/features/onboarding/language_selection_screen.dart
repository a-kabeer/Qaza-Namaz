import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/user_profile.dart';
import '../../l10n/app_localizations.dart';
import '../auth/authentication_screen.dart';
import '../auth/guest_upgrade_controller.dart';
import 'profile_setup_screen.dart';
import 'startup_gate.dart';

class LanguageSelectionScreen extends ConsumerWidget {
  const LanguageSelectionScreen({super.key});

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    Locale locale,
  ) async {
    ref.read(localeProvider.notifier).set(locale);
    await ref.read(userProfileRepositoryProvider).save(
          UserProfile(
            languageCode: locale.languageCode,
            onboardingCompleted: false,
          ),
        );
    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileSetupScreen(languageCode: locale.languageCode),
      ),
    );
  }

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(guestUpgradeControllerProvider.notifier);
    final ok = await controller.signInAndMigrate(
      origin: GuestUpgradeOrigin.startup,
    );
    if (!context.mounted) return;

    final state = ref.read(guestUpgradeControllerProvider);
    if (!ok) return;

    if (state.pendingAccount != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const AuthenticationScreen(closeWhenDecided: true),
        ),
      );
      return;
    }

    // Existing accounts go straight to Home. Newly-created accounts carry a
    // UID-scoped pending marker so StartupGate sends them through the normal
    // profile/Qaza setup instead of treating them as an established account.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const StartupGate()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(localeProvider);
    final authState = ref.watch(guestUpgradeControllerProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final urdu = current.languageCode == 'ur';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
              children: [
                Icon(
                  Icons.language_rounded,
                  size: 56,
                  color: scheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.profileLanguageTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.profileLanguageIntro,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                for (final locale in AppLocalizations.supportedLocales)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ChoiceChip(
                      key: Key(
                        'onboarding_language_${locale.languageCode}',
                      ),
                      label: Text(
                        locale.languageCode == 'ur'
                            ? l10n.languageUrdu
                            : l10n.languageEnglish,
                      ),
                      selected:
                          locale.languageCode == current.languageCode,
                      onSelected: authState.running
                          ? null
                          : (_) => _select(context, ref, locale),
                    ),
                  ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 18),
                Text(
                  urdu
                      ? 'پہلے سے اکاؤنٹ موجود ہے؟'
                      : 'Already have an account?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    key: const Key('onboarding_sign_in_google'),
                    onPressed: authState.running
                        ? null
                        : () => _signIn(context, ref),
                    icon: authState.running
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.g_mobiledata_rounded),
                    label: Text(
                      authState.running
                          ? (urdu ? 'سائن اِن ہو رہا ہے…' : 'Signing in…')
                          : (urdu
                              ? 'گوگل کے ساتھ سائن اِن کریں'
                              : 'Sign in with Google'),
                    ),
                  ),
                ),
                if (authState.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    authState.error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
