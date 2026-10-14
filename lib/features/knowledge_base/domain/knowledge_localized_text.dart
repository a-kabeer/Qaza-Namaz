import 'knowledge_language.dart';

/// Localized article text kept explicitly for all supported content languages.
class KnowledgeLocalizedText {
  const KnowledgeLocalizedText({
    required this.ur,
    required this.en,
    this.ar = '',
  });

  final String ur;
  final String en;
  final String ar;

  String forLanguage(KnowledgeLanguage language) => switch (language) {
        KnowledgeLanguage.urdu => ur,
        KnowledgeLanguage.english => en,
        KnowledgeLanguage.arabic => ar,
      };

  bool get isComplete =>
      ur.trim().isNotEmpty && en.trim().isNotEmpty && ar.trim().isNotEmpty;
}

/// Per-language search vocabulary. Keywords are reader vocabulary, not
/// necessarily literal translations, so each language keeps its own list.
class KnowledgeLocalizedKeywords {
  const KnowledgeLocalizedKeywords({
    required this.ur,
    required this.en,
    this.ar = const [],
  });

  static const empty = KnowledgeLocalizedKeywords(ur: [], en: [], ar: []);

  final List<String> ur;
  final List<String> en;
  final List<String> ar;

  List<String> forLanguage(KnowledgeLanguage language) => switch (language) {
        KnowledgeLanguage.urdu => ur,
        KnowledgeLanguage.english => en,
        KnowledgeLanguage.arabic => ar,
      };

  /// Combined search vocabulary for operations that intentionally search all
  /// supported language terms.
  Iterable<String> get all => [...en, ...ur, ...ar];
}
