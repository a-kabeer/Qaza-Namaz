import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/knowledge_base/data/knowledge_base_parser.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_article.dart';
import 'package:qaza_namaz/features/knowledge_base/domain/knowledge_category.dart';

import 'support/knowledge_fixtures.dart';

void main() {
  const parser = KnowledgeBaseParser();

  List<Map<String, dynamic>> pairFor(String language) => [
        datasetEntry(id: 'masala_001', language: language),
        datasetEntry(
            id: 'mugalata_001',
            language: language,
            type: 'mugalata',
            categoryId: 'misconceptions'),
      ];

  List<KnowledgeArticle> parse({
    List<Map<String, dynamic>>? english,
    List<Map<String, dynamic>>? urdu,
  }) =>
      parser.parsePair(
        english: jsonEncode(english ?? pairFor('en')),
        urdu: jsonEncode(urdu ?? pairFor('ur')),
      );

  test('joins the two datasets on id', () {
    final articles = parser.parsePair(
      english: jsonEncode(pairFor('en')),
      urdu: jsonEncode(pairFor('ur')),
    );

    expect(articles, hasLength(2));
    final masala = articles.first;
    expect(masala.id, 'masala_001');
    expect(masala.category, KnowledgeCategory.masail);
    expect(masala.title.en, 'Text masala_001');
    expect(masala.title.ur, 'متن masala_001');
    expect(articles.last.category, KnowledgeCategory.mugalat);
  });

  test('preserves every field the datasets carry', () {
    final article = parser
        .parsePair(
          english: jsonEncode([
            datasetEntry(
              id: 'masala_007',
              language: 'en',
              categoryId: 'sleep_forgetfulness',
              sortOrder: 7,
              references: const [
                {
                  'sourceName': 'Quran.com',
                  'bookName': "The Qur'an",
                  'author': "The Qur'an",
                }
              ],
            )
          ]),
          urdu: jsonEncode([
            datasetEntry(
              id: 'masala_007',
              language: 'ur',
              categoryId: 'sleep_forgetfulness',
              sortOrder: 7,
              references: const [
                {
                  'sourceName': 'Quran.com',
                  'bookName': "The Qur'an",
                  'author': "The Qur'an",
                }
              ],
            )
          ]),
        )
        .single;

    expect(article.id, 'masala_007');
    expect(article.topicId, 'sleep_forgetfulness');
    expect(article.sortOrder, 7);
    expect(article.isPublished, isTrue);
    expect(article.keywords.en, ['keyword']);
    expect(article.keywords.ur, ['کلیدی']);
    expect(article.references.single.sourceName, 'Quran.com');
    expect(article.references.single.bookName, "The Qur'an");
    expect(article.references.single.author, "The Qur'an");
  });

  test('keeps an unpublished entry as unpublished rather than dropping it', () {
    final article = parser
        .parsePair(
          english: jsonEncode([
            datasetEntry(id: 'masala_001', language: 'en', isPublished: false)
          ]),
          urdu: jsonEncode([
            datasetEntry(id: 'masala_001', language: 'ur', isPublished: false)
          ]),
        )
        .single;

    expect(article.isPublished, isFalse);
  });

  test('rejects an id present in only one language', () {
    expect(
      () => parse(urdu: [datasetEntry(id: 'masala_001', language: 'ur')]),
      throwsA(isA<KnowledgeBaseParseException>()),
    );
  });

  test('rejects metadata that disagrees between the two files', () {
    expect(
      () => parse(urdu: [
        datasetEntry(id: 'masala_001', language: 'ur', sortOrder: 99),
        datasetEntry(
            id: 'mugalata_001',
            language: 'ur',
            type: 'mugalata',
            categoryId: 'misconceptions'),
      ]),
      throwsA(isA<KnowledgeBaseParseException>()),
    );
  });

  test('rejects references that disagree between the two files', () {
    expect(
      () => parser.parsePair(
        english: jsonEncode([
          datasetEntry(id: 'masala_001', language: 'en', references: const [
            {'sourceName': 'A', 'bookName': 'B', 'author': 'C'}
          ])
        ]),
        urdu: jsonEncode([
          datasetEntry(id: 'masala_001', language: 'ur', references: const [
            {'sourceName': 'A', 'bookName': 'B', 'author': 'Different'}
          ])
        ]),
      ),
      throwsA(isA<KnowledgeBaseParseException>()),
    );
  });

  test('rejects an unknown type', () {
    expect(
      () => parser.parsePair(
        english: jsonEncode(
            [datasetEntry(id: 'x_1', language: 'en', type: 'unknown')]),
        urdu: jsonEncode(
            [datasetEntry(id: 'x_1', language: 'ur', type: 'unknown')]),
      ),
      throwsA(isA<KnowledgeBaseParseException>()),
    );
  });

  test('rejects a duplicate sortOrder within one section', () {
    expect(
      () => parser.parsePair(
        english: jsonEncode([
          datasetEntry(id: 'masala_001', language: 'en', sortOrder: 1),
          datasetEntry(id: 'masala_002', language: 'en', sortOrder: 1),
        ]),
        urdu: jsonEncode([
          datasetEntry(id: 'masala_001', language: 'ur', sortOrder: 1),
          datasetEntry(id: 'masala_002', language: 'ur', sortOrder: 1),
        ]),
      ),
      throwsA(isA<KnowledgeBaseParseException>()),
    );
  });

  test('rejects a duplicate id inside one file', () {
    expect(
      () => parse(english: [
        datasetEntry(id: 'masala_001', language: 'en'),
        datasetEntry(id: 'masala_001', language: 'en', sortOrder: 2),
      ]),
      throwsA(isA<KnowledgeBaseParseException>()),
    );
  });

  test('rejects a missing translation field', () {
    final broken = datasetEntry(id: 'masala_001', language: 'ur')
      ..remove('summaryUr');
    expect(
      () => parse(urdu: [broken]),
      throwsA(isA<KnowledgeBaseParseException>()),
    );
  });

  test('rejects a document that is not an array', () {
    expect(
      () => parser.parsePair(english: '{"articles":[]}', urdu: '[]'),
      throwsA(isA<KnowledgeBaseParseException>()),
    );
  });

  test('parses an empty pair', () {
    expect(parser.parsePair(english: '[]', urdu: '[]'), isEmpty);
  });
}
