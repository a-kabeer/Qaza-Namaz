import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/theme/app_theme.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_article.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_category.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_localized_text.dart';
import 'package:qaza_namaz/features/knowledge_base/presentation/knowledge_article_detail_page.dart';
import 'package:qaza_namaz/features/knowledge_base/presentation/providers/knowledge_base_providers.dart';

import 'knowledge_base/support/knowledge_fixtures.dart';
import 'support/test_app.dart';

const _urdu = Locale('ur');
const _english = Locale('en');

/// Every slot of a [TextTheme], so no test can quietly check a subset.
List<TextStyle> _allSlots(TextTheme theme) => [
      theme.displayLarge!,
      theme.displayMedium!,
      theme.displaySmall!,
      theme.headlineLarge!,
      theme.headlineMedium!,
      theme.headlineSmall!,
      theme.titleLarge!,
      theme.titleMedium!,
      theme.titleSmall!,
      theme.bodyLarge!,
      theme.bodyMedium!,
      theme.bodySmall!,
      theme.labelLarge!,
      theme.labelMedium!,
      theme.labelSmall!,
    ];

const _masalaArticle = KnowledgeArticle(
  id: 'masala_001',
  category: KnowledgeCategory.masail,
  topicId: 'basic',
  sortOrder: 1,
  isPublished: true,
  title: KnowledgeLocalizedText(ur: 'قضا نماز کا مسئلہ', en: 'A masala'),
  question: KnowledgeLocalizedText(ur: 'قضا نماز کا مسئلہ', en: 'A masala'),
  summary: KnowledgeLocalizedText(ur: 'مختصر خلاصہ', en: 'A summary'),
  body: KnowledgeLocalizedText(
      ur: 'قضا نمازوں کی ادائیگی کے بارے میں تفصیلی وضاحت۔',
      en: 'A detailed explanation.'),
  keywords: KnowledgeLocalizedKeywords.empty,
  references: [],
);

