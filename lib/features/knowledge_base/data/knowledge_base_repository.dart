import '../domain/knowledge_article.dart';
import '../domain/knowledge_category.dart';
import '../domain/knowledge_query.dart';

abstract interface class KnowledgeBaseRepository {
  /// Every published article, ordered by section then [KnowledgeArticle.sortOrder].
  Future<List<KnowledgeArticle>> getArticles();

  Future<List<KnowledgeArticle>> getArticlesByCategory(
      KnowledgeCategory category);

  Future<KnowledgeArticle?> getArticleById(String id);

  /// Free-text search combined with the section and topic filters.
  ///
  /// Querying lives here rather than in a provider so the matching rules are
  /// part of the data layer and cannot be restated differently by a caller.
  Future<List<KnowledgeArticle>> search(KnowledgeQuery query);

  /// The distinct `categoryId` values present in the content, in display
  /// order, so a filter never offers a topic that has no articles.
  Future<List<String>> getTopicIds();
}
