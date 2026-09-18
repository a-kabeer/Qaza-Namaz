import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/knowledge_base/data/knowledge_base_repository.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_article.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_category.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_localized_text.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_reference.dart';
import 'package:qaza_namaz/features/knowledge_base/presentation/providers/knowledge_base_providers.dart';

class _FakeKnowledgeBaseRepository implements KnowledgeBaseRepository {
  _FakeKnowledgeBaseRepository(this._articles);

  final List<KnowledgeArticle> _articles;

  @override
  Future<List<KnowledgeArticle>> getArticles() async =>
      List.unmodifiable(_articles);

  @override
  Future<List<KnowledgeArticle>> getArticlesByCategory(
    KnowledgeCategory category,
  ) async {
    return List.unmodifiable(
      _articles.where((article) => article.category == category),
    );
  }

  @override
  Future<KnowledgeArticle?> getArticleById(String id) async {
    for (final article in _articles) {
      if (article.id == id) return article;
    }
    return null;
  }
}

KnowledgeArticle _article({
  required String id,
  required KnowledgeCategory category,
  required String title,
  List<String> tags = const [],
  List<String> relatedArticleIds = const [],
}) {
  return KnowledgeArticle(
    id: id,
    slug: id,
    category: category,
    sortOrder: 0,
    title: KnowledgeLocalizedText(ur: title, en: title),
    summary: KnowledgeLocalizedText(ur: 'خلاصہ', en: 'Summary'),
    body: KnowledgeLocalizedText(ur: 'متن', en: 'Body'),
    tags: tags,
    references: const <KnowledgeReference>[],
    relatedArticleIds: relatedArticleIds,
  );
}

void main() {
  final articles = [
    _article(
      id: 'masail-fasting',
      category: KnowledgeCategory.masail,
      title: 'Fasting Rules',
      tags: ['fasting', 'masail'],
      relatedArticleIds: ['mugalat-fasting'],
    ),
    _article(
      id: 'mugalat-fasting',
      category: KnowledgeCategory.mugalat,
      title: 'Fasting Misconceptions',
      tags: ['fasting', 'mugalat'],
    ),
  ];

  ProviderContainer buildContainer() {
    return ProviderContainer(
      overrides: [
        knowledgeBaseRepositoryProvider.overrideWithValue(
          _FakeKnowledgeBaseRepository(articles),
        ),
      ],
    );
  }

  test('exposes both knowledge categories', () {
    final container = buildContainer();
    addTearDown(container.dispose);

    expect(container.read(knowledgeBaseCategoriesProvider), [
      KnowledgeCategory.masail,
      KnowledgeCategory.mugalat,
    ]);
  });

  test('filters articles by category and search query', () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    expect(
      await container.read(knowledgeFilteredArticlesProvider.future),
      hasLength(2),
    );

    container.read(knowledgeCategoryFilterProvider.notifier).state =
        KnowledgeCategory.masail;
    expect(
      await container.read(knowledgeFilteredArticlesProvider.future),
      hasLength(1),
    );

    container.read(knowledgeSearchQueryProvider.notifier).state = 'fasting';
    expect(
      await container.read(knowledgeFilteredArticlesProvider.future),
      hasLength(1),
    );
  });

  test('loads selected article and related articles', () async {
    final container = buildContainer();
    addTearDown(container.dispose);

    container.read(knowledgeSelectedArticleIdProvider.notifier).state =
        'masail-fasting';

    final selected =
        await container.read(selectedKnowledgeArticleProvider.future);
    expect(selected?.id, 'masail-fasting');

    final related = await container.read(
      knowledgeRelatedArticlesProvider('masail-fasting').future,
    );
    expect(related.map((article) => article.id), ['mugalat-fasting']);
  });
}
