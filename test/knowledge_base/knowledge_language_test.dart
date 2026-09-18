import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_language.dart';
import 'package:qaza_namaz/features/knowledge_base/presentation/knowledge_base_page.dart';
import 'package:qaza_namaz/features/knowledge_base/presentation/providers/knowledge_base_providers.dart';

import '../support/test_app.dart';
import 'support/knowledge_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final article = knowledgeArticle(
    id: 'masala_001',
    titleEn: 'Sleeping through Fajr',
    titleUr: 'فجر میں نیند',
    summaryEn: 'English summary',
    summaryUr: 'اردو خلاصہ',
    bodyEn: 'English body',
    bodyUr: 'اردو متن',
  );

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('language value', () {
    test('carries its own direction, alignment and code', () {
      expect(KnowledgeLanguage.urdu.isUrdu, isTrue);
      expect(KnowledgeLanguage.urdu.direction, TextDirection.rtl);
      expect(KnowledgeLanguage.urdu.textAlign, TextAlign.right);
      expect(KnowledgeLanguage.urdu.code, 'ur');

      expect(KnowledgeLanguage.english.isUrdu, isFalse);
      expect(KnowledgeLanguage.english.direction, TextDirection.ltr);
      expect(KnowledgeLanguage.english.textAlign, TextAlign.left);
      expect(KnowledgeLanguage.english.code, 'en');
    });

    test('resolves stored codes and rejects anything else', () {
      expect(KnowledgeLanguage.fromCode('ur'), KnowledgeLanguage.urdu);
      expect(KnowledgeLanguage.fromCode('en'), KnowledgeLanguage.english);
      expect(KnowledgeLanguage.fromCode('fr'), isNull);
      expect(KnowledgeLanguage.fromCode(null), isNull);
    });
  });

  group('persisted selection', () {
    ProviderContainer container() {
      final result = ProviderContainer();
      addTearDown(result.dispose);
      result.listen(knowledgeLanguageProvider, (_, __) {});
      return result;
    }

    test('starts from the application language', () async {
      final scope = container();

      expect(scope.read(knowledgeLanguageProvider), KnowledgeLanguage.english);

      scope.read(localeProvider.notifier).set(const Locale('ur'));
      expect(scope.read(knowledgeLanguageProvider), KnowledgeLanguage.urdu);
    });

    test('writes the choice to storage', () async {
      final scope = container();

      scope
          .read(knowledgeLanguageProvider.notifier)
          .set(KnowledgeLanguage.urdu);
      await Future<void>.delayed(Duration.zero);

      expect(scope.read(knowledgeLanguageProvider), KnowledgeLanguage.urdu);
      expect(
          (await SharedPreferences.getInstance())
              .getString(KnowledgeLanguageNotifier.storageKey),
          'ur');
    });

    test('restores the choice on the next launch', () async {
      SharedPreferences.setMockInitialValues(
          {KnowledgeLanguageNotifier.storageKey: 'ur'});
      final scope = container();

      expect(scope.read(knowledgeLanguageProvider), KnowledgeLanguage.english);
      await scope.read(knowledgeLanguageProvider.notifier).restore();

      expect(scope.read(knowledgeLanguageProvider), KnowledgeLanguage.urdu);
    });

    test('ignores an unreadable stored value', () async {
      SharedPreferences.setMockInitialValues(
          {KnowledgeLanguageNotifier.storageKey: 'klingon'});
      final scope = container();

      await scope.read(knowledgeLanguageProvider.notifier).restore();

      expect(scope.read(knowledgeLanguageProvider), KnowledgeLanguage.english);
    });

    test('an explicit choice outlives a change to the app language', () async {
      final scope = container();

      scope
          .read(knowledgeLanguageProvider.notifier)
          .set(KnowledgeLanguage.urdu);
      scope.read(localeProvider.notifier).set(const Locale('en'));

      expect(scope.read(knowledgeLanguageProvider), KnowledgeLanguage.urdu);
    });

    test('choosing a reading language leaves Settings alone', () async {
      final scope = container();
      scope.listen(localeProvider, (_, __) {});

      scope
          .read(knowledgeLanguageProvider.notifier)
          .set(KnowledgeLanguage.urdu);
      await Future<void>.delayed(Duration.zero);

      expect(scope.read(localeProvider).languageCode, 'en');
      expect(
          (await SharedPreferences.getInstance())
              .getString(LocaleNotifier.storageKey),
          isNull);
    });
  });

  group('screens', () {
    Future<void> pumpList(WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          knowledgeBaseRepositoryProvider.overrideWithValue(
            InMemoryKnowledgeBaseRepository([article]),
          ),
        ],
        child: TestApp(
          theme: AppTheme.light(locale: const Locale('en')),
          locale: const Locale('en'),
          home: const KnowledgeBasePage(),
        ),
      ));
      await tester.pumpAndSettle();
    }

    Future<void> chooseUrdu(WidgetTester tester) async {
      await tester.tap(find.text('اردو'));
      await tester.pumpAndSettle();
    }

    testWidgets('the switcher sits at the top of the Knowledge Base',
        (tester) async {
      await pumpList(tester);

      expect(
          find.byKey(const Key('knowledge_language_switcher')), findsOneWidget);
      expect(find.text('اردو'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      // Fixed under the app bar rather than scrolling with the list.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byKey(const Key('knowledge_language_switcher')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('the list renders in the chosen language', (tester) async {
      await pumpList(tester);

      expect(find.text('Sleeping through Fajr'), findsOneWidget);
      expect(find.text('فجر میں نیند'), findsNothing);

      await chooseUrdu(tester);

      expect(find.text('فجر میں نیند'), findsOneWidget);
      expect(find.text('اردو خلاصہ'), findsOneWidget);
      expect(find.text('Sleeping through Fajr'), findsNothing);
    });

    testWidgets('Urdu content gets Nastaliq and right-to-left text',
        (tester) async {
      await pumpList(tester);
      await chooseUrdu(tester);

      final title = tester.widget<Text>(find.text('فجر میں نیند'));
      expect(title.style!.fontFamily, AppTheme.urduFamily);
      expect(title.textDirection, TextDirection.rtl);
      expect(title.textAlign, TextAlign.right);
    });

    testWidgets('English content keeps the Latin face and left-to-right text',
        (tester) async {
      await pumpList(tester);

      final title = tester.widget<Text>(find.text('Sleeping through Fajr'));
      expect(title.style!.fontFamily, isNot(AppTheme.urduFamily));
      expect(title.textDirection, TextDirection.ltr);
      expect(title.textAlign, TextAlign.left);
    });

    testWidgets('the interface stays in its own language', (tester) async {
      await pumpList(tester);
      await chooseUrdu(tester);

      // Content flipped; the page itself did not.
      expect(Directionality.of(tester.element(find.byType(KnowledgeBasePage))),
          TextDirection.ltr);
      expect(find.text('Knowledge Base'), findsOneWidget);
    });

    testWidgets('the choice carries into an article and back', (tester) async {
      await pumpList(tester);
      await chooseUrdu(tester);

      await tester.tap(find.text('فجر میں نیند'));
      await tester.pumpAndSettle();

      // The article opens in Urdu rather than resetting to English, and shows
      // the same control in the same place.
      expect(find.text('اردو متن'), findsOneWidget);
      expect(
          find.byKey(const Key('knowledge_language_switcher')), findsOneWidget);

      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      expect(find.text('English body'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      // Switching inside the article is still in force on the list.
      expect(find.text('Sleeping through Fajr'), findsOneWidget);
    });
  });
}
