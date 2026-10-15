import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
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
/// Its height can grow when system text scaling makes Nastaliq or Arabic labels
/// taller than the compact default.
class KnowledgeLanguageBar extends StatelessWidget
    implements PreferredSizeWidget {
  const KnowledgeLanguageBar({
    super.key,
    this.height,
  }) : assert(height == null || height > 0);

  static const double _minimumHeight = 56;
  final double? height;

  static double heightFor(BuildContext context) {
    final typography = AppTypography.of(context);
    final scaler = MediaQuery.textScalerOf(context);

    double scaledLineBox(TextStyle? style) {
      final resolved = style ?? const TextStyle(fontSize: 14, height: 1.2);
      final size = resolved.fontSize ?? 14;
      return scaler.scale(size) * (resolved.height ?? 1.2) + 20;
    }

    return math.max(
      _minimumHeight,
      math.max(
        scaledLineBox(typography.urdu.labelLarge),
        math.max(
          scaledLineBox(typography.arabic.labelLarge),
          scaledLineBox(typography.latin.labelLarge),
        ),
      ),
    ).toDouble();
  }

  @override
  Size get preferredSize => Size.fromHeight(height ?? _minimumHeight);

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height ?? _minimumHeight,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: KnowledgeLanguageSwitcher(),
          ),
        ),
      );
}
