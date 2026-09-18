import 'dart:convert';

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

/// Turns the two shipped datasets into [KnowledgeArticle] records.
///
/// The Urdu and English content are authored and shipped as separate files, so
/// the parser reads both and joins them on `id`. Everything the files agree on
/// — `type`, `categoryId`, `sortOrder`, `isPublished`, `references` — must
/// actually agree: a mismatch means the two translations have drifted apart,
/// and failing loudly here beats showing a reader an Urdu answer under an
/// English question.
class KnowledgeBaseParser {
  const KnowledgeBaseParser();

  List<KnowledgeArticle> parsePair({
    required String english,
    required String urdu,
    String englishSource = 'english dataset',
    String urduSource = 'urdu dataset',
  }) {
    final englishEntries = _entriesById(english, englishSource);
    final urduEntries = _entriesById(urdu, urduSource);

    final missingUrdu = englishEntries.keys.toSet()
      ..removeAll(urduEntries.keys);
    if (missingUrdu.isNotEmpty) {
      throw KnowledgeBaseParseException(
          '$urduSource: missing entries for ${_sample(missingUrdu)}.');
    }
    final missingEnglish = urduEntries.keys.toSet()
      ..removeAll(englishEntries.keys);
    if (missingEnglish.isNotEmpty) {
      throw KnowledgeBaseParseException(
          '$englishSource: missing entries for ${_sample(missingEnglish)}.');
    }

    final articles = [
      for (final id in englishEntries.keys)
        _merge(englishEntries[id]!, urduEntries[id]!, id),
    ];
    _rejectDuplicateOrder(articles);
    return articles;
  }

  Map<String, Map<String, dynamic>> _entriesById(String raw, String source) {
    final decoded = _decodeList(raw, source);
    final result = <String, Map<String, dynamic>>{};
    for (var index = 0; index < decoded.length; index++) {
      final value = decoded[index];
      if (value is! Map) {
        throw KnowledgeBaseParseException(
            '$source: entry[$index] must be an object.');
      }
      final entry = Map<String, dynamic>.from(value);
      final id = _requiredString(entry, 'id', '$source: entry[$index]');
      if (result.containsKey(id)) {
        throw KnowledgeBaseParseException('$source: duplicate id "$id".');
      }
      result[id] = entry;
    }
    return result;
  }

