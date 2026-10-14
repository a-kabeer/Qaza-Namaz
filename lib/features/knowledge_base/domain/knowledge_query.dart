import 'knowledge_article.dart';
import 'knowledge_category.dart';
import 'knowledge_language.dart';

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
    this.language = KnowledgeLanguage.english,
  });

  static const KnowledgeQuery none = KnowledgeQuery();

  final String text;
  final KnowledgeCategory? category;
  final String? topicId;

  /// The language whose fields free text is matched against.
  final KnowledgeLanguage language;

  bool get isEmpty =>
      text.trim().isEmpty && category == null && topicId == null;

  KnowledgeQuery copyWith({
    String? text,
    KnowledgeCategory? category,
    String? topicId,
    KnowledgeLanguage? language,
    bool clearCategory = false,
    bool clearTopic = false,
  }) =>
      KnowledgeQuery(
        text: text ?? this.text,
        category: clearCategory ? null : category ?? this.category,
        topicId: clearTopic ? null : topicId ?? this.topicId,
        language: language ?? this.language,
      );

  /// True when [article] satisfies every set part of the query.
  ///
  /// Free text is matched against [language] only, so results always contain
  /// the words the reader typed in the text they are shown. Arabic marks,
  /// tatweel and common alef/ya variants are normalized for easier searching.
  bool matches(KnowledgeArticle article) {
    if (category != null && article.category != category) return false;
    if (topicId != null && article.topicId != topicId) return false;

    final needle = _normalizeSearchText(text);
    if (needle.isEmpty) return true;
    final searchable = article.searchableTextFor(
      urdu: language.isUrdu,
      arabic: language.isArabic,
    );
    return _normalizeSearchText(searchable).contains(needle);
  }

  static final RegExp _arabicMarks = RegExp(
    r'[\\u0610-\\u061A\\u064B-\\u065F\\u0670\\u06D6-\\u06ED]',
  );
  static final RegExp _alefVariants = RegExp(r'[أإآٱ]');

  static String _normalizeSearchText(String value) => value
      .toLowerCase()
      .replaceAll(_arabicMarks, '')
      .replaceAll('ـ', '')
      .replaceAll(_alefVariants, 'ا')
      .replaceAll('ى', 'ي');

  @override
  bool operator ==(Object other) =>
      other is KnowledgeQuery &&
      other.text == text &&
      other.category == category &&
      other.topicId == topicId &&
      other.language == language;

  @override
  int get hashCode => Object.hash(text, category, topicId, language);
}
