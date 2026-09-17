import '../domain/knowledge_article.dart';
import '../domain/knowledge_category.dart';

abstract interface class KnowledgeBaseRepository {
  Future<List<KnowledgeArticle>> getArticles();

  Future<List<KnowledgeArticle>> getArticlesByCategory(KnowledgeCategory category);

  Future<KnowledgeArticle?> getArticleById(String id);
}
