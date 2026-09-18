import 'package:flutter/material.dart';

/// The language the Knowledge Base renders its content in.
///
/// Deliberately separate from the application locale: a reader may run the
/// interface in English and still want the rulings in Urdu, or the reverse.
/// Settings -> Language continues to own the interface; this owns the content.
enum KnowledgeLanguage {
  urdu,
  english;

  bool get isUrdu => this == KnowledgeLanguage.urdu;

  /// Nastaliq cascades right to left; English does not.
  TextDirection get direction => isUrdu ? TextDirection.rtl : TextDirection.ltr;

  TextAlign get textAlign => isUrdu ? TextAlign.right : TextAlign.left;

  /// The stored and locale-facing code for this language.
  String get code => isUrdu ? 'ur' : 'en';

  static KnowledgeLanguage? fromCode(String? code) => switch (code) {
        'ur' => KnowledgeLanguage.urdu,
        'en' => KnowledgeLanguage.english,
        _ => null,
      };
}
