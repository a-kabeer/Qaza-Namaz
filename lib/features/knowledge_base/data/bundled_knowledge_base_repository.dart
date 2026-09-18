import 'package:flutter/services.dart';

import '../domain/knowledge_article.dart';
import '../domain/knowledge_category.dart';
import '../domain/knowledge_query.dart';
import 'knowledge_base_parser.dart';
import 'knowledge_base_repository.dart';

/// Serves the Masail and Mugalat content bundled with the app.
///
/// The Urdu and English files ship separately, exactly as authored; this is
/// the only place that knows they are two files. Everything above it sees one
/// list of bilingual articles.
class BundledKnowledgeBaseRepository implements KnowledgeBaseRepository {
  BundledKnowledgeBaseRepository({
    KnowledgeBaseParser parser = const KnowledgeBaseParser(),
    AssetBundle? bundle,
  })  : _parser = parser,
        _bundle = bundle;

  static const String englishAssetPath =
      'assets/knowledge_base/content/qaza_masail_mugalat_en.json';
  static const String urduAssetPath =
      'assets/knowledge_base/content/qaza_masail_mugalat_ur.json';

  final KnowledgeBaseParser _parser;
  final AssetBundle? _bundle;
  List<KnowledgeArticle>? _cache;

  @override
  Future<List<KnowledgeArticle>> getArticles() async {
    final cached = _cache;
    if (cached != null) return cached;

    final bundle = _bundle ?? rootBundle;
    final english = await bundle.loadString(englishAssetPath);
    final urdu = await bundle.loadString(urduAssetPath);

    final articles = _parser
        .parsePair(
          english: english,
          urdu: urdu,
          englishSource: englishAssetPath,
          urduSource: urduAssetPath,
        )
        // isPublished is honoured, not just preserved: an unpublished entry
        // stays in the dataset and out of the reader's hands.
        .where((article) => article.isPublished)
        .toList()
      ..sort(_bySectionThenOrder);

    _cache = List.unmodifiable(articles);
    return _cache!;
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
    for (final article in await getArticles()) {
      if (article.id == id) return article;
    }
    return null;
  }

  @override
  Future<List<KnowledgeArticle>> search(KnowledgeQuery query) async {
    final articles = await getArticles();
    if (query.isEmpty) return articles;
    return List.unmodifiable(articles.where(query.matches));
  }

  @override
  Future<List<String>> getTopicIds() async {
    final articles = await getArticles();
    // A LinkedHashSet keeps first-seen order, which is the display order the
    // sort above already established.
    return List.unmodifiable({for (final a in articles) a.topicId});
  }

  /// Each section numbers its own entries from 1, so ordering has to be by
  /// section first or the two would interleave.
  static int _bySectionThenOrder(KnowledgeArticle a, KnowledgeArticle b) {
    final section = a.category.index.compareTo(b.category.index);
    if (section != 0) return section;
    final order = a.sortOrder.compareTo(b.sortOrder);
    return order != 0 ? order : a.id.compareTo(b.id);
  }
}
