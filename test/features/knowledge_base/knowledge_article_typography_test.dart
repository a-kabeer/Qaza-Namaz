import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/features/knowledge_base/data/knowledge_base_repository.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_article.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_category.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_language.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_localized_text.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_query.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_reference.dart';
import 'package:qaza_namaz/features/knowledge_base/presentation/knowledge_article_detail_page.dart';
import 'package:qaza_namaz/features/knowledge_base/presentation/knowledge_base_page.dart';
import 'package:qaza_namaz/features/knowledge_base/presentation/providers/knowledge_base_providers.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

const _primaryArticle = KnowledgeArticle(
  id: 'masala_001',
  category: KnowledgeCategory.masail,
  topicId: 'qaza_namaz',
  sortOrder: 1,
  isPublished: true,
  title: KnowledgeLocalizedText(
    ur: 'قضا نماز کا عنوان',
    en: 'English article title',
    urLatn: 'Qaza namaz ka unwan',
  ),
  question: KnowledgeLocalizedText(
    ur: 'قضا نماز کے بارے میں سوال',
    en: 'A question about missed prayers',
    urLatn: 'Qaza namaz ke baray mein sawal',
  ),
  summary: KnowledgeLocalizedText(
    ur: 'یہ قضا نماز کے بارے میں ایک طویل خلاصہ ہے۔',
    en: 'A longer summary about making up missed prayers.',
    urLatn: 'Yeh qaza namaz ke baray mein aik taweel khulasa hai.',
  ),
  body: KnowledgeLocalizedText(
    ur: 'قضا نماز کی ادائیگی کے لیے روزانہ کا ہدف مقرر کریں۔ '
        'اپنی پیش رفت باقاعدگی سے دیکھیں اور ضرورت کے مطابق ہدف تبدیل کریں۔ '
        'اس مضمون میں طویل عبارت، اعداد ۱۲۳ اور English mixed text شامل ہے۔ '
        'یہ متن کئی سطروں میں لپٹنا چاہیے اور اگلے متن سے نہیں ٹکرانا چاہیے۔',
    en: 'Set a daily target for making up missed prayers. '
        'Review your progress regularly and adjust the target when needed.',
    urLatn: 'Qaza namaz ki adaigi ke liye rozana ka hadaf muqarrar karein. '
        'Apni pesh raft baqaidgi se dekhein aur zaroorat ke mutabiq hadaf tabdeel karein.',
  ),
  keywords: KnowledgeLocalizedKeywords.empty,
  references: [
    KnowledgeReference(
      sourceName: 'Test source',
      bookName: 'Test fiqh book',
      author: 'Test author',
    ),
  ],
  relatedArticleIds: ['masala_002'],
);

const _relatedArticle = KnowledgeArticle(
  id: 'masala_002',
  category: KnowledgeCategory.masail,
  topicId: 'qaza_namaz',
  sortOrder: 2,
  isPublished: true,
  title: KnowledgeLocalizedText(
    ur: 'متعلقہ مضمون کا عنوان',
    en: 'Related article title',
    urLatn: 'Mutaliqa mazmoon ka unwan',
  ),
  question: KnowledgeLocalizedText(
    ur: 'متعلقہ سوال',
    en: 'Related question',
    urLatn: 'Mutaliqa sawal',
  ),
  summary: KnowledgeLocalizedText(
    ur: 'متعلقہ خلاصہ',
    en: 'Related summary',
    urLatn: 'Mutaliqa khulasa',
  ),
  body: KnowledgeLocalizedText(
    ur: 'متعلقہ مضمون کی عبارت',
    en: 'Related article body',
    urLatn: 'Mutaliqa mazmoon ka matn',
  ),
  keywords: KnowledgeLocalizedKeywords.empty,
  references: [],
);

class _FakeKnowledgeBaseRepository implements KnowledgeBaseRepository {
  _FakeKnowledgeBaseRepository(this.articles);

  final List<KnowledgeArticle> articles;

  @override
  Future<List<KnowledgeArticle>> getArticles() async => articles;

  @override
  Future<List<KnowledgeArticle>> getArticlesByCategory(
    KnowledgeCategory category,
  ) async =>
      articles.where((article) => article.category == category).toList();

  @override
  Future<KnowledgeArticle?> getArticleById(String id) async {
    for (final article in articles) {
      if (article.id == id) return article;
    }
    return null;
  }

