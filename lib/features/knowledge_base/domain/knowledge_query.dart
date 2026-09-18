import 'knowledge_article.dart';
import 'knowledge_category.dart';

/// A Knowledge Base query: free text, section, and topic.
///
/// Expressed as a value object so the same query can be built by a provider,
/// passed to the repository, and asserted in a test without any of them
/// restating the matching rules.
class KnowledgeQuery {
  const KnowledgeQuery({
    this.text = '',
    this.category,
    this.topicId,
  });

  static const KnowledgeQuery none = KnowledgeQuery();

  final String text;
  final KnowledgeCategory? category;
  final String? topicId;

  bool get isEmpty =>
      text.trim().isEmpty && category == null && topicId == null;

  KnowledgeQuery copyWith({
    String? text,
    KnowledgeCategory? category,
    String? topicId,
    bool clearCategory = false,
    bool clearTopic = false,
  }) =>
      KnowledgeQuery(
        text: text ?? this.text,
        category: clearCategory ? null : category ?? this.category,
        topicId: clearTopic ? null : topicId ?? this.topicId,
      );

  /// True when [article] satisfies every set part of the query.
  ///
  /// Free text matches on either language, so a reader searching in Urdu finds
  /// an article they first saw in English and the other way round.
  bool matches(KnowledgeArticle article) {
    if (category != null && article.category != category) return false;
    if (topicId != null && article.topicId != topicId) return false;
    final needle = text.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return article.searchableText.contains(needle);
  }

  @override
  bool operator ==(Object other) =>
      other is KnowledgeQuery &&
      other.text == text &&
      other.category == category &&
      other.topicId == topicId;

  @override
  int get hashCode => Object.hash(text, category, topicId);
}
