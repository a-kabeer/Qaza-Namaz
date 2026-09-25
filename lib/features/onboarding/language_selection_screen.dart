
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/user_profile.dart';
import '../../l10n/app_localizations.dart';
import 'profile_setup_screen.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final current = ref.watch(localeProvider);
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
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.profileLanguageTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.profileLanguageIntro,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                for (final locale in AppLocalizations.supportedLocales)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: ChoiceChip(
                      key: Key(
                        'onboarding_language_' + locale.languageCode,
                      ),
                      label: Text(
                        locale.languageCode == 'ur'
                            ? l10n.languageUrdu
                            : l10n.languageEnglish,
                      ),
                      selected:
                          locale.languageCode == current.languageCode,
                      onSelected: (_) => _select(context, ref, locale),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
