import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/knowledge_base_repository.dart';
import '../domain/knowledge_article.dart';
import '../domain/knowledge_category.dart';
import '../domain/knowledge_localized_text.dart';
import '../domain/knowledge_reference.dart';
import 'knowledge_article_detail_page.dart';
import 'providers/knowledge_base_providers.dart';

class _FakeRepository implements KnowledgeBaseRepository {
  _FakeRepository(this.article);

  final KnowledgeArticle article;

  @override
  Future<List<KnowledgeArticle>> getArticles() async => [article];

  @override
  Future<List<KnowledgeArticle>> getArticlesByCategory(
    KnowledgeCategory category,
  ) async => [article].where((item) => item.category == category).toList();

  @override
  Future<KnowledgeArticle?> getArticleById(String id) async =>
      id == article.id ? article : null;
}

void main() {
  final article = KnowledgeArticle(
    id: 'sample-article',
    slug: 'sample-article',
    category: KnowledgeCategory.masail,
    sortOrder: 1,
    title: const KnowledgeLocalizedText(
      ur: 'نمونہ عنوان',
      en: 'Sample title',
    ),
    summary: const KnowledgeLocalizedText(
      ur: 'نمونہ خلاصہ',
      en: 'Sample summary',
    ),
    body: const KnowledgeLocalizedText(
      ur: 'نمونہ متن',
      en: 'Sample body',
    ),
    tags: const ['sample'],
    references: const [
      KnowledgeReference(
        source: 'Sample source',
        citation: 'Sample citation',
      ),
    ],
    relatedArticleIds: const [],
  );

  testWidgets('renders English then Urdu and references', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          knowledgeBaseRepositoryProvider.overrideWithValue(
            _FakeRepository(article),
          ),
        ],
        child: const MaterialApp(
          home: KnowledgeArticleDetailPage(articleId: 'sample-article'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sample title'), findsOneWidget);
    expect(find.text('Sample summary'), findsOneWidget);
    expect(find.text('Sample body'), findsOneWidget);
    expect(find.text('Sample source'), findsOneWidget);

    await tester.tap(find.text('اردو'));
    await tester.pump();

    expect(find.text('نمونہ عنوان'), findsOneWidget);
    expect(find.text('نمونہ خلاصہ'), findsOneWidget);
    expect(find.text('نمونہ متن'), findsOneWidget);
  });
}
