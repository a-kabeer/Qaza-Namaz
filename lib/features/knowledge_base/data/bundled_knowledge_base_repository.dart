import 'package:flutter/services.dart';

import '../domain/knowledge_article.dart';
import '../domain/knowledge_category.dart';
import 'knowledge_base_parser.dart';
import 'knowledge_base_repository.dart';

class BundledKnowledgeBaseRepository implements KnowledgeBaseRepository {
  BundledKnowledgeBaseRepository({
    KnowledgeBaseParser parser = const KnowledgeBaseParser(),
    AssetBundle? bundle,
  })  : _parser = parser,
        _bundle = bundle;

  static const String assetPath = 'assets/knowledge_base/content/articles.json';

  final KnowledgeBaseParser _parser;
  final AssetBundle? _bundle;
  List<KnowledgeArticle>? _cache;

  @override
  Future<List<KnowledgeArticle>> getArticles() async {
    final cached = _cache;
    if (cached != null) {
      return List.unmodifiable(cached);
    }

    final raw = await (_bundle ?? rootBundle).loadString(assetPath);
    final articles = _parser.parse(raw, source: assetPath)
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        return order != 0 ? order : a.id.compareTo(b.id);
      });

    _cache = List.unmodifiable(articles);
    return List.unmodifiable(articles);
  }

  @override
  Future<List<KnowledgeArticle>> getArticlesByCategory(
    KnowledgeCategory category,
  ) async {
    final articles = await getArticles();
    return List.unmodifiable(
      articles.where((article) => article.category == category),
    );
  }

  @override
  Future<KnowledgeArticle?> getArticleById(String id) async {
    final articles = await getArticles();
    for (final article in articles) {
      if (article.id == id) {
        return article;
      }
    }
    return null;
  }
}
