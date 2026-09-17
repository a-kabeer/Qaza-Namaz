import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/knowledge_article.dart';
import '../domain/knowledge_category.dart';
import 'providers/knowledge_base_providers.dart';

class KnowledgeArticleDetailPage extends ConsumerStatefulWidget {
  const KnowledgeArticleDetailPage({
    super.key,
    required this.articleId,
  });

  final String articleId;

  @override
  ConsumerState<KnowledgeArticleDetailPage> createState() =>
      _KnowledgeArticleDetailPageState();
}

class _KnowledgeArticleDetailPageState
    extends ConsumerState<KnowledgeArticleDetailPage> {
  bool _showUrdu = false;

  @override
  Widget build(BuildContext context) {
    final articleAsync = ref.watch(knowledgeArticleProvider(widget.articleId));
    final relatedAsync = ref.watch(
      knowledgeRelatedArticlesProvider(widget.articleId),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Article')),
      body: articleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _DetailErrorState(
          onRetry: () => ref.invalidate(knowledgeArticleProvider(widget.articleId)),
        ),
        data: (article) {
          if (article == null) {
            return const _MissingArticleState();
          }

          final title = _showUrdu ? article.title.ur : article.title.en;
          final body = _showUrdu ? article.body.ur : article.body.en;
          final summary = _showUrdu ? article.summary.ur : article.summary.en;
          final direction = _showUrdu ? TextDirection.rtl : TextDirection.ltr;

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(
                            value: false,
                            icon: Icon(Icons.language),
                            label: Text('English'),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            label: Text('اردو'),
                          ),
                        ],
                        selected: {_showUrdu},
                        onSelectionChanged: (selection) => setState(() {
                          _showUrdu = selection.single;
                        }),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        title,
                        textDirection: direction,
                        textAlign: _showUrdu ? TextAlign.right : TextAlign.left,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        summary,
                        textDirection: direction,
                        textAlign: _showUrdu ? TextAlign.right : TextAlign.left,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      _CategoryBadge(category: article.category),
                      const SizedBox(height: 20),
                      Text(
                        body,
                        textDirection: direction,
                        textAlign: _showUrdu ? TextAlign.right : TextAlign.left,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              height: 1.7,
                            ),
                      ),
                      if (article.references.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Text(
                          _showUrdu ? 'حوالہ جات' : 'References',
                          textDirection: direction,
                          textAlign: _showUrdu ? TextAlign.right : TextAlign.left,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        ...article.references.map(
                          (reference) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.menu_book_outlined),
                              title: Text(reference.source),
                              subtitle: reference.citation == null
                                  ? null
                                  : Text(reference.citation!),
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
                  loading: () => const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                  data: (related) {
                    if (related.isEmpty) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                    return SliverMainAxisGroup(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Text(
                            _showUrdu ? 'متعلقہ مضامین' : 'Related articles',
                            textDirection: direction,
                            textAlign: _showUrdu ? TextAlign.right : TextAlign.left,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                        SliverList.builder(
                          itemCount: related.length,
                          itemBuilder: (context, index) {
                            final relatedArticle = related[index];
                            final relatedTitle = _showUrdu
                                ? relatedArticle.title.ur
                                : relatedArticle.title.en;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(
                                  relatedTitle,
                                  textDirection: direction,
                                  textAlign: _showUrdu
                                      ? TextAlign.right
                                      : TextAlign.left,
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.of(context).pushReplacement(
                                  MaterialPageRoute<void>(
                                    builder: (_) => KnowledgeArticleDetailPage(
                                      articleId: relatedArticle.id,
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

class _CategoryBadge extends StatelessWidget {
  const _CategoryBadge({required this.category});

  final KnowledgeCategory category;

  @override
  Widget build(BuildContext context) {
    final label = switch (category) {
      KnowledgeCategory.masail => 'Masail',
      KnowledgeCategory.mugalat => 'Mugalat',
    };
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Chip(
        avatar: const Icon(Icons.category_outlined, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _MissingArticleState extends StatelessWidget {
  const _MissingArticleState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Article not found.'),
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
          label: const Text('Retry'),
        ),
      );
}
