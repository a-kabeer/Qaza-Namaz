import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_category.dart';
import 'package:qaza_namaz/features/knowledge_base/presentation/providers/knowledge_base_providers.dart';

import 'support/knowledge_fixtures.dart';

void main() {
  final articles = [
    knowledgeArticle(
      id: 'masala_001',
      topicId: 'sleep_forgetfulness',
      titleEn: 'Sleeping through Fajr',
      titleUr: 'فجر میں نیند',
      keywordsEn: const ['sleep'],
      keywordsUr: const ['نیند'],
      relatedArticleIds: const ['mugalata_001'],
    ),
    knowledgeArticle(
      id: 'mugalata_001',
      category: KnowledgeCategory.mugalat,
      topicId: 'misconceptions',
      titleEn: 'Sleep excuses qaza',
      titleUr: 'نیند قضا کا عذر ہے',
      keywordsEn: const ['sleep'],
    ),
    knowledgeArticle(
      id: 'masala_002',
      topicId: 'friday',
      sortOrder: 2,
      titleEn: 'Missing Jumuah',
      titleUr: 'جمعہ چھوٹ جانا',
      keywordsEn: const ['friday'],
    ),
  ];

  ProviderContainer buildContainer() {
    final container = ProviderContainer(overrides: [
      knowledgeBaseRepositoryProvider
          .overrideWithValue(InMemoryKnowledgeBaseRepository(articles)),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  test('exposes both sections and the topics present in the content', () async {
    final container = buildContainer();

    expect(container.read(knowledgeBaseCategoriesProvider),
        [KnowledgeCategory.masail, KnowledgeCategory.mugalat]);
    expect(await container.read(knowledgeTopicIdsProvider.future),
        ['sleep_forgetfulness', 'misconceptions', 'friday']);
  });

  test('gathers the three controls into one query', () {
    final container = buildContainer();

    expect(container.read(knowledgeQueryProvider).isEmpty, isTrue);

    container.read(knowledgeSearchQueryProvider.notifier).state = 'sleep';
    container.read(knowledgeCategoryFilterProvider.notifier).state =
        KnowledgeCategory.masail;
    container.read(knowledgeTopicFilterProvider.notifier).state = 'friday';

    final query = container.read(knowledgeQueryProvider);
    expect(query.text, 'sleep');
    expect(query.category, KnowledgeCategory.masail);
    expect(query.topicId, 'friday');
  });

  test('filters by section, topic and free text', () async {
    final container = buildContainer();

    expect(await container.read(knowledgeFilteredArticlesProvider.future),
        hasLength(3));

    container.read(knowledgeCategoryFilterProvider.notifier).state =
        KnowledgeCategory.masail;
    expect(
        (await container.read(knowledgeFilteredArticlesProvider.future))
            .map((article) => article.id),
        ['masala_001', 'masala_002']);

    container.read(knowledgeTopicFilterProvider.notifier).state = 'friday';
    expect(
        (await container.read(knowledgeFilteredArticlesProvider.future))
            .map((article) => article.id),
        ['masala_002']);

    container.read(knowledgeTopicFilterProvider.notifier).state = null;
    container.read(knowledgeSearchQueryProvider.notifier).state = 'sleep';
    expect(
        (await container.read(knowledgeFilteredArticlesProvider.future))
            .map((article) => article.id),
        ['masala_001']);
  });

  test('search matches Urdu text as well as English', () async {
    final container = buildContainer();

    container.read(knowledgeSearchQueryProvider.notifier).state = 'نیند';
    expect(
        (await container.read(knowledgeFilteredArticlesProvider.future))
            .map((article) => article.id),
        ['masala_001', 'mugalata_001']);
  });

  test('loads the selected article and its related articles', () async {
    final container = buildContainer();

    container.read(knowledgeSelectedArticleIdProvider.notifier).state =
        'masala_001';

    expect((await container.read(selectedKnowledgeArticleProvider.future))?.id,
        'masala_001');
    expect(
        (await container
                .read(knowledgeRelatedArticlesProvider('masala_001').future))
            .map((article) => article.id),
        ['mugalata_001']);
  });
}
