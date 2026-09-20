import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../l10n/app_localizations.dart';
import '../../../l10n/prayer_type_l10n.dart';
import '../domain/knowledge_category.dart';
import 'providers/knowledge_base_providers.dart';
import 'widgets/knowledge_language_switcher.dart';

/// One article, rendered in the Knowledge Base reading language.
///
/// The language is not page state: it comes from the same provider the list
/// uses, so opening an article never resets what the reader chose.
class KnowledgeArticleDetailPage extends ConsumerWidget {
  const KnowledgeArticleDetailPage({
    super.key,
    required this.articleId,
  });

  final String articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articleAsync = ref.watch(knowledgeArticleProvider(articleId));
    final relatedAsync = ref.watch(
      knowledgeRelatedArticlesProvider(articleId),
    );
    final language = ref.watch(knowledgeLanguageProvider);
    final showUrdu = language.isUrdu;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).knowledgeArticleTitle),
        bottom: const KnowledgeLanguageBar(),
      ),
      body: articleAsync.when(
        loading: () => const _KnowledgeArticleSkeleton(),
        error: (error, _) => _DetailErrorState(
          onRetry: () => ref.invalidate(
            knowledgeArticleProvider(articleId),
          ),
        ),
        data: (article) {
          if (article == null) {
            return const _MissingArticleState();
          }

          final title = showUrdu ? article.title.ur : article.title.en;
          final body = showUrdu ? article.body.ur : article.body.en;
          final direction = language.direction;
          final textAlign = language.textAlign;
          // The article's language is independent of the interface language,
          // so the scale is chosen from the content rather than the locale.
          final typography = AppTypography.of(context);
          final type = typography.forScript(urduScript: showUrdu);

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        textDirection: direction,
                        textAlign: textAlign,
                        style: type.headlineSmall,
                      ),
                      const SizedBox(height: 20),
                      _CategoryBadge(
                          category: article.category, topicId: article.topicId),
                      const SizedBox(height: 20),
                      SelectableText(
                        body,
                        textDirection: direction,
                        textAlign: textAlign,
                        style: typography.readingBody(urduScript: showUrdu),
                      ),
                      if (article.references.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Text(
                          AppLocalizations.of(context)
                              .knowledgeArticleReferences,
                          textDirection: direction,
                          textAlign: textAlign,
                          style: type.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        ...article.references.map(
                          (reference) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.menu_book_outlined),
                              title: Text(reference.bookName),
                              subtitle: Text(
                                  '${reference.author} • ${reference.sourceName}'),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
                sliver: relatedAsync.when(
                  loading: () => SliverList.builder(
                    itemCount: 3,
                    itemBuilder: (_, __) => const _RelatedArticleSkeleton(),
                  ),
                  error: (error, _) => const SliverToBoxAdapter(
                    child: SizedBox.shrink(),
                  ),
                  data: (related) {
                    if (related.isEmpty) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                    return SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Text(
                            AppLocalizations.of(context)
                                .knowledgeArticleRelated,
                            textDirection: direction,
                            textAlign: textAlign,
                            style: type.titleLarge,
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                        SliverList.builder(
                          itemCount: related.length,
                          itemBuilder: (context, index) {
                            final relatedArticle = related[index];
                            final relatedTitle = showUrdu
                                ? relatedArticle.title.ur
                                : relatedArticle.title.en;
                            return Semantics(
                              button: true,
                              label: relatedTitle,
                              child: Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  title: Text(
                                    relatedTitle,
                                    textDirection: direction,
                                    textAlign: textAlign,
                                    style: type.bodyLarge,
                                  ),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () =>
                                      Navigator.of(context).pushReplacement(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          KnowledgeArticleDetailPage(
                                        articleId: relatedArticle.id,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KnowledgeArticleSkeleton extends StatelessWidget {
  const _KnowledgeArticleSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SkeletonText(width: 260, height: 28),
                const SizedBox(height: 22),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SkeletonBox(width: 94, height: 32,
                        borderRadius: BorderRadius.all(Radius.circular(999))),
                    SkeletonBox(width: 120, height: 32,
                        borderRadius: BorderRadius.all(Radius.circular(999))),
                  ],
                ),
                const SizedBox(height: 22),
                for (var i = 0; i < 11; i++) ...[
                  const SkeletonText(width: double.infinity, height: 13),
                  const SizedBox(height: 9),
                ],
              ],
            ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 28, 16, 8),
          sliver: SliverToBoxAdapter(
            child: SkeletonText(width: 180, height: 22),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList.builder(
            itemCount: 3,
            itemBuilder: (_, __) => const _RelatedArticleSkeleton(),
          ),
        ),
      ],
    );
  }
}

class _RelatedArticleSkeleton extends StatelessWidget {
  const _RelatedArticleSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: SkeletonCircle(size: 40),
        title: Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: SkeletonText(width: 190, height: 16),
        ),
        trailing: SkeletonBox(
          width: 20,
          height: 20,
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
      ),
    );
  }
}

class _CategoryBadge extends ConsumerWidget {
  const _CategoryBadge({required this.category, required this.topicId});

  final KnowledgeCategory category;
  final String topicId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The section and topic name the content, so they follow the article's
    // language rather than the interface language.
    final l10n = ref.watch(knowledgeLocalizationsProvider);
    final section = switch (category) {
      KnowledgeCategory.masail => l10n.knowledgeCategoryMasail,
      KnowledgeCategory.mugalat => l10n.knowledgeCategoryMugalat,
    };
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          Chip(
            avatar: const Icon(Icons.category_outlined, size: 18),
            label: Text(section),
          ),
          Chip(label: Text(localizedKnowledgeTopic(topicId, l10n))),
        ],
      ),
    );
  }
}

class _MissingArticleState extends StatelessWidget {
  const _MissingArticleState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(AppLocalizations.of(context).knowledgeArticleNotFound),
        ),
      );
}

class _DetailErrorState extends StatelessWidget {
  const _DetailErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(AppLocalizations.of(context).commonRetry),
        ),
      );
}
