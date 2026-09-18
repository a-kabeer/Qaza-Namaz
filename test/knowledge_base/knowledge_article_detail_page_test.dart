import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_category.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_reference.dart';
import 'package:qaza_namaz/features/knowledge_base/presentation/knowledge_article_detail_page.dart';
import 'package:qaza_namaz/features/knowledge_base/presentation/providers/knowledge_base_providers.dart';

import '../support/test_app.dart';
import 'support/knowledge_fixtures.dart';

void main() {
  final article = knowledgeArticle(
    id: 'masala_001',
    category: KnowledgeCategory.masail,
    topicId: 'sleep_forgetfulness',
    titleEn: 'Sample title',
    titleUr: 'نمونہ عنوان',
    summaryEn: 'Sample summary',
    summaryUr: 'نمونہ خلاصہ',
    bodyEn: 'Sample body',
    bodyUr: 'نمونہ متن',
    references: const [
      KnowledgeReference(
        sourceName: 'Quran.com',
        bookName: "The Qur'an",
        author: 'Sample author',
      ),
    ],
  );

  Future<void> pumpDetail(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          knowledgeBaseRepositoryProvider.overrideWithValue(
            InMemoryKnowledgeBaseRepository([article]),
          ),
        ],
        child: const TestApp(
          home: KnowledgeArticleDetailPage(articleId: 'masala_001'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders English then Urdu', (tester) async {
    await pumpDetail(tester);

    expect(find.text('Sample title'), findsOneWidget);
    expect(find.text('Sample summary'), findsOneWidget);
    expect(find.text('Sample body'), findsOneWidget);

    await tester.tap(find.text('اردو'));
    await tester.pump();

    expect(find.text('نمونہ عنوان'), findsOneWidget);
    expect(find.text('نمونہ خلاصہ'), findsOneWidget);
    expect(find.text('نمونہ متن'), findsOneWidget);
  });

  testWidgets('shows the section, the topic and the full reference',
      (tester) async {
    await pumpDetail(tester);

    expect(find.text('Masail'), findsOneWidget);
    expect(find.text('Sleep & forgetfulness'), findsOneWidget);
    expect(find.text("The Qur'an"), findsOneWidget);
    expect(find.text('Sample author • Quran.com'), findsOneWidget);
  });
}
