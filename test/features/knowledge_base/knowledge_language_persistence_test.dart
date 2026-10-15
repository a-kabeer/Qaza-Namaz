import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_language.dart';
import 'package:qaza_namaz/features/knowledge_base/presentation/providers/knowledge_base_providers.dart';
import 'package:qaza_namaz/features/knowledge_base/presentation/widgets/knowledge_language_switcher.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Knowledge Base language is persisted in Drift, not SharedPreferences',
      () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);

    final first = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(first.dispose);

    first.read(knowledgeLanguageProvider.notifier).set(KnowledgeLanguage.urdu);
    await Future<void>.delayed(Duration.zero);

    final rows = await database
        .customSelect(
          "SELECT value FROM meta_store WHERE key = 'qaza_knowledge_language'",
        )
        .get();
    expect(rows.single.read<String>('value'), 'ur');

    final second = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(second.dispose);

    final secondNotifier = second.read(knowledgeLanguageProvider.notifier);
    await secondNotifier.restore();
    expect(second.read(knowledgeLanguageProvider), KnowledgeLanguage.urdu);
  });

  test('Roman Urdu app locale becomes the default Guidance language', () {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        localeProvider.overrideWith(_RomanUrduLocaleNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(knowledgeLanguageProvider),
      KnowledgeLanguage.romanUrdu,
    );
  });

  testWidgets(
      'Knowledge selector changes reading language without changing app locale',
      (tester) async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        localeProvider.overrideWith(_EnglishLocaleNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, child) => MaterialApp(
            locale: ref.watch(localeProvider),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: Center(child: KnowledgeLanguageSwitcher()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(localeProvider).languageCode, 'en');
    expect(
        container.read(knowledgeLanguageProvider), KnowledgeLanguage.english);

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('knowledge_language_switcher')),
        matching: find.byType(DropdownButton<KnowledgeLanguage>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    await tester.pump();

    expect(container.read(knowledgeLanguageProvider), KnowledgeLanguage.arabic);
    expect(container.read(localeProvider).languageCode, 'en');

    final rows = await database
        .customSelect(
          "SELECT value FROM meta_store WHERE key = 'qaza_knowledge_language'",
        )
        .get();
    expect(rows.single.read<String>('value'), 'ar');

    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('knowledge_language_switcher')),
        matching: find.byType(DropdownButton<KnowledgeLanguage>),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Urdu'), findsOneWidget);
    expect(find.text('Roman Urdu'), findsNothing);
    final romanUrduOption =
        find.byKey(const Key('knowledge_language_option_ur_Latn'));
    expect(romanUrduOption, findsOneWidget);
    expect(
      find.descendant(
        of: romanUrduOption,
        matching: find.text('Urdu'),
      ),
      findsOneWidget,
      reason: 'The Latin-script option must display exactly Urdu.',
    );
    expect(find.text('Roman Urdu'), findsNothing);
    await tester.tap(romanUrduOption);
    await tester.pumpAndSettle();
    await tester.pump();

    expect(find.text('Urdu'), findsOneWidget);
    expect(
      container.read(knowledgeLanguageProvider),
      KnowledgeLanguage.romanUrdu,
    );
    expect(container.read(localeProvider).languageCode, 'en');
    final romanRows = await database
        .customSelect(
          "SELECT value FROM meta_store WHERE key = 'qaza_knowledge_language'",
        )
        .get();
    expect(romanRows.single.read<String>('value'), 'ur_Latn');
    expect(tester.takeException(), isNull);
  });
}

class _EnglishLocaleNotifier extends LocaleNotifier {
  @override
  Locale build() => const Locale('en');
}

class _RomanUrduLocaleNotifier extends LocaleNotifier {
  @override
  Locale build() => const Locale.fromSubtags(
        languageCode: 'ur',
        scriptCode: 'Latn',
      );
}
