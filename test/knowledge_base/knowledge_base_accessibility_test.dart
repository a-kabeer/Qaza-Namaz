import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/knowledge_base/presentation/knowledge_base_page.dart';
import 'package:qaza_namaz/features/knowledge_base/presentation/providers/knowledge_base_providers.dart';

import '../support/test_app.dart';
import 'support/knowledge_fixtures.dart';

void main() {
  final article = knowledgeArticle(
    id: 'masala_001',
    titleEn: 'Accessible title',
    titleUr: 'قابل رسائی عنوان',
    summaryEn: 'Accessible summary',
    summaryUr: 'قابل رسائی خلاصہ',
    bodyEn: 'Accessible body',
    bodyUr: 'قابل رسائی متن',
    keywordsEn: const ['accessibility'],
  );

  Widget host({Widget Function(Widget)? wrap}) {
    const page = TestApp(home: KnowledgeBasePage());
    return ProviderScope(
      overrides: [
        knowledgeBaseRepositoryProvider.overrideWithValue(
          InMemoryKnowledgeBaseRepository([article]),
        ),
      ],
      child: wrap == null ? page : wrap(page),
    );
  }

  testWidgets('article card exposes a useful semantic label', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsLabel('Accessible title. Accessible summary'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('article list remains renderable at large text scale',
      (tester) async {
    await tester.pumpWidget(host(
      wrap: (page) => MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: page,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Accessible title'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