  List<Object?> _decodeList(String raw, String source) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const FormatException('root must be an array of entries');
      }
      return decoded;
    } on FormatException catch (error) {
      throw KnowledgeBaseParseException(
          '$source: invalid JSON (${error.message}).');
    }
  }

  KnowledgeArticle _merge(
    Map<String, dynamic> english,
    Map<String, dynamic> urdu,
    String id,
  ) {
    final prefix = 'entry "$id"';

    final typeValue = _requiredString(english, 'type', prefix);
    final category = KnowledgeCategory.fromDatasetType(typeValue);
    if (category == null) {
      throw KnowledgeBaseParseException('$prefix: unknown type "$typeValue".');
    }
    final topicId = _requiredString(english, 'categoryId', prefix);
    final sortOrder = _requiredInt(english, 'sortOrder', prefix);
    if (sortOrder < 0) {
      throw KnowledgeBaseParseException(
          '$prefix: sortOrder must be non-negative.');
    }
    final isPublished = _requiredBool(english, 'isPublished', prefix);

    _requireSame(prefix, 'type', typeValue, urdu['type']);
    _requireSame(prefix, 'categoryId', topicId, urdu['categoryId']);
    _requireSame(prefix, 'sortOrder', sortOrder, urdu['sortOrder']);
    _requireSame(prefix, 'isPublished', isPublished, urdu['isPublished']);

    final englishReferences = _parseReferences(english['references'], prefix);
    final urduReferences = _parseReferences(urdu['references'], prefix);
    // References carry bibliographic metadata rather than prose, so the two
    // files ship them identically; treating a divergence as an error keeps a
    // silently half-updated citation from reaching a reader.
    if (englishReferences.length != urduReferences.length ||
        !_sameReferences(englishReferences, urduReferences)) {
      throw KnowledgeBaseParseException(
          '$prefix: references differ between the two datasets.');
    }

    return KnowledgeArticle(
      id: id,
      category: category,
      topicId: topicId,
      sortOrder: sortOrder,
      isPublished: isPublished,
      title: _pair(english, urdu, 'title', prefix),
      question: _pair(english, urdu, 'question', prefix),
      summary: _pair(english, urdu, 'summary', prefix),
      body: _pair(english, urdu, 'content', prefix),
      keywords: KnowledgeLocalizedKeywords(
        en: _stringList(english, 'keywordsEn', prefix),
        ur: _stringList(urdu, 'keywordsUr', prefix),
      ),
      references: List.unmodifiable(englishReferences),
    );
  }

  /// Reads `<field>En` from the English entry and `<field>Ur` from the Urdu one.
  KnowledgeLocalizedText _pair(
    Map<String, dynamic> english,
    Map<String, dynamic> urdu,
    String field,
    String prefix,
  ) =>
      KnowledgeLocalizedText(
        en: _requiredString(english, '${field}En', prefix),
        ur: _requiredString(urdu, '${field}Ur', prefix),
      );

  bool _sameReferences(
      List<KnowledgeReference> english, List<KnowledgeReference> urdu) {
    for (var index = 0; index < english.length; index++) {
      if (english[index] != urdu[index]) return false;
    }
    return true;
  }

  List<KnowledgeReference> _parseReferences(Object? value, String prefix) {
    if (value is! List) {
      throw KnowledgeBaseParseException(
          '$prefix: "references" must be an array.');
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
    return KnowledgeReference(
      sourceName: _requiredString(map, 'sourceName', prefix),
      bookName: _requiredString(map, 'bookName', prefix),
      author: _requiredString(map, 'author', prefix),
    );
  }

  List<String> _stringList(
      Map<String, dynamic> map, String field, String prefix) {
    final value = map[field];
    if (value is! List || value.any((item) => item is! String)) {
      throw KnowledgeBaseParseException(
          '$prefix: "$field" must be an array of strings.');
    }
    return List.unmodifiable(value.cast<String>());
  }

  void _rejectDuplicateOrder(List<KnowledgeArticle> articles) {
    final seen = <String>{};
    for (final article in articles) {
      final key = '${article.category.name}/${article.sortOrder}';
      if (!seen.add(key)) {
        throw KnowledgeBaseParseException(
            'sortOrder ${article.sortOrder} is used twice in '
            '${article.category.name}.');
      }
    }
  }

  void _requireSame(
      String prefix, String field, Object expected, Object? actual) {
    if (actual != expected) {
      throw KnowledgeBaseParseException(
          '$prefix: "$field" is "$actual" in the Urdu dataset but "$expected" '
          'in the English one.');
    }
  }

  String _requiredString(
      Map<String, dynamic> map, String field, String prefix) {
    final value = map[field];
    if (value is! String || value.trim().isEmpty) {
      throw KnowledgeBaseParseException(
          '$prefix: "$field" must be a non-empty string.');
    }
    return value.trim();
  }

  int _requiredInt(Map<String, dynamic> map, String field, String prefix) {
    final value = map[field];
    if (value is! int) {
      throw KnowledgeBaseParseException(
          '$prefix: "$field" must be an integer.');
    }
    return value;
  }

  bool _requiredBool(Map<String, dynamic> map, String field, String prefix) {
    final value = map[field];
    if (value is! bool) {
      throw KnowledgeBaseParseException('$prefix: "$field" must be a boolean.');
    }
    return value;
  }

  String _sample(Iterable<String> ids) {
    final sorted = ids.toList()..sort();
    return sorted.length <= 3
        ? sorted.join(', ')
        : '${sorted.take(3).join(', ')} and ${sorted.length - 3} more';
  }
}
