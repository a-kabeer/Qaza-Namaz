import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/knowledge_category.dart';
import 'bundled_knowledge_base_repository.dart';

class _MemoryAssetBundle extends CachingAssetBundle {
  _MemoryAssetBundle(this._assets);

  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async {
    final value = _assets[key];
    if (value == null) {
      throw FlutterError('Missing test asset: $key');
    }
    final bytes = Uint8List.fromList(utf8.encode(value));
    return ByteData.sublistView(bytes);
  }
}

void main() {
  test('loads, sorts, filters, and caches bundled articles', () async {
    final bundle = _MemoryAssetBundle({
      BundledKnowledgeBaseRepository.assetPath: jsonEncode({
        'schemaVersion': 1,
        'articles': [
          {
            'id': 'masail-two',
            'slug': 'masail-two',
            'category': 'masail',
            'sortOrder': 2,
            'title': {'ur': 'دو', 'en': 'Two'},
            'summary': {'ur': 'خلاصہ', 'en': 'Summary'},
            'body': {'ur': 'متن', 'en': 'Body'},
            'tags': ['two'],
            'references': [],
            'relatedArticleIds': [],
          },
          {
            'id': 'masail-one',
            'slug': 'masail-one',
            'category': 'masail',
            'sortOrder': 1,
            'title': {'ur': 'ایک', 'en': 'One'},
            'summary': {'ur': 'خلاصہ', 'en': 'Summary'},
            'body': {'ur': 'متن', 'en': 'Body'},
            'tags': ['one'],
            'references': [],
            'relatedArticleIds': [],
          },
        ],
      }),
    });

    final repository = BundledKnowledgeBaseRepository(bundle: bundle);

    final articles = await repository.getArticles();
    expect(articles.map((article) => article.id), ['masail-one', 'masail-two']);

    final filtered = await repository.getArticlesByCategory(
      KnowledgeCategory.masail,
    );
    expect(filtered.length, 2);
    expect(await repository.getArticleById('masail-one'), isNotNull);
    expect(await repository.getArticleById('missing'), isNull);

    expect(identical(articles, await repository.getArticles()), isFalse);
  });
}
