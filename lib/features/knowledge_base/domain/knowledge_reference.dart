/// A source entry attached to an article.
///
/// The three fields are carried through from the dataset unchanged; none of
/// them is derived or reformatted, so a citation always reads back exactly as
/// the content author wrote it.
class KnowledgeReference {
  const KnowledgeReference({
    required this.sourceName,
    required this.bookName,
    required this.author,
  });

  final String sourceName;
  final String bookName;
  final String author;

  @override
  bool operator ==(Object other) =>
      other is KnowledgeReference &&
      other.sourceName == sourceName &&
      other.bookName == bookName &&
      other.author == author;

  @override
  int get hashCode => Object.hash(sourceName, bookName, author);
}
