import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/features/knowledge_base/data/knowledge_base_parser.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_article.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_language.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_query.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String english;
  late String urdu;
  late String arabic;
  late String romanUrdu;
  late List<dynamic> romanEntries;

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
    romanUrdu = await rootBundle.loadString(
      'assets/knowledge_base/content/qaza_masail_mugalat_ur_Latn.json',
    );
    romanEntries = jsonDecode(romanUrdu) as List<dynamic>;
  });

  List<KnowledgeArticle> articles() =>
      const KnowledgeBaseParser().parseQuadruple(
        english: english,
        urdu: urdu,
        arabic: arabic,
        romanUrdu: romanUrdu,
      );

  test('Roman Urdu has its own script-aware identity and LTR direction', () {
    final language = KnowledgeLanguage.fromLocale(
      const Locale.fromSubtags(languageCode: 'ur', scriptCode: 'Latn'),
    );

    expect(language, KnowledgeLanguage.romanUrdu);
    expect(KnowledgeLanguage.fromCode('ur_Latn'), KnowledgeLanguage.romanUrdu);
    expect(KnowledgeLanguage.fromCode('ur-Latn'), KnowledgeLanguage.romanUrdu);
    expect(language!.code, 'ur_Latn');
    expect(language.locale.languageCode, 'ur');
    expect(language.locale.scriptCode, 'Latn');
    expect(language.selectorLanguageCode, 'ur');
    expect(language.scriptCode, 'Latn');
    expect(language.isUrdu, isFalse);
    expect(language.isRomanUrdu, isTrue);
    expect(language.direction, TextDirection.ltr);
    expect(language.textAlign, TextAlign.left);
  });

  test('all 75 Roman Urdu entries are complete and match the Urdu dataset', () {
    final decodedUrdu = jsonDecode(urdu) as List<dynamic>;
    final englishIds = (jsonDecode(english) as List<dynamic>)
        .map((entry) => (entry as Map<String, dynamic>)['id'])
        .toList();
    final urduIds = decodedUrdu
        .map((entry) => (entry as Map<String, dynamic>)['id'])
        .toList();
    final romanIds = romanEntries
        .map((entry) => (entry as Map<String, dynamic>)['id'])
        .toList();

    expect(romanEntries, hasLength(75));
    expect(romanIds, englishIds);
    expect(romanIds, urduIds);

    final parsed = articles();
    expect(parsed, hasLength(75));
    for (final article in parsed) {
      expect(article.title.urLatn.trim(), isNotEmpty, reason: article.id);
      expect(article.question.urLatn.trim(), isNotEmpty, reason: article.id);
      expect(article.summary.urLatn.trim(), isNotEmpty, reason: article.id);
      expect(article.body.urLatn.trim(), isNotEmpty, reason: article.id);
      expect(article.keywords.urLatn, isNotEmpty, reason: article.id);
      expect(article.title.isComplete, isTrue, reason: article.id);
      expect(
        RegExp(r'[\u0600-\u06FF]').hasMatch(article.body.urLatn),
        isFalse,
        reason: 'Roman Urdu body should use Latin script: ${article.id}',
      );
    }
  });

  test('search uses Roman Urdu text rather than Urdu-script article text', () {
    final article = articles().firstWhere((item) => item.id == 'masala_001');

    expect(
      const KnowledgeQuery(
        text: 'paanch',
        language: KnowledgeLanguage.romanUrdu,
      ).matches(article),
      isTrue,
    );
    expect(
      const KnowledgeQuery(
        text: 'paanch',
        language: KnowledgeLanguage.urdu,
      ).matches(article),
      isFalse,
    );
  });

  test('Roman Urdu visible text follows sentence case', () {
    const textFields = <String>[
      'titleUrLatn',
      'questionUrLatn',
      'summaryUrLatn',
      'contentUrLatn',
    ];

    for (final entry in romanEntries.cast<Map<String, dynamic>>()) {
      for (final field in textFields) {
        final value = entry[field] as String;
        final segments = value.split(RegExp(r'[.!?]+|\\r?\\n+'));
        for (final segment in segments) {
          final firstLetter = RegExp(r'[A-Za-z]').firstMatch(segment);
          if (firstLetter == null) continue;

          expect(
            firstLetter.group(0),
            firstLetter.group(0)!.toUpperCase(),
            reason: '${entry['id']} / $field must capitalize sentence beginnings',
          );
        }
      }
    }
  });

  test('quadruple parser rejects an incomplete Roman Urdu dataset', () {
    final incomplete = jsonEncode(romanEntries.take(74).toList());

    expect(
      () => const KnowledgeBaseParser().parseQuadruple(
        english: english,
        urdu: urdu,
        arabic: arabic,
        romanUrdu: incomplete,
      ),
      throwsA(isA<KnowledgeBaseParseException>()),
    );
  });
}
