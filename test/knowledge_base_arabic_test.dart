import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/features/knowledge_base/data/knowledge_base_parser.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_language.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_query.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String english;
  late String urdu;
  late String arabic;
  late List<dynamic> arabicEntries;

  setUpAll(() async {
    english = await rootBundle.loadString(
      'assets/knowledge_base/content/qaza_masail_mugalat_en.json',
    );
    urdu = await rootBundle.loadString(
      'assets/knowledge_base/content/qaza_masail_mugalat_ur.json',
    );
    arabic = await rootBundle.loadString(
      'assets/knowledge_base/content/qaza_masail_mugalat_ar.json',
    );
    arabicEntries = jsonDecode(arabic) as List<dynamic>;
  });

  test('Arabic reading language resolves its code and RTL direction', () {
    final language = KnowledgeLanguage.fromCode('ar');

    expect(language, KnowledgeLanguage.arabic);
    expect(language!.code, 'ar');
    expect(language.isArabic, isTrue);
    expect(language.direction.name, 'rtl');
    expect(language.textAlign, TextAlign.right);
  });

  test('all published articles have complete Arabic translations', () {
    final articles = const KnowledgeBaseParser().parseTriple(
      english: english,
      urdu: urdu,
      arabic: arabic,
    );

    expect(articles, hasLength(75));
    expect(articles.where((article) => article.isPublished), hasLength(75));
    expect(
      articles.where((article) => article.id.startsWith('masala_')),
      hasLength(55),
    );
    expect(
      articles.where((article) => article.id.startsWith('mugalata_')),
      hasLength(20),
    );
    for (final article in articles) {
      expect(article.title.ar.trim(), isNotEmpty, reason: article.id);
      expect(article.question.ar.trim(), isNotEmpty, reason: article.id);
      expect(article.summary.ar.trim(), isNotEmpty, reason: article.id);
      expect(article.body.ar.trim(), isNotEmpty, reason: article.id);
      expect(article.keywords.ar, isNotEmpty, reason: article.id);
      expect(article.title.isComplete, isTrue, reason: article.id);
    }
  });

  test('Arabic search matches Arabic article text, not English-only text', () {
    final articles = const KnowledgeBaseParser().parseTriple(
      english: english,
      urdu: urdu,
      arabic: arabic,
    );
    final fajr = articles.firstWhere((article) => article.id == 'masala_031');

    expect(
      const KnowledgeQuery(
        text: 'الفجر',
        language: KnowledgeLanguage.arabic,
      ).matches(fajr),
      isTrue,
    );
    expect(
      const KnowledgeQuery(
        text: 'الفجر',
        language: KnowledgeLanguage.english,
      ).matches(fajr),
      isFalse,
    );
  });

  test('the triple parser rejects an incomplete Arabic dataset', () {
    final incompleteArabic = jsonEncode(arabicEntries.take(74).toList());

    expect(
      () => const KnowledgeBaseParser().parseTriple(
        english: english,
        urdu: urdu,
        arabic: incompleteArabic,
      ),
      throwsA(isA<KnowledgeBaseParseException>()),
    );
  });
}
