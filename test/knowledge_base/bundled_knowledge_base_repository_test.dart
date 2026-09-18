import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/knowledge_base/data/bundled_knowledge_base_repository.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_category.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_language.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_query.dart';

import 'support/knowledge_fixtures.dart';

void main() {
  List<Map<String, dynamic>> entries(String language) => [
        datasetEntry(
            id: 'masala_002',
            language: language,
            sortOrder: 2,
            categoryId: 'friday'),
        datasetEntry(id: 'masala_001', language: language, sortOrder: 1),
        datasetEntry(
          id: 'mugalata_001',
          language: language,
          type: 'mugalata',
          categoryId: 'misconceptions',
          sortOrder: 1,
        ),
      ];

  BundledKnowledgeBaseRepository repositoryFor(
          {List<Map<String, dynamic>>? english,
          List<Map<String, dynamic>>? urdu}) =>
      BundledKnowledgeBaseRepository(
        bundle: datasetBundle(
          english: english ?? entries('en'),
          urdu: urdu ?? entries('ur'),
        ),
      );

  test('orders by section, then by the order the dataset gives', () async {
    final articles = await repositoryFor().getArticles();

    // Each section numbers from 1, so mugalata_001 must not sort alongside
    // masala_001 — sections stay whole.
    expect(articles.map((article) => article.id),
        ['masala_001', 'masala_002', 'mugalata_001']);
  });

  test('filters by section', () async {
    final repository = repositoryFor();

    expect(
        (await repository.getArticlesByCategory(KnowledgeCategory.masail))
            .map((article) => article.id),
        ['masala_001', 'masala_002']);
    expect(
        (await repository.getArticlesByCategory(KnowledgeCategory.mugalat))
            .map((article) => article.id),
        ['mugalata_001']);
  });

  test('looks an article up by its dataset id', () async {
    final repository = repositoryFor();

    expect((await repository.getArticleById('mugalata_001'))?.topicId,
        'misconceptions');
    expect(await repository.getArticleById('masala_999'), isNull);
  });

  test('withholds an unpublished entry from readers', () async {
    final repository = repositoryFor(
      english: [
        datasetEntry(id: 'masala_001', language: 'en'),
        datasetEntry(id: 'masala_002', language: 'en', sortOrder: 2)
          ..['isPublished'] = false,
      ],
      urdu: [
        datasetEntry(id: 'masala_001', language: 'ur'),
        datasetEntry(id: 'masala_002', language: 'ur', sortOrder: 2)
          ..['isPublished'] = false,
      ],
    );

    expect((await repository.getArticles()).map((article) => article.id),
        ['masala_001']);
    expect(await repository.getArticleById('masala_002'), isNull);
  });

  test('lists only topics that have articles', () async {
    expect(await repositoryFor().getTopicIds(),
        ['basic', 'friday', 'misconceptions']);
  });

  test('searches across both languages and both filters', () async {
    final repository = repositoryFor();

    expect(await repository.search(KnowledgeQuery.none), hasLength(3));
    expect(
        (await repository.search(
                const KnowledgeQuery(category: KnowledgeCategory.mugalat)))
            .map((article) => article.id),
        ['mugalata_001']);
    expect(
        (await repository.search(const KnowledgeQuery(topicId: 'friday')))
            .map((article) => article.id),
        ['masala_002']);
    expect(
        (await repository.search(const KnowledgeQuery(text: 'masala_001')))
            .map((article) => article.id),
        ['masala_001']);
    // Free text reads the selected language only: Urdu words match under the
    // Urdu reading language and nothing under English.
    expect(
        await repository.search(const KnowledgeQuery(
            text: 'متن', language: KnowledgeLanguage.urdu)),
        hasLength(3));
    expect(await repository.search(const KnowledgeQuery(text: 'متن')), isEmpty);
    expect(
        await repository.search(const KnowledgeQuery(
            text: 'masala_001', category: KnowledgeCategory.mugalat)),
        isEmpty);
  });

  test('parses the datasets once and serves the cache after that', () async {
    final repository = repositoryFor();

    final first = await repository.getArticles();
    final second = await repository.getArticles();

    expect(identical(first, second), isTrue);
  });
}
