import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_category.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_language.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_query.dart';
import 'package:qaza_namaz/features/knowledge_base/presentation/knowledge_base_page.dart';
import 'package:qaza_namaz/features/knowledge_base/presentation/providers/knowledge_base_providers.dart';

import '../support/test_app.dart';
import 'support/knowledge_fixtures.dart';

/// Two articles whose English and Urdu text share no words, so a result can
/// only come from the dataset that was actually searched.
final _articles = [
  knowledgeArticle(
    id: 'masala_001',
    topicId: 'sleep_forgetfulness',
    titleEn: 'Sleeping through Fajr',
    titleUr: 'فجر میں نیند',
    summaryEn: 'English summary',
    summaryUr: 'اردو خلاصہ',
    bodyEn: 'English body about oversleeping',
    bodyUr: 'اردو متن سونے کے بارے میں',
    keywordsEn: const ['oversleep'],
    keywordsUr: const ['سونا'],
  ),
  knowledgeArticle(
    id: 'mugalata_001',
    category: KnowledgeCategory.mugalat,
    topicId: 'misconceptions',
    titleEn: 'A misconception',
    titleUr: 'ایک مغالطہ',
    summaryEn: 'Another English summary',
    summaryUr: 'ایک اور اردو خلاصہ',
    bodyEn: 'English explanation',
    bodyUr: 'اردو وضاحت',
    keywordsEn: const ['myth'],
    keywordsUr: const ['وہم'],
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('search reads one language', () {
    test('an English query never matches on the Urdu text', () {
      const query = KnowledgeQuery(
          text: 'اردو خلاصہ', language: KnowledgeLanguage.english);

      expect(_articles.where(query.matches), isEmpty);
    });

    test('an Urdu query never matches on the English text', () {
      const query = KnowledgeQuery(
          text: 'English summary', language: KnowledgeLanguage.urdu);

      expect(_articles.where(query.matches), isEmpty);
    });

    test('each language finds its own content', () {
      expect(
          _articles
              .where(const KnowledgeQuery(
                      text: 'oversleeping', language: KnowledgeLanguage.english)
                  .matches)
              .map((a) => a.id),
          ['masala_001']);
      expect(
          _articles
              .where(const KnowledgeQuery(
                      text: 'وضاحت', language: KnowledgeLanguage.urdu)
                  .matches)
              .map((a) => a.id),
          ['mugalata_001']);
    });

    test('keywords follow the language too', () {
      expect(
          _articles.where(const KnowledgeQuery(
                  text: 'oversleep', language: KnowledgeLanguage.english)
              .matches),
          hasLength(1));
      expect(
          _articles.where(const KnowledgeQuery(
                  text: 'oversleep', language: KnowledgeLanguage.urdu)
              .matches),
          isEmpty);
      expect(
          _articles.where(const KnowledgeQuery(
                  text: 'سونا', language: KnowledgeLanguage.urdu)
              .matches),
          hasLength(1));
    });

    test('language-neutral identifiers stay searchable in both', () {
      for (final language in KnowledgeLanguage.values) {
        expect(
            _articles
                .where(KnowledgeQuery(text: 'masala_001', language: language)
                    .matches)
                .map((a) => a.id),
            ['masala_001'],
            reason: language.name);
      }
    });

    test('the language is part of the query identity', () {
      expect(const KnowledgeQuery(text: 'x', language: KnowledgeLanguage.urdu),
          isNot(const KnowledgeQuery(text: 'x')));
      expect(
          const KnowledgeQuery(text: 'x').language, KnowledgeLanguage.english);
    });
  });

  group('the page follows the switcher', () {
    Future<ProviderContainer> pumpPage(WidgetTester tester,
        {Locale appLocale = const Locale('en')}) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      final container = ProviderContainer(overrides: [
        knowledgeBaseRepositoryProvider
            .overrideWithValue(InMemoryKnowledgeBaseRepository(_articles)),
      ]);
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: TestApp(locale: appLocale, home: const KnowledgeBasePage()),
      ));
      await tester.pumpAndSettle();
      return container;
    }

    Future<void> chooseUrdu(WidgetTester tester) async {
      await tester.tap(find.text('اردو'));
      await tester.pumpAndSettle();
    }

    String hintOf(WidgetTester tester) =>
        tester.widget<TextField>(find.byType(TextField)).decoration!.hintText!;

    testWidgets('categories switch with the content language', (tester) async {
      await pumpPage(tester);
      expect(find.text('Masail'), findsOneWidget);
      expect(find.text('Mugalat'), findsOneWidget);

      await chooseUrdu(tester);

      // Regression: these used to stay in the interface language.
      expect(find.text('Masail'), findsNothing);
      expect(find.text('Mugalat'), findsNothing);
      expect(find.text('مسائل'), findsOneWidget);
      expect(find.text('مغالطے'), findsWidgets);
    });

    testWidgets('topics switch with the content language', (tester) async {
      await pumpPage(tester);
      expect(find.text('Sleep & forgetfulness'), findsOneWidget);
      expect(find.text('All topics'), findsOneWidget);

      await chooseUrdu(tester);

      expect(find.text('Sleep & forgetfulness'), findsNothing);
      expect(find.text('نیند اور بھول'), findsOneWidget);
      expect(find.text('تمام موضوعات'), findsOneWidget);
    });

    testWidgets('the search field switches with the content language',
        (tester) async {
      await pumpPage(tester);
      expect(hintOf(tester), 'Search Masail & Mugalat');

      await chooseUrdu(tester);

      expect(hintOf(tester), isNot('Search Masail & Mugalat'));
      expect(hintOf(tester), contains('مسائل'));
    });

    testWidgets('content labels ignore the interface language', (tester) async {
      // Interface in Urdu, Knowledge Base left in English.
      await pumpPage(tester, appLocale: const Locale('ur'));

      expect(find.text('Masail'), findsOneWidget);
      expect(find.text('Sleep & forgetfulness'), findsOneWidget);
      expect(hintOf(tester), 'Search Masail & Mugalat');
    });

    testWidgets('results come from the selected dataset only', (tester) async {
      final container = await pumpPage(tester);

      container.read(knowledgeSearchQueryProvider.notifier).state =
          'oversleeping';
      await tester.pumpAndSettle();
      expect(
          (await container.read(knowledgeFilteredArticlesProvider.future))
              .map((a) => a.id),
          ['masala_001']);

      await chooseUrdu(tester);
      // The same English words find nothing once Urdu is the reading language.
      expect(await container.read(knowledgeFilteredArticlesProvider.future),
          isEmpty);
    });
  });
}
