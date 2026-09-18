/// The two sections of the Knowledge Base.
///
/// These are the dataset's `type` values: a masala is a ruling, a mugalata is
/// a misconception being corrected.
enum KnowledgeCategory {
  masail,
  mugalat;

  /// The dataset spelling for this section.
  String get datasetType => switch (this) {
        KnowledgeCategory.masail => 'masala',
        KnowledgeCategory.mugalat => 'mugalata',
      };

  /// Resolves a dataset `type` value, or null when it is not one we know.
  static KnowledgeCategory? fromDatasetType(String value) {
    for (final category in KnowledgeCategory.values) {
      if (category.datasetType == value) return category;
    }
    return null;
  }
}
