import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../../../l10n/prayer_type_l10n.dart';
import '../domain/knowledge_article.dart';
import '../domain/knowledge_category.dart';
import 'knowledge_article_detail_page.dart';
import 'providers/knowledge_base_providers.dart';

class KnowledgeBasePage extends ConsumerStatefulWidget {
  const KnowledgeBasePage({super.key});

  @override
  ConsumerState<KnowledgeBasePage> createState() => _KnowledgeBasePageState();
}

class _KnowledgeBasePageState extends ConsumerState<KnowledgeBasePage> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final articles = ref.watch(knowledgeFilteredArticlesProvider);
    final selectedCategory = ref.watch(knowledgeCategoryFilterProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.knowledgeBaseTitle)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(knowledgeArticlesProvider),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onChanged: (value) {
                    ref.read(knowledgeSearchQueryProvider.notifier).state =
                        value;
                    setState(() {});
                  },
                  decoration: InputDecoration(
                    hintText: l10n.knowledgeBaseSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: l10n.knowledgeBaseClearSearch,
                            onPressed: () {
                              _searchController.clear();
                              ref
                                  .read(knowledgeSearchQueryProvider.notifier)
                                  .state = '';
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  scrollDirection: Axis.horizontal,
                  children: [
                    ChoiceChip(
                      label: Text(l10n.filterAll),
                      selected: selectedCategory == null,
                      onSelected: (_) => ref
                          .read(knowledgeCategoryFilterProvider.notifier)
                          .state = null,
                    ),
                    const SizedBox(width: 8),
                    ...KnowledgeCategory.values.map(
                      (category) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(category.localizedLabel(l10n)),
                          selected: selectedCategory == category,
                          onSelected: (_) => ref
                              .read(knowledgeCategoryFilterProvider.notifier)
                              .state = category,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            articles.when(
              data: (items) => items.isEmpty
                  ? const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyKnowledgeState(),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      sliver: SliverList.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) => _ArticleCard(
                          article: items[index],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => KnowledgeArticleDetailPage(
                                articleId: items[index].id,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorKnowledgeState(
                  onRetry: () => ref.invalidate(knowledgeArticlesProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article, required this.onTap});

  final KnowledgeArticle article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Semantics(
        button: true,
        label: '${article.title.en}. ${article.summary.en}',
        child: Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title.en,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    article.title.ur,
                    textDirection: TextDirection.rtl,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article.summary.en,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    article.category
                        .localizedLabel(AppLocalizations.of(context)),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyKnowledgeState extends StatelessWidget {
  const _EmptyKnowledgeState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).knowledgeBaseEmptyTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(AppLocalizations.of(context).knowledgeBaseEmptyMessage),
            ],
          ),
        ),
      );
}

class _ErrorKnowledgeState extends StatelessWidget {
  const _ErrorKnowledgeState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).knowledgeBaseLoadError,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context).commonRetry),
              ),
            ],
          ),
        ),
      );
}
