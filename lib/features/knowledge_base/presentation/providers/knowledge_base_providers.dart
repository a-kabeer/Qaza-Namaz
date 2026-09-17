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

final knowledgeFilteredArticlesProvider =
    Provider<AsyncValue<List<KnowledgeArticle>>>((ref) {
  final articles = ref.watch(knowledgeArticlesProvider);
  final category = ref.watch(knowledgeCategoryFilterProvider);
  final query = ref.watch(knowledgeSearchQueryProvider).trim().toLowerCase();

  return articles.whenData((items) {
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
  });
});

final knowledgeArticleProvider =
    FutureProvider.family<KnowledgeArticle?, String>((ref, id) {
  return ref.watch(knowledgeBaseRepositoryProvider).getArticleById(id);
});

final selectedKnowledgeArticleProvider =
    Provider<AsyncValue<KnowledgeArticle?>>((ref) {
  final id = ref.watch(knowledgeSelectedArticleIdProvider);
  if (id == null || id.trim().isEmpty) {
    return const AsyncValue.data(null);
  }
  return ref.watch(knowledgeArticleProvider(id));
});

final knowledgeRelatedArticlesProvider =
    Provider.family<AsyncValue<List<KnowledgeArticle>>, String>((ref, id) {
  final articles = ref.watch(knowledgeArticlesProvider);
  return articles.whenData((items) {
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
