import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
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
    final typography = AppTypography.of(context);

    return Semantics(
      label: l10n.knowledgeBaseLanguage,
      child: SegmentedButton<KnowledgeLanguage>(
        key: const Key('knowledge_language_switcher'),
        showSelectedIcon: false,
        segments: [
          // Urdu leads, as the content's first language. In an Urdu interface
          // the row mirrors, which is the correct reading order there.
          ButtonSegment<KnowledgeLanguage>(
            value: KnowledgeLanguage.urdu,
            label: Text('اردو', style: typography.urdu.labelLarge),
          ),
          const ButtonSegment<KnowledgeLanguage>(
            value: KnowledgeLanguage.english,
            label: Text('English'),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (selection) =>
            ref.read(knowledgeLanguageProvider.notifier).set(selection.single),
      ),
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
