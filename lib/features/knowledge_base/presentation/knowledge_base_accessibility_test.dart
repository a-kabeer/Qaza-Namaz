import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/knowledge_base_repository.dart';
import '../domain/knowledge_article.dart';
import '../domain/knowledge_category.dart';
import '../domain/knowledge_localized_text.dart';
import 'knowledge_base_page.dart';
import 'providers/knowledge_base_providers.dart';

class _FakeRepository implements KnowledgeBaseRepository {
  _FakeRepository(this.articles);

  final List<KnowledgeArticle> articles;

  @override
  Future<List<KnowledgeArticle>> getArticles() async => articles;

  @override
  Future<List<KnowledgeArticle>> getArticlesByCategory(
    KnowledgeCategory category,
  ) async => articles.where((item) => item.category == category).toList();

  @override
  Future<KnowledgeArticle?> getArticleById(String id) async {
    for (final article in articles) {
      if (article.id == id) return article;
    }
    return null;
  }
}

void main() {
  final article = KnowledgeArticle(
    id: 'accessible-article',
    slug: 'accessible-article',
    category: KnowledgeCategory.masail,
    sortOrder: 1,
    title: const KnowledgeLocalizedText(
      ur: 'قابل رسائی عنوان',
      en: 'Accessible title',
    ),
    summary: const KnowledgeLocalizedText(
      ur: 'قابل رسائی خلاصہ',
      en: 'Accessible summary',
    ),
    body: const KnowledgeLocalizedText(
      ur: 'قابل رسائی متن',
      en: 'Accessible body',
    ),
    tags: const ['accessibility'],
    references: const [],
    relatedArticleIds: const [],
  );

  testWidgets('article card exposes a useful semantic label', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          knowledgeBaseRepositoryProvider.overrideWithValue(
            _FakeRepository([article]),
          ),
        ],
        child: const MaterialApp(home: KnowledgeBasePage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Accessible title. Accessible summary'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('article list remains renderable at large text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          knowledgeBaseRepositoryProvider.overrideWithValue(
            _FakeRepository([article]),
          ),
        ],
        child: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: const MaterialApp(home: KnowledgeBasePage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Accessible title'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
