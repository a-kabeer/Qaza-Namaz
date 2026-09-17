class KnowledgeReference {
  const KnowledgeReference({
    required this.source,
    this.citation,
    this.url,
  });

  final String source;
  final String? citation;
  final String? url;
}
