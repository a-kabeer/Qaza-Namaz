import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/bundled_knowledge_base_repository.dart';
import '../../data/knowledge_base_repository.dart';
import '../../domain/knowledge_article.dart';
import '../../domain/knowledge_category.dart';

final knowledgeBaseRepositoryProvider = Provider<KnowledgeBaseRepository>(
  (ref) => BundledKnowledgeBaseRepository(),
);

final knowledgeBaseCategoriesProvider = Provider<List<KnowledgeCategory>>(
  (ref) => List.unmodifiable(KnowledgeCategory.values),
);

final knowledgeArticlesProvider = FutureProvider<List<KnowledgeArticle>>(
  (ref) => ref.watch(knowledgeBaseRepositoryProvider).getArticles(),
);

final knowledgeCategoryFilterProvider = StateProvider<KnowledgeCategory?>(
  (ref) => null,
);

final knowledgeSearchQueryProvider = StateProvider<String>(
  (ref) => '',
);

final knowledgeSelectedArticleIdProvider = StateProvider<String?>(
  (ref) => null,
);

final knowledgeFilteredArticlesProvider = FutureProvider<List<KnowledgeArticle>>(
  (ref) async {
    final items = await ref.watch(knowledgeArticlesProvider.future);
    final category = ref.watch(knowledgeCategoryFilterProvider);
    final query = ref.watch(knowledgeSearchQueryProvider).trim().toLowerCase();

    final filtered = items.where((article) {
      if (category != null && article.category != category) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return _matchesQuery(article, query);
    });

    return List.unmodifiable(filtered);
  },
);

final knowledgeArticleProvider =
    FutureProvider.family<KnowledgeArticle?, String>((ref, id) {
  return ref.watch(knowledgeBaseRepositoryProvider).getArticleById(id);
});

final selectedKnowledgeArticleProvider =
    FutureProvider<KnowledgeArticle?>((ref) async {
  final id = ref.watch(knowledgeSelectedArticleIdProvider);
  if (id == null || id.trim().isEmpty) {
    return null;
  }
  return ref.watch(knowledgeArticleProvider(id).future);
});

final knowledgeRelatedArticlesProvider =
    FutureProvider.family<List<KnowledgeArticle>, String>((ref, id) async {
  final items = await ref.watch(knowledgeArticlesProvider.future);
  final byId = <String, KnowledgeArticle>{
    for (final article in items) article.id: article,
  };

  final related = <KnowledgeArticle>[];
  for (final relatedId in byId[id]?.relatedArticleIds ?? const <String>[]) {
    final article = byId[relatedId];
    if (article != null && article.id != id) {
      related.add(article);
    }
  }
  return List.unmodifiable(related);
});

bool _matchesQuery(KnowledgeArticle article, String query) {
  final searchableText = <String>[
    article.id,
    article.slug,
    article.title.en,
    article.title.ur,
    article.summary.en,
    article.summary.ur,
    article.body.en,
    article.body.ur,
    ...article.tags,
  ].join(' ').toLowerCase();

  return searchableText.contains(query);
}
