import 'knowledge_category.dart';
import 'knowledge_language.dart';
import 'knowledge_localized_text.dart';
import 'knowledge_reference.dart';

/// One Masala or Mugalata, assembled from the English, Urdu and Arabic data.
///
/// Stable IDs and shared metadata are preserved across language datasets so
/// every translation refers to the same article.
class KnowledgeArticle {
  const KnowledgeArticle({
    required this.id,
    required this.category,
    required this.topicId,
    required this.sortOrder,
    required this.isPublished,
    required this.title,
    required this.question,
    required this.summary,
    required this.body,
    required this.keywords,
    required this.references,
    this.relatedArticleIds = const [],
  });

  final String id;
  final KnowledgeCategory category;
  final String topicId;
  final int sortOrder;
  final bool isPublished;

  final KnowledgeLocalizedText title;
  final KnowledgeLocalizedText question;
  final KnowledgeLocalizedText summary;
  final KnowledgeLocalizedText body;
  final KnowledgeLocalizedKeywords keywords;
  final List<KnowledgeReference> references;
  final List<String> relatedArticleIds;

  /// Text that should be searchable in the currently displayed language.
  ///
  /// References remain in their authored bibliographic form so a citation can
  /// be traced back to its source. Article prose and search vocabulary come
  /// only from the selected language.
  String searchableTextFor({
    required bool urdu,
    bool arabic = false,
  }) {
    final language = arabic
        ? KnowledgeLanguage.arabic
        : urdu
            ? KnowledgeLanguage.urdu
            : KnowledgeLanguage.english;
    return [
      id,
      topicId,
      title.forLanguage(language),
      question.forLanguage(language),
      summary.forLanguage(language),
      body.forLanguage(language),
      ...keywords.forLanguage(language),
      for (final reference in references)
        '${reference.sourceName} ${reference.bookName} ${reference.author}',
    ].join(' ').toLowerCase();
  }
}
