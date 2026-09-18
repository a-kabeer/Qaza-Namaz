/// Bilingual content used by the Knowledge Base.
///
/// The data layer keeps Urdu and English explicit so the presentation layer
/// can choose the correct language and text direction without inspecting raw
/// JSON maps.
class KnowledgeLocalizedText {
  const KnowledgeLocalizedText({
    required this.ur,
    required this.en,
  });

  final String ur;
  final String en;

  bool get isComplete => ur.trim().isNotEmpty && en.trim().isNotEmpty;
}

/// The same pairing for the per-language keyword lists.
///
/// Keywords are not translations of one another — each language has its own
/// search vocabulary — so they are kept as two lists rather than flattened
/// into one.
class KnowledgeLocalizedKeywords {
  const KnowledgeLocalizedKeywords({
    required this.ur,
    required this.en,
  });

  static const empty = KnowledgeLocalizedKeywords(ur: [], en: []);

  final List<String> ur;
  final List<String> en;

  /// Both vocabularies, for search that should hit regardless of the language
  /// the reader typed in.
  Iterable<String> get all => [...en, ...ur];
}
