import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/user_profile.dart';
import '../../l10n/app_localizations.dart';
import 'previous_qaza_choice_screen.dart';
import 'profile_setup_screen.dart';

class LanguageSelectionScreen extends ConsumerStatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  ConsumerState<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState
    extends ConsumerState<LanguageSelectionScreen> {
  late Locale _selectedLocale;
  bool _isContinuing = false;

  @override
  void initState() {
    super.initState();
    _selectedLocale = ref.read(localeProvider);
  }

  void _select(Locale locale) {
    if (_isContinuing) return;
    setState(() => _selectedLocale = locale);
    ref.read(localeProvider.notifier).preview(locale);
  }

  Future<void> _continue() async {
    if (_isContinuing) return;

    setState(() => _isContinuing = true);
    final locale = _selectedLocale;

    try {
      ref.read(localeProvider.notifier).set(locale);
      await ref.read(userProfileRepositoryProvider).save(
            UserProfile(
              languageCode: locale.languageCode,
              onboardingCompleted: false,
            ),
          );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PreviousQazaChoiceScreen(
            languageCode: locale.languageCode,
            nextScreenBuilder: (choice) => ProfileSetupScreen(
              languageCode: locale.languageCode,
              previousQazaChoice: choice,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isContinuing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
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
                            selected: locale.languageCode ==
                                _selectedLocale.languageCode,
                            onSelected: (selected) {
                              if (selected) _select(locale);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isContinuing ? null : _continue,
                      child: _isContinuing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : Text(l10n.commonContinue),
                    ),
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
