import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/language_selector.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/knowledge_language.dart';
import '../providers/knowledge_base_providers.dart';

/// The Knowledge Base reading-language control.
///
/// One control, one piece of state: the list and every article read the same
/// provider, so a choice made anywhere holds everywhere and survives a
/// restart. It changes Knowledge Base content only — the interface language
/// stays with Settings -> Language.
class KnowledgeLanguageSwitcher extends ConsumerWidget {
  const KnowledgeLanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(knowledgeLanguageProvider);
    // This model lists only languages with a bundled, validated content file.
    // Do not derive Knowledge options from application UI locales.
    return LanguageSelector<KnowledgeLanguage>(
      key: const Key('knowledge_language_switcher'),
      options: KnowledgeLanguage.values
          .map(
            (language) => LanguageOption<KnowledgeLanguage>(
              value: language,
              languageCode: language.code,
            ),
          )
          .toList(growable: false),
      value: selected,
      layout: LanguageSelectorLayout.compact,
      semanticLabel: l10n.knowledgeBaseLanguage,
      optionKeyPrefix: 'knowledge_language_option',
      onChanged: (language) {
        ref.read(knowledgeLanguageProvider.notifier).set(language);
      },
    );
  }
}

/// The switcher pinned under an app bar, so it stays put while content scrolls.
///
/// Used by both Knowledge Base screens so the control never moves between the
/// list and an article.
class KnowledgeLanguageBar extends StatelessWidget
    implements PreferredSizeWidget {
  const KnowledgeLanguageBar({super.key});

  static const double _height = 56;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: _height,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: KnowledgeLanguageSwitcher(),
          ),
        ),
      );
}