void main() {
  group('type scale', () {
    test('the Urdu scale uses Nastaliq in every slot', () {
      final theme = AppTheme.light(locale: _urdu);

      for (final style in _allSlots(theme.textTheme)) {
        expect(style.fontFamily, AppTheme.urduFamily);
      }
    });

    test('the English scale keeps the Latin families', () {
      final theme = AppTheme.light(locale: _english);

      for (final style in _allSlots(theme.textTheme)) {
        expect(style.fontFamily, isNot(AppTheme.urduFamily));
      }
      expect(theme.textTheme.bodyMedium!.fontFamily, 'Manrope');
      expect(theme.textTheme.displayLarge!.fontFamily, 'Noto Serif');
    });

    test('a null locale falls back to the Latin scale', () {
      expect(AppTheme.light().textTheme.bodyMedium!.fontFamily, 'Manrope');
      expect(AppTheme.dark().textTheme.bodyMedium!.fontFamily, 'Manrope');
    });

    test('Urdu styles carry no letter spacing', () {
      // Spacing out Arabic-script letters breaks the cursive join between
      // them, which is precisely what Nastaliq is made of.
      for (final style in _allSlots(AppTheme.dark(locale: _urdu).textTheme)) {
        expect(style.letterSpacing, 0);
        expect(style.wordSpacing, 0);
      }
    });

    test('Urdu lines are given room for the Nastaliq cascade', () {
      final urdu = AppTheme.light(locale: _urdu).textTheme;
      final latin = AppTheme.light(locale: _english).textTheme;

      for (final style in _allSlots(urdu)) {
        expect(style.height, greaterThanOrEqualTo(1.9),
            reason: 'Nastaliq clips into the next line below this');
      }
      for (final slot in [
        (urdu.bodyMedium!, latin.bodyMedium!),
        (urdu.titleLarge!, latin.titleLarge!),
        (urdu.labelSmall!, latin.labelSmall!),
      ]) {
        expect(slot.$1.fontSize, greaterThan(slot.$2.fontSize!));
        expect(slot.$1.height, greaterThan(slot.$2.height!));
      }
    });

    test('Urdu weights are named on the variable axis', () {
      final bold = AppTheme.light(locale: _urdu).textTheme.labelSmall!;

      expect(bold.fontVariations, isNotEmpty);
      expect(bold.fontVariations!.single.axis, 'wght');
      expect(bold.fontVariations!.single.value, inInclusiveRange(400, 700));
    });

    test('both scales ride on the theme in light and dark', () {
      for (final theme in [
        AppTheme.light(locale: _english),
        AppTheme.dark(locale: _english),
        AppTheme.light(locale: _urdu),
        AppTheme.dark(locale: _urdu),
      ]) {
        final typography = theme.extension<AppTypography>();
        expect(typography, isNotNull);
        expect(typography!.urdu.bodyLarge!.fontFamily, AppTheme.urduFamily);
        expect(typography.latin.bodyLarge!.fontFamily, 'Manrope');
        expect(typography.forScript(urduScript: true).bodyLarge!.fontFamily,
            AppTheme.urduFamily);
      }
    });

    test('long-form reading style loosens Latin but not Nastaliq', () {
      final typography =
          AppTheme.light(locale: _english).extension<AppTypography>()!;

      expect(typography.readingBody(urduScript: false)!.height, 1.7);
      expect(typography.readingBody(urduScript: true)!.fontFamily,
          AppTheme.urduFamily);
      expect(typography.readingBody(urduScript: true)!.height,
          typography.urdu.bodyLarge!.height);
    });

    test('colours come from the scheme, so both brightnesses stay legible', () {
      final light = AppTheme.light(locale: _urdu);
      final dark = AppTheme.dark(locale: _urdu);

      expect(light.textTheme.bodyMedium!.color, light.colorScheme.onSurface);
      expect(dark.textTheme.bodyMedium!.color, dark.colorScheme.onSurface);
      expect(light.textTheme.bodyMedium!.color,
          isNot(dark.textTheme.bodyMedium!.color));
    });
  });

  group('application', () {
    Future<void> pump(WidgetTester tester, Locale locale, Widget child,
        {ThemeMode mode = ThemeMode.light}) async {
      await tester.pumpWidget(TestApp(
        theme: AppTheme.light(locale: locale),
        darkTheme: AppTheme.dark(locale: locale),
        themeMode: mode,
        locale: locale,
        home: child,
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('an Urdu locale lays out right to left', (tester) async {
      late TextDirection direction;
      await pump(
        tester,
        _urdu,
        Builder(builder: (context) {
          direction = Directionality.of(context);
          return const Text('قضا');
        }),
      );

      expect(direction, TextDirection.rtl);
    });

    testWidgets('an English locale stays left to right', (tester) async {
      late TextDirection direction;
      await pump(
        tester,
        _english,
        Builder(builder: (context) {
          direction = Directionality.of(context);
          return const Text('Qaza');
        }),
      );

      expect(direction, TextDirection.ltr);
    });

    testWidgets('screens, dialogs, buttons and fields all inherit Nastaliq',
        (tester) async {
      late ThemeData theme;
      await pump(
        tester,
        _urdu,
        Scaffold(
          appBar: AppBar(title: const Text('ترتیبات')),
          body: Builder(builder: (context) {
            theme = Theme.of(context);
            return const TextField(
                decoration: InputDecoration(labelText: 'تاریخ'));
          }),
        ),
      );

      // Every component style the app relies on is derived from textTheme, so
      // one assertion per surface is enough to prove the whole chain.
      expect(theme.textTheme.bodyMedium!.fontFamily, AppTheme.urduFamily);
      expect(theme.appBarTheme.titleTextStyle!.fontFamily, AppTheme.urduFamily);
      expect(theme.dialogTheme.titleTextStyle!.fontFamily, AppTheme.urduFamily);
      expect(
          theme.dialogTheme.contentTextStyle!.fontFamily, AppTheme.urduFamily);
      expect(theme.inputDecorationTheme.labelStyle!.fontFamily,
          AppTheme.urduFamily);
      expect(theme.chipTheme.labelStyle!.fontFamily, AppTheme.urduFamily);
      final filled =
          theme.filledButtonTheme.style!.textStyle!.resolve(<WidgetState>{});
      expect(filled!.fontFamily, AppTheme.urduFamily);
      final navigation =
          theme.navigationBarTheme.labelTextStyle!.resolve(<WidgetState>{});
      expect(navigation!.fontFamily, AppTheme.urduFamily);
    });

    testWidgets('Urdu renders without overflow in light and dark',
        (tester) async {
      const paragraph =
          'قضا نمازوں کی ادائیگی کے بارے میں تفصیلی وضاحت اور ضروری مسائل۔';
      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        await pump(
          tester,
          _urdu,
          const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: Column(children: [Text(paragraph), Text('قضا نماز')]),
            ),
          ),
          mode: mode,
        );

        expect(tester.takeException(), isNull, reason: 'mode $mode');
        // A single line must occupy the taller Nastaliq line box, otherwise
        // the cascade is being clipped.
        final line = tester.getSize(find.text('قضا نماز'));
        expect(line.height, greaterThan(14 * 1.9), reason: 'mode $mode');
      }
    });
  });

  group('bilingual content', () {
    testWidgets('an Urdu article uses Nastaliq inside an English interface',
        (tester) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          knowledgeBaseRepositoryProvider.overrideWithValue(
              InMemoryKnowledgeBaseRepository([_masalaArticle])),
        ],
        child: TestApp(
          theme: AppTheme.light(locale: _english),
          locale: _english,
          home: const KnowledgeArticleDetailPage(articleId: 'masala_001'),
        ),
      ));
      await tester.pumpAndSettle();

      // The interface is English, so the article opens in English.
      expect(tester.widget<Text>(find.text('A masala')).style!.fontFamily,
          isNot(AppTheme.urduFamily));

      await tester.tap(find.text('اردو'));
      await tester.pumpAndSettle();

      expect(
          tester.widget<Text>(find.text('قضا نماز کا مسئلہ')).style!.fontFamily,
          AppTheme.urduFamily);
      expect(tester.widget<Text>(find.text('مختصر خلاصہ')).style!.fontFamily,
          AppTheme.urduFamily);
      final body =
          tester.widget<SelectableText>(find.byType(SelectableText).first);
      expect(body.style!.fontFamily, AppTheme.urduFamily);
    });
  });
}
