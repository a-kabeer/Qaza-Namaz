import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:qaza_namaz/features/knowledge_base/data/bundled_knowledge_base_repository.dart';
import 'package:qaza_namaz/features/knowledge_base/data/knowledge_base_repository.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_article.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_category.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_localized_text.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_query.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_reference.dart';

/// Builds an article without every test restating the whole model.
KnowledgeArticle knowledgeArticle({
  required String id,
  KnowledgeCategory category = KnowledgeCategory.masail,
  String topicId = 'basic',
  int sortOrder = 1,
  bool isPublished = true,
  String titleEn = 'Title',
  String titleUr = 'عنوان',
  String questionEn = 'Question',
  String questionUr = 'سوال',
  String summaryEn = 'Summary',
  String summaryUr = 'خلاصہ',
  String bodyEn = 'Body',
  String bodyUr = 'متن',
  List<String> keywordsEn = const [],
  List<String> keywordsUr = const [],
  List<KnowledgeReference> references = const [],
  List<String> relatedArticleIds = const [],
}) =>
    KnowledgeArticle(
      id: id,
      category: category,
      topicId: topicId,
      sortOrder: sortOrder,
      isPublished: isPublished,
      title: KnowledgeLocalizedText(ur: titleUr, en: titleEn),
      question: KnowledgeLocalizedText(ur: questionUr, en: questionEn),
      summary: KnowledgeLocalizedText(ur: summaryUr, en: summaryEn),
      body: KnowledgeLocalizedText(ur: bodyUr, en: bodyEn),
      keywords: KnowledgeLocalizedKeywords(ur: keywordsUr, en: keywordsEn),
      references: references,
      relatedArticleIds: relatedArticleIds,
    );

/// A complete repository double.
///
/// It implements [search] and [getTopicIds] the same way the bundled one does
/// so a widget test exercising the filters is not quietly testing different
/// rules from production.
class InMemoryKnowledgeBaseRepository implements KnowledgeBaseRepository {
  InMemoryKnowledgeBaseRepository(this.articles);

  final List<KnowledgeArticle> articles;

  @override
  Future<List<KnowledgeArticle>> getArticles() async =>
      List.unmodifiable(articles);

  @override
  Future<List<KnowledgeArticle>> getArticlesByCategory(
          KnowledgeCategory category) async =>
      List.unmodifiable(
          articles.where((article) => article.category == category));

  @override
  Future<KnowledgeArticle?> getArticleById(String id) async {
    for (final article in articles) {
      if (article.id == id) return article;
    }
    return null;
  }

  @override
  Future<List<KnowledgeArticle>> search(KnowledgeQuery query) async =>
      List.unmodifiable(articles.where(query.matches));

  @override
  Future<List<String>> getTopicIds() async =>
      List.unmodifiable({for (final article in articles) article.topicId});
}

/// One raw dataset entry, in the shape the shipped files use.
Map<String, dynamic> datasetEntry({
  required String id,
  required String language,
  String type = 'masala',
  String categoryId = 'basic',
  int sortOrder = 1,
  bool isPublished = true,
  String? title,
  List<Map<String, String>> references = const [],
}) {
  final suffix = language == 'en' ? 'En' : 'Ur';
  final text = title ?? (language == 'en' ? 'Text $id' : 'متن $id');
  return {
    'id': id,
    'type': type,
    'categoryId': categoryId,
    'title$suffix': text,
    'question$suffix': text,
    'summary$suffix': text,
    'content$suffix': text,
    'keywords$suffix': [language == 'en' ? 'keyword' : 'کلیدی'],
    'references': references,
    'sortOrder': sortOrder,
    'isPublished': isPublished,
  };
}

/// An asset bundle serving the two dataset files from memory.
AssetBundle datasetBundle({
  required List<Map<String, dynamic>> english,
  required List<Map<String, dynamic>> urdu,
}) =>
    _MemoryAssetBundle({
      BundledKnowledgeBaseRepository.englishAssetPath: jsonEncode(english),
      BundledKnowledgeBaseRepository.urduAssetPath: jsonEncode(urdu),
    });

class _MemoryAssetBundle extends CachingAssetBundle {
  _MemoryAssetBundle(this._assets);

  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async {
    final value = _assets[key];
    if (value == null) {
      throw FlutterError('Missing test asset: $key');
    }
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}
