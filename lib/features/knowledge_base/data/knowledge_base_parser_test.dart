import 'package:flutter_test/flutter_test.dart';

import '../domain/knowledge_category.dart';
import 'knowledge_base_parser.dart';

void main() {
  const parser = KnowledgeBaseParser();

  test('parses an empty version 1 dataset', () {
    final articles = parser.parse(
      '{"schemaVersion":1,"articles":[]}',
    );
    expect(articles, isEmpty);
  });

  test('parses a valid kebab-case article', () {
    final articles = parser.parse(
      '{'
      '"schemaVersion":1,'
      '"articles":[{'
      '"id":"valid-article-1",'
      '"slug":"valid-article-1",'
      '"category":"masail",'
      '"sortOrder":1,'
      '"title":{"ur":"عنوان","en":"Title"},'
      '"summary":{"ur":"خلاصہ","en":"Summary"},'
      '"body":{"ur":"متن","en":"Body"},'
      '"tags":["tag"],'
      '"references":[],'
      '"relatedArticleIds":[]'
      '}]'
      '}',
    );

    expect(articles, hasLength(1));
    expect(articles.single.id, 'valid-article-1');
    expect(articles.single.category, KnowledgeCategory.masail);
  });

  test('rejects an unsupported schema version', () {
    expect(
      () => parser.parse('{"schemaVersion":2,"articles":[]}'),
      throwsA(isA<KnowledgeBaseParseException>()),
    );
  });

  test('rejects malformed article data', () {
    expect(
      () => parser.parse(
        '{"schemaVersion":1,"articles":[{"id":"Bad ID"}]}',
      ),
      throwsA(isA<KnowledgeBaseParseException>()),
    );
  });
}
