import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../app/providers.dart';
import '../../data/bundled_knowledge_base_repository.dart';
import '../../data/knowledge_base_repository.dart';
import '../../domain/knowledge_article.dart';
import '../../domain/knowledge_category.dart';
import '../../domain/knowledge_language.dart';
import '../../domain/knowledge_query.dart';

final knowledgeBaseRepositoryProvider = Provider<KnowledgeBaseRepository>(
  (ref) => BundledKnowledgeBaseRepository(),
);

final knowledgeBaseCategoriesProvider = Provider<List<KnowledgeCategory>>(
  (ref) => List.unmodifiable(KnowledgeCategory.values),
);

final knowledgeArticlesProvider = FutureProvider<List<KnowledgeArticle>>(
  (ref) => ref.watch(knowledgeBaseRepositoryProvider).getArticles(),
);

/// The topics actually present in the content, so the filter row never offers
/// a chip that would return nothing.
final knowledgeTopicIdsProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(knowledgeBaseRepositoryProvider).getTopicIds(),
);

/// The Knowledge Base reading language, persisted across restarts.
///
/// Until the reader picks one it follows the application language, so an app
/// running in Urdu does not open the Knowledge Base in English. Once they
/// choose, that choice wins and stops tracking Settings -> Language: an
/// explicit decision should not be silently undone by an unrelated setting.
class KnowledgeLanguageNotifier extends Notifier<KnowledgeLanguage> {
  static const String storageKey = 'qaza_knowledge_language';

  /// Held on the notifier rather than in [state] so it survives the rebuilds
  /// caused by the application locale changing.
  KnowledgeLanguage? _chosen;

  @override
  KnowledgeLanguage build() {
    final fromApp =
        KnowledgeLanguage.fromCode(ref.watch(localeProvider).languageCode) ??
            KnowledgeLanguage.english;
    if (_chosen == null) Future.microtask(restore);
    return _chosen ?? fromApp;
  }

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = KnowledgeLanguage.fromCode(prefs.getString(storageKey));
      if (stored == null) return;
      _chosen = stored;
      state = stored;
    } catch (_) {
      // An unreadable store simply leaves the application language in charge.
    }
  }

  void set(KnowledgeLanguage language) {
    _chosen = language;
    state = language;
    _persist(language);
  }

  Future<void> _persist(KnowledgeLanguage language) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, language.code);
    } catch (_) {
      // Persistence failure must not break the in-session choice.
    }
  }
}

final knowledgeLanguageProvider =
    NotifierProvider<KnowledgeLanguageNotifier, KnowledgeLanguage>(
  KnowledgeLanguageNotifier.new,
);

final knowledgeCategoryFilterProvider = StateProvider<KnowledgeCategory?>(
  (ref) => null,
);

final knowledgeTopicFilterProvider = StateProvider<String?>((ref) => null);

final knowledgeSearchQueryProvider = StateProvider<String>((ref) => '');

final knowledgeSelectedArticleIdProvider = StateProvider<String?>(
  (ref) => null,
);

/// The three filter controls, gathered into the one value the data layer takes.
final knowledgeQueryProvider = Provider<KnowledgeQuery>(
  (ref) => KnowledgeQuery(
    text: ref.watch(knowledgeSearchQueryProvider),
    category: ref.watch(knowledgeCategoryFilterProvider),
    topicId: ref.watch(knowledgeTopicFilterProvider),
  ),
);

final knowledgeFilteredArticlesProvider =
    FutureProvider<List<KnowledgeArticle>>(
  (ref) => ref
      .watch(knowledgeBaseRepositoryProvider)
      .search(ref.watch(knowledgeQueryProvider)),
);

final knowledgeArticleProvider =
    FutureProvider.family<KnowledgeArticle?, String>((ref, id) {
  return ref.watch(knowledgeBaseRepositoryProvider).getArticleById(id);
});

final selectedKnowledgeArticleProvider =
    FutureProvider<KnowledgeArticle?>((ref) async {
  final id = ref.watch(knowledgeSelectedArticleIdProvider);
  if (id == null || id.trim().isEmpty) {
    return null;
  }
  return ref.watch(knowledgeArticleProvider(id).future);
});

final knowledgeRelatedArticlesProvider =
    FutureProvider.family<List<KnowledgeArticle>, String>((ref, id) async {
  final items = await ref.watch(knowledgeArticlesProvider.future);
  final byId = <String, KnowledgeArticle>{
    for (final article in items) article.id: article,
  };

  final related = <KnowledgeArticle>[];
  for (final relatedId in byId[id]?.relatedArticleIds ?? const <String>[]) {
    final article = byId[relatedId];
    if (article != null && article.id != id) {
      related.add(article);
    }
  }
  return List.unmodifiable(related);
});