  @override
  Future<List<KnowledgeArticle>> search(KnowledgeQuery query) async =>
      articles.where(query.matches).toList();

  @override
  Future<List<String>> getTopicIds() async =>
      articles.map((article) => article.topicId).toSet().toList();
}

class _TestKnowledgeLanguageNotifier extends KnowledgeLanguageNotifier {
  @override
  KnowledgeLanguage build() => KnowledgeLanguage.urdu;

  // Typography tests exercise rendering/direction, not persistence. Keep
  // language changes synchronous so database I/O cannot block widget pumping.
  @override
  void set(KnowledgeLanguage language) => state = language;
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  // Article pages can contain repeating skeleton animations while an async
  // provider resolves, so pumpAndSettle may wait forever. Pump bounded frames
  // until the expected article text is present instead.
  for (var frame = 0; frame < 60; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder to appear');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [
        knowledgeLanguageProvider.overrideWith(
          _TestKnowledgeLanguageNotifier.new,
        ),
        knowledgeBaseRepositoryProvider.overrideWithValue(
          _FakeKnowledgeBaseRepository([_primaryArticle, _relatedArticle]),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(knowledgeLanguageProvider.notifier)
        .set(KnowledgeLanguage.urdu);
  });

  testWidgets(
    'Roman Urdu article renders left-to-right in an English interface',
    (tester) async {
      container
          .read(knowledgeLanguageProvider.notifier)
          .set(KnowledgeLanguage.romanUrdu);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.light(locale: const Locale('en')),
            home: const KnowledgeArticleDetailPage(articleId: 'masala_001'),
          ),
        ),
      );
      await _pumpUntilFound(tester, find.text('Qaza namaz ka unwan'));

      final title = tester.widget<Text>(find.text('Qaza namaz ka unwan'));
      expect(title.textDirection, TextDirection.ltr);
      expect(
        find.text(
          'Qaza namaz ki adaigi ke liye rozana ka hadaf muqarrar karein. '
          'Apni pesh raft baqaidgi se dekhein aur zaroorat ke mutabiq hadaf tabdeel karein.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Urdu article stays RTL while English interface headings stay LTR',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 720);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.light(locale: const Locale('en')),
            home: const KnowledgeArticleDetailPage(articleId: 'masala_001'),
          ),
        ),
      );
      await _pumpUntilFound(tester, find.text('قضا نماز کا عنوان'));

      final urduTitle = tester.widget<Text>(find.text('قضا نماز کا عنوان'));
      expect(urduTitle.textDirection, TextDirection.rtl);

      final context = tester.element(find.byType(KnowledgeArticleDetailPage));
      final referencesText =
          AppLocalizations.of(context).knowledgeArticleReferences;
      final referencesHeading = tester.widget<Text>(
        find.text(referencesText),
      );
      // No explicit article direction: the heading follows the English
      // interface's ambient Directionality rather than inheriting Urdu RTL.
      expect(referencesHeading.textDirection, isNull);
      expect(tester.takeException(), isNull);

      container
          .read(knowledgeLanguageProvider.notifier)
          .set(KnowledgeLanguage.english);
      await _pumpUntilFound(tester, find.text('English article title'));

      final englishTitle =
          tester.widget<Text>(find.text('English article title'));
      expect(englishTitle.textDirection, TextDirection.ltr);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Urdu Knowledge list keeps cards and filter labels readable on narrow screens',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.light(locale: const Locale('en')),
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(1.4),
                ),
                child: const KnowledgeBasePage(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final articleTitle = tester.widget<Text>(
        find.text('قضا نماز کا عنوان'),
      );
      expect(articleTitle.textDirection, TextDirection.rtl);
      expect(
        find.text('یہ قضا نماز کے بارے میں ایک طویل خلاصہ ہے۔'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long Urdu article lays out at narrow width with enlarged text in both themes',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final brightness in Brightness.values) {
        final theme = brightness == Brightness.dark
            ? AppTheme.dark(locale: const Locale('en'))
            : AppTheme.light(locale: const Locale('en'));
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('en'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              theme: theme,
              home: Builder(
                builder: (context) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.4),
                  ),
                  child: const KnowledgeArticleDetailPage(
                    articleId: 'masala_001',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('قضا نماز کا عنوان'),
          findsOneWidget,
          reason: 'Article title should remain visible in $brightness mode',
        );
        expect(
          tester.takeException(),
          isNull,
          reason: 'Urdu article should lay out in $brightness mode',
        );
      }
    },
  );
}
