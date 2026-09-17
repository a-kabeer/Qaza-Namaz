import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/knowledge_base/data/bundled_knowledge_base_repository.dart';
import 'package:qaza_namaz/features/knowledge_base/data/knowledge_base_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled dataset is valid and deterministic', () async {
    final raw = await rootBundle.loadString(
      BundledKnowledgeBaseRepository.assetPath,
    );
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final articles = decoded['articles'] as List<dynamic>;

    final parsed = const KnowledgeBaseParser().parse(
      raw,
      source: BundledKnowledgeBaseRepository.assetPath,
    );

    expect(decoded['schemaVersion'], 1);
    expect(parsed.length, articles.length);
    expect(parsed.map((article) => article.id).toSet().length, parsed.length);
    expect(parsed.map((article) => article.slug).toSet().length, parsed.length);
    expect(
      parsed.every((article) => article.title.isComplete),
      isTrue,
    );
    expect(
      parsed.every((article) => article.summary.isComplete),
      isTrue,
    );
    expect(
      parsed.every((article) => article.body.isComplete),
      isTrue,
    );
  });
}
