import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/knowledge_article.dart';
import '../domain/knowledge_category.dart';
import '../domain/knowledge_localized_text.dart';
import '../domain/knowledge_reference.dart';

class KnowledgeBaseParseException implements Exception {
  const KnowledgeBaseParseException(this.message);

  final String message;

  @override
  String toString() => 'KnowledgeBaseParseException: $message';
}

class KnowledgeBaseParser {
  const KnowledgeBaseParser();

  Future<List<KnowledgeArticle>> loadAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    return parse(raw, source: assetPath);
  }

  List<KnowledgeArticle> parse(String raw, {String source = 'dataset'}) {
    final decoded = _decodeObject(raw, source);
    final version = decoded['schemaVersion'];
    if (version != 1) {
      throw KnowledgeBaseParseException(
        '$source: unsupported schemaVersion "$version"; expected 1.',
      );
    }

    final articles = decoded['articles'];
    if (articles is! List) {
      throw KnowledgeBaseParseException('$source: "articles" must be an array.');
    }

    return [
      for (var index = 0; index < articles.length; index++)
        _parseArticle(articles[index], source: source, index: index),
    ];
  }

  Map<String, dynamic> _decodeObject(String raw, String source) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        throw const FormatException('root must be an object');
      }
      return Map<String, dynamic>.from(decoded);
    } on FormatException catch (error) {
      throw KnowledgeBaseParseException('$source: invalid JSON (${error.message}).');
    }
  }

  KnowledgeArticle _parseArticle(
    Object value, {
    required String source,
    required int index,
  }) {
    if (value is! Map) {
      throw KnowledgeBaseParseException('$source: article[$index] must be an object.');
    }
    final map = Map<String, dynamic>.from(value);
    final prefix = '$source: article[$index]';

    final id = _requiredString(map, 'id', prefix);
    final slug = _requiredString(map, 'slug', prefix);
    final categoryValue = _requiredString(map, 'category', prefix);
    final sortOrder = _requiredInt(map, 'sortOrder', prefix);

    if (!_kebabCase.hasMatch(id) || !_kebabCase.hasMatch(slug)) {
      throw KnowledgeBaseParseException('$prefix: id and slug must use kebab-case.');
    }
    if (sortOrder < 0) {
      throw KnowledgeBaseParseException('$prefix: sortOrder must be non-negative.');
    }

    final category = KnowledgeCategory.values.where(
      (item) => item.name == categoryValue,
    );
    if (category.length != 1) {
      throw KnowledgeBaseParseException('$prefix: invalid category "$categoryValue".');
    }

    return KnowledgeArticle(
      id: id,
      slug: slug,
      category: category.single,
      sortOrder: sortOrder,
      title: _parseLocalizedText(map['title'], 'title', prefix),
      summary: _parseLocalizedText(map['summary'], 'summary', prefix),
      body: _parseLocalizedText(map['body'], 'body', prefix),
      tags: _parseStringList(map['tags'], 'tags', prefix, unique: true),
      references: _parseReferences(map['references'], prefix),
      relatedArticleIds: _parseStringList(
        map['relatedArticleIds'],
        'relatedArticleIds',
        prefix,
      ),
    );
  }

  KnowledgeLocalizedText _parseLocalizedText(
    Object? value,
    String field,
    String prefix,
  ) {
    if (value is! Map) {
      throw KnowledgeBaseParseException('$prefix: "$field" must be an object.');
    }
    final map = Map<String, dynamic>.from(value);
    return KnowledgeLocalizedText(
      ur: _requiredString(map, 'ur', '$prefix.$field'),
      en: _requiredString(map, 'en', '$prefix.$field'),
    );
  }

  List<KnowledgeReference> _parseReferences(Object? value, String prefix) {
    if (value is! List) {
      throw KnowledgeBaseParseException('$prefix: "references" must be an array.');
    }
    return [
      for (var index = 0; index < value.length; index++)
        _parseReference(value[index], '$prefix.references[$index]'),
    ];
  }

  KnowledgeReference _parseReference(Object? value, String prefix) {
    if (value is! Map) {
      throw KnowledgeBaseParseException('$prefix must be an object.');
    }
    final map = Map<String, dynamic>.from(value);
    final url = map['url'];
    if (url != null && url is! String) {
      throw KnowledgeBaseParseException('$prefix.url must be a string or null.');
    }
    final citation = map['citation'];
    if (citation != null && citation is! String) {
      throw KnowledgeBaseParseException('$prefix.citation must be a string or null.');
    }
    return KnowledgeReference(
      source: _requiredString(map, 'source', prefix),
      citation: citation as String?,
      url: url as String?,
    );
  }

  List<String> _parseStringList(
    Object? value,
    String field,
    String prefix, {
    bool unique = false,
  }) {
    if (value is! List || value.any((item) => item is! String)) {
      throw KnowledgeBaseParseException('$prefix: "$field" must be an array of strings.');
    }
    final result = List<String>.from(value);
    if (unique && result.toSet().length != result.length) {
      throw KnowledgeBaseParseException('$prefix: "$field" must contain unique values.');
    }
    return result;
  }

  String _requiredString(Map<String, dynamic> map, String field, String prefix) {
    final value = map[field];
    if (value is! String || value.trim().isEmpty) {
      throw KnowledgeBaseParseException('$prefix: "$field" must be a non-empty string.');
    }
    return value.trim();
  }

  int _requiredInt(Map<String, dynamic> map, String field, String prefix) {
    final value = map[field];
    if (value is! int) {
      throw KnowledgeBaseParseException('$prefix: "$field" must be an integer.');
    }
    return value;
  }

  static final RegExp _kebabCase = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');
}
