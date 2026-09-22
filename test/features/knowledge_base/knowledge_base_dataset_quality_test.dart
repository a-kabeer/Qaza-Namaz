import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/knowledge_base/data/bundled_knowledge_base_repository.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_article.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_category.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_language.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_query.dart';

/// Checks the datasets that actually ship, not a fixture standing in for them.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> englishSource;
  late List<Map<String, dynamic>> urduSource;
  late List<KnowledgeArticle> articles;

  Future<List<Map<String, dynamic>>> loadSource(String path) async {
    final raw = await rootBundle.loadString(path);
    return (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  setUpAll(() async {
    englishSource =
        await loadSource(BundledKnowledgeBaseRepository.englishAssetPath);
    urduSource = await loadSource(BundledKnowledgeBaseRepository.urduAssetPath);
    articles = await BundledKnowledgeBaseRepository().getArticles();
  });

  test('both shipped files parse and join', () {
    expect(englishSource, hasLength(76));
    expect(urduSource, hasLength(76));
    expect(articles, hasLength(76));
  });

  test('every id from the source files survives verbatim', () {
    final sourceIds = englishSource.map((entry) => entry['id']).toSet();

    expect(articles.map((article) => article.id).toSet(), sourceIds);
    expect(sourceIds, contains('masala_001'));
    expect(sourceIds, contains('mugalata_020'));
  });

  test('sections carry the counts the data has', () {
    final bySection = <KnowledgeCategory, int>{};
    for (final article in articles) {
      bySection[article.category] = (bySection[article.category] ?? 0) + 1;
    }

    expect(bySection[KnowledgeCategory.masail], 56);
    expect(bySection[KnowledgeCategory.mugalat], 20);
  });

  test('categoryId, sortOrder and isPublished are preserved entry by entry',
      () {
    final byId = {for (final article in articles) article.id: article};

    for (final entry in englishSource) {
      final article = byId[entry['id']];
      expect(article, isNotNull, reason: '${entry['id']} is missing');
      expect(article!.topicId, entry['categoryId']);
      expect(article.sortOrder, entry['sortOrder']);
      expect(article.isPublished, entry['isPublished']);
      expect(article.category.datasetType, entry['type']);
    }
  });

  test('keywords and references are preserved entry by entry', () {
    final byId = {for (final article in articles) article.id: article};
    final urduById = {for (final entry in urduSource) entry['id']: entry};

    for (final entry in englishSource) {
      final article = byId[entry['id']]!;
      expect(article.keywords.en, entry['keywordsEn']);
      expect(article.keywords.ur, urduById[entry['id']]!['keywordsUr']);

      final references = entry['references'] as List<dynamic>;
      expect(article.references, hasLength(references.length));
      for (var index = 0; index < references.length; index++) {
        final source = references[index] as Map<String, dynamic>;
        expect(article.references[index].sourceName, source['sourceName']);
        expect(article.references[index].bookName, source['bookName']);
        expect(article.references[index].author, source['author']);
      }
    }
  });

  test('both languages are complete for every entry', () {
    for (final article in articles) {
      expect(article.title.isComplete, isTrue, reason: article.id);
      expect(article.question.isComplete, isTrue, reason: article.id);
      expect(article.summary.isComplete, isTrue, reason: article.id);
      expect(article.body.isComplete, isTrue, reason: article.id);
    }
  });

  test('every topic offered by the filter has articles behind it', () async {
    final repository = BundledKnowledgeBaseRepository();
    final topics = await repository.getTopicIds();

    expect(topics, hasLength(9));
    for (final topicId in topics) {
      expect(await repository.search(KnowledgeQuery(topicId: topicId)),
          isNotEmpty);
    }
  });

  test('search reaches the real content in both languages', () async {
    final repository = BundledKnowledgeBaseRepository();

    expect(await repository.search(const KnowledgeQuery(text: 'qaza')),
        isNotEmpty);
    // Free text reads the selected language's fields, so the Urdu search has
    // to say so; under English the Urdu words match nothing.
    expect(
        await repository.search(const KnowledgeQuery(
            text: 'قضا', language: KnowledgeLanguage.urdu)),
        isNotEmpty);
    expect(await repository.search(const KnowledgeQuery(text: 'قضا')), isEmpty);
    expect(
      await repository.search(const KnowledgeQuery(
        text: 'sleep',
        category: KnowledgeCategory.mugalat,
      )),
      isNotEmpty,
    );
    expect(
        await repository
            .search(const KnowledgeQuery(text: 'zzz-no-such-content')),
        isEmpty);
  });

  test('ordering is deterministic and section by section', () {
    var previousSection = articles.first.category;
    var previousOrder = 0;
    for (final article in articles) {
      if (article.category != previousSection) {
        previousSection = article.category;
        previousOrder = 0;
      }
      expect(article.sortOrder, greaterThan(previousOrder), reason: article.id);
      previousOrder = article.sortOrder;
    }
  });
}
