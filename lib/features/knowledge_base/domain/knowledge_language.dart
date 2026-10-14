import 'package:flutter/material.dart';

/// The language the Knowledge Base renders its content in.
///
/// Deliberately separate from the application locale: a reader may run the
/// interface in English and still want articles in Urdu or Arabic. Settings
/// -> Language owns the interface; this language owns article content.
enum KnowledgeLanguage {
  urdu,
  english,
  arabic;

  bool get isUrdu => this == KnowledgeLanguage.urdu;
  bool get isArabic => this == KnowledgeLanguage.arabic;

  bool get isRightToLeft => isUrdu || isArabic;

  /// Urdu Nastaliq and Arabic both read from right to left.
  TextDirection get direction =>
      isRightToLeft ? TextDirection.rtl : TextDirection.ltr;

  TextAlign get textAlign => isRightToLeft ? TextAlign.right : TextAlign.left;

  /// Stored and locale-facing language code.
  String get code => switch (this) {
        KnowledgeLanguage.urdu => 'ur',
        KnowledgeLanguage.english => 'en',
        KnowledgeLanguage.arabic => 'ar',
      };

  static KnowledgeLanguage? fromCode(String? code) => switch (code) {
        'ur' => KnowledgeLanguage.urdu,
        'en' => KnowledgeLanguage.english,
        'ar' => KnowledgeLanguage.arabic,
        _ => null,
      };
}
