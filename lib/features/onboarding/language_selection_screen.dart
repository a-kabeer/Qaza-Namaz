import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/language_selector.dart';

import '../../app/providers.dart';
import '../../domain/entities/user_profile.dart';
import '../../l10n/app_localizations.dart';
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
      await ref.read(userProfileRepositoryProvider).save(
            UserProfile(
              languageCode: locale.languageCode,
              onboardingCompleted: false,
            ),
          );

      // Persist the confirmed locale only after the profile save succeeds.
      await ref.read(localeProvider.notifier).set(locale);

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ProfileSetupScreen(
            languageCode: locale.languageCode,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).errorStorage),
          ),
        );
      }
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: LanguageSelector<Locale>(
                          key: const Key('onboarding_language_selector'),
                          options: AppLocalizations.supportedLocales
                              .map(
                                (locale) => LanguageOption<Locale>(
                                  value: locale,
                                  languageCode: locale.languageCode,
                                ),
                              )
                              .toList(growable: false),
                          value: _selectedLocale,
                          layout: LanguageSelectorLayout.fullWidth,
                          semanticLabel: l10n.profileLanguageTitle,
                          optionKeyPrefix: 'onboarding_language',
                          enabled: !_isContinuing,
                          onChanged: _select,
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
