import 'dart:math' as math;

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
            label: Text(
              'اردو',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: typography.urdu.labelLarge,
            ),
          ),
          ButtonSegment<KnowledgeLanguage>(
            value: KnowledgeLanguage.english,
            label: Text(
              'English',
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: typography.latin.labelLarge,
            ),
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
  const KnowledgeLanguageBar({
    super.key,
    required this.height,
  }) : assert(height > 0);

  static const double _minimumHeight = 56;

  final double height;

  /// Keeps the pinned control tall enough for the larger script's actual
  /// scaled line metrics instead of clipping when system text is enlarged.
  static double heightFor(BuildContext context) {
    final typography = AppTypography.of(context);
    final scaler = MediaQuery.textScalerOf(context);

    double scaledLineBox(TextStyle style) {
      final size = style.fontSize ?? 14;
      return scaler.scale(size) * (style.height ?? 1.2) + 20;
    }

    return math.max(
      _minimumHeight,
      math.max(
        scaledLineBox(typography.urdu.labelLarge!),
        scaledLineBox(typography.latin.labelLarge!),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: KnowledgeLanguageSwitcher(),
          ),
        ),
      );
}
