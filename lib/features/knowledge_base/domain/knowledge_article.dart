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

  /// Everything a free-text search should look at, for one language.
  ///
  /// Searching the other language's text would return an article whose visible
  /// title and summary contain nothing the reader typed, so the language-bearing
  /// fields are taken from the chosen side only. The id, the topic and the
  /// bibliographic references carry no language and appear identically in both
  /// datasets, so they stay searchable either way.
  ///
  /// Lives on the article rather than in a provider so search behaves the same
  /// wherever it is invoked from.
  String searchableTextFor({required bool urdu}) => [
        id,
        topicId,
        urdu ? title.ur : title.en,
        urdu ? question.ur : question.en,
        urdu ? summary.ur : summary.en,
        urdu ? body.ur : body.en,
        ...(urdu ? keywords.ur : keywords.en),
        for (final reference in references)
          '${reference.sourceName} ${reference.bookName} ${reference.author}',
      ].join(' ').toLowerCase();
}
