import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/data/local/database/app_database.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_language.dart';
import 'package:qaza_namaz/features/knowledge_base/presentation/providers/knowledge_base_providers.dart';

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

    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(second.read(knowledgeLanguageProvider), KnowledgeLanguage.urdu);
  });
}
