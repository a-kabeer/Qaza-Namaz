import 'knowledge_category.dart';
import 'knowledge_localized_text.dart';
import 'knowledge_reference.dart';

/// One Masala or Mugalata, assembled from the Urdu and English datasets.
///
/// Every field the datasets carry is represented here — including [topicId],
/// [isPublished] and [sortOrder], which the application must not invent or
/// rewrite — so a record can be traced back to its source entry.
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

  /// The dataset `id`, verbatim (for example `masala_001`).
  final String id;

  /// The dataset `type`, as the section it belongs to.
  final KnowledgeCategory category;

  /// The dataset `categoryId`, verbatim (for example `sleep_forgetfulness`).
  ///
  /// Kept as the raw identifier rather than an enum so a topic added to the
  /// content later loads instead of failing validation.
  final String topicId;

  /// Display order within [category]; the datasets number each section from 1.
  final int sortOrder;

  final bool isPublished;

  final KnowledgeLocalizedText title;
  final KnowledgeLocalizedText question;
  final KnowledgeLocalizedText summary;
  final KnowledgeLocalizedText body;
  final KnowledgeLocalizedKeywords keywords;
  final List<KnowledgeReference> references;
  final List<String> relatedArticleIds;

  /// Everything a free-text search should look at, in both languages.
  ///
  /// Lives on the article rather than in a provider so search behaves the same
  /// wherever it is invoked from.
  String get searchableText => [
        id,
        topicId,
        title.en,
        title.ur,
        question.en,
        question.ur,
        summary.en,
        summary.ur,
        body.en,
        body.ur,
        ...keywords.all,
        for (final reference in references)
          '${reference.sourceName} ${reference.bookName} ${reference.author}',
      ].join(' ').toLowerCase();
}
