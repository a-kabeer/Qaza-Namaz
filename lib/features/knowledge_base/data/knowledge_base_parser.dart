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

/// Turns the English and Urdu datasets into a base article set. The strict
/// [parseTriple] entry point adds and validates the Arabic translation.
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

  /// Parses and validates all three language datasets.
  ///
  /// The existing two-language parser remains available for its focused
  /// legacy tests; production loading must use this strict triple parser so
  /// missing Arabic articles never silently fall back to another language.
  List<KnowledgeArticle> parseTriple({
    required String english,
    required String urdu,
    required String arabic,
    String englishSource = 'english dataset',
    String urduSource = 'urdu dataset',
    String arabicSource = 'arabic dataset',
  }) {
    final baseArticles = parsePair(
      english: english,
      urdu: urdu,
      englishSource: englishSource,
      urduSource: urduSource,
    );
    final englishEntries = _entriesById(english, englishSource);
    final arabicEntries = _entriesById(arabic, arabicSource);

    final missingArabic = englishEntries.keys.toSet()
      ..removeAll(arabicEntries.keys);
    if (missingArabic.isNotEmpty) {
      throw KnowledgeBaseParseException(
        '$arabicSource: missing entries for ${_sample(missingArabic)}.',
      );
    }
    final missingEnglish = arabicEntries.keys.toSet()
      ..removeAll(englishEntries.keys);
    if (missingEnglish.isNotEmpty) {
      throw KnowledgeBaseParseException(
        '$englishSource: missing entries for ${_sample(missingEnglish)}.',
      );
    }

    final articles = <KnowledgeArticle>[];
    for (final article in baseArticles) {
      final source = englishEntries[article.id]!;
      final translated = arabicEntries[article.id]!;
      final prefix = 'entry "${article.id}"';

      for (final field in const [
        'type',
        'categoryId',
        'sortOrder',
        'isPublished',
      ]) {
        _requireSame(prefix, field, source[field], translated[field]);
      }

      final sourceReferences = _parseReferences(source['references'], prefix);
      final arabicReferences = _parseReferences(
        translated['references'],
        '$arabicSource: $prefix',
      );
      if (sourceReferences.length != arabicReferences.length ||
          !_sameReferences(sourceReferences, arabicReferences)) {
        throw KnowledgeBaseParseException(
          '$prefix: references differ between English and Arabic datasets.',
        );
      }

      articles.add(
        KnowledgeArticle(
          id: article.id,
          category: article.category,
          topicId: article.topicId,
          sortOrder: article.sortOrder,
          isPublished: article.isPublished,
          title: KnowledgeLocalizedText(
            en: article.title.en,
            ur: article.title.ur,
            ar: _requiredString(translated, 'titleAr', prefix),
          ),
          question: KnowledgeLocalizedText(
            en: article.question.en,
            ur: article.question.ur,
            ar: _requiredString(translated, 'questionAr', prefix),
          ),
          summary: KnowledgeLocalizedText(
            en: article.summary.en,
            ur: article.summary.ur,
            ar: _requiredString(translated, 'summaryAr', prefix),
          ),
          body: KnowledgeLocalizedText(
            en: article.body.en,
            ur: article.body.ur,
            ar: _requiredString(translated, 'contentAr', prefix),
          ),
          keywords: KnowledgeLocalizedKeywords(
            en: article.keywords.en,
            ur: article.keywords.ur,
            ar: _stringList(translated, 'keywordsAr', prefix),
          ),
          references: article.references,
          relatedArticleIds: article.relatedArticleIds,
        ),
      );
    }

    return List.unmodifiable(articles);
  }


  /// Parses all four bundled content datasets, including Roman Urdu.
  ///
  /// Roman Urdu is validated against the same stable IDs, shared metadata and
  /// references used by the other languages; missing text never falls back to
  /// another language.
  List<KnowledgeArticle> parseQuadruple({
    required String english,
    required String urdu,
    required String arabic,
    required String romanUrdu,
    String englishSource = 'english dataset',
    String urduSource = 'urdu dataset',
    String arabicSource = 'arabic dataset',
    String romanUrduSource = 'Roman Urdu dataset',
  }) {
    final baseArticles = parseTriple(
      english: english,
      urdu: urdu,
      arabic: arabic,
      englishSource: englishSource,
      urduSource: urduSource,
      arabicSource: arabicSource,
    );
    final englishEntries = _entriesById(english, englishSource);
    final romanEntries = _entriesById(romanUrdu, romanUrduSource);

    final missingRoman = englishEntries.keys.toSet()
      ..removeAll(romanEntries.keys);
    if (missingRoman.isNotEmpty) {
      throw KnowledgeBaseParseException(
        '$romanUrduSource: missing entries for ${_sample(missingRoman)}.',
      );
    }
    final missingEnglish = romanEntries.keys.toSet()
      ..removeAll(englishEntries.keys);
    if (missingEnglish.isNotEmpty) {
      throw KnowledgeBaseParseException(
        '$englishSource: missing entries for ${_sample(missingEnglish)}.',
      );
    }

    final articles = <KnowledgeArticle>[];
    for (final article in baseArticles) {
      final source = englishEntries[article.id]!;
      final translated = romanEntries[article.id]!;
      final prefix = 'entry "${article.id}"';

      for (final field in const [
        'type',
        'categoryId',
        'sortOrder',
        'isPublished',
      ]) {
        _requireSame(prefix, field, source[field], translated[field]);
      }

      final romanReferences = _parseReferences(
        translated['references'],
        '$romanUrduSource: $prefix',
      );
      if (article.references.length != romanReferences.length ||
          !_sameReferences(article.references, romanReferences)) {
        throw KnowledgeBaseParseException(
          '$prefix: references differ between English and Roman Urdu datasets.',
        );
      }

      articles.add(
        KnowledgeArticle(
          id: article.id,
          category: article.category,
          topicId: article.topicId,
          sortOrder: article.sortOrder,
          isPublished: article.isPublished,
          title: KnowledgeLocalizedText(
            en: article.title.en,
            ur: article.title.ur,
            ar: article.title.ar,
            urLatn: _requiredString(translated, 'titleUrLatn', prefix),
          ),
          question: KnowledgeLocalizedText(
            en: article.question.en,
            ur: article.question.ur,
            ar: article.question.ar,
            urLatn: _requiredString(translated, 'questionUrLatn', prefix),
          ),
          summary: KnowledgeLocalizedText(
            en: article.summary.en,
            ur: article.summary.ur,
            ar: article.summary.ar,
            urLatn: _requiredString(translated, 'summaryUrLatn', prefix),
          ),
          body: KnowledgeLocalizedText(
            en: article.body.en,
            ur: article.body.ur,
            ar: article.body.ar,
            urLatn: _requiredString(translated, 'contentUrLatn', prefix),
          ),
          keywords: KnowledgeLocalizedKeywords(
            en: article.keywords.en,
            ur: article.keywords.ur,
            ar: article.keywords.ar,
            urLatn: _stringList(translated, 'keywordsUrLatn', prefix),
          ),
          references: article.references,
          relatedArticleIds: article.relatedArticleIds,
        ),
      );
    }

    return List.unmodifiable(articles);
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
