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
