import 'package:flutter_test/flutter_test.dart';

import 'knowledge_base_parser.dart';

void main() {
  const parser = KnowledgeBaseParser();

  test('parses an empty version 1 dataset', () {
    final articles = parser.parse(
      '{"schemaVersion":1,"articles":[]}',
    );
    expect(articles, isEmpty);
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
