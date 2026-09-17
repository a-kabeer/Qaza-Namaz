import 'knowledge_category.dart';
import 'knowledge_localized_text.dart';
import 'knowledge_reference.dart';

class KnowledgeArticle {
  const KnowledgeArticle({
    required this.id,
    required this.slug,
    required this.category,
    required this.sortOrder,
    required this.title,
    required this.summary,
    required this.body,
    required this.tags,
    required this.references,
    required this.relatedArticleIds,
  });

  final String id;
  final String slug;
  final KnowledgeCategory category;
  final int sortOrder;
  final KnowledgeLocalizedText title;
  final KnowledgeLocalizedText summary;
  final KnowledgeLocalizedText body;
  final List<String> tags;
  final List<KnowledgeReference> references;
  final List<String> relatedArticleIds;
}
