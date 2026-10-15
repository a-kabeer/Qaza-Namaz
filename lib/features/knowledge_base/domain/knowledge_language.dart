import 'package:flutter/material.dart';

/// The language the Guidance page renders its article content in.
///
/// This remains independent of the app interface locale: a reader can use the
/// app in English and choose Roman Urdu for articles, for example.
enum KnowledgeLanguage {
  urdu,
  romanUrdu,
  english,
  arabic;

  /// True only for Urdu Nastaleeq text, not Roman Urdu.
  bool get isUrdu => this == KnowledgeLanguage.urdu;
  bool get isRomanUrdu => this == KnowledgeLanguage.romanUrdu;
  bool get isArabic => this == KnowledgeLanguage.arabic;

  bool get isRightToLeft => isUrdu || isArabic;

  TextDirection get direction =>
      isRightToLeft ? TextDirection.rtl : TextDirection.ltr;

  TextAlign get textAlign => isRightToLeft ? TextAlign.right : TextAlign.left;

  /// Stable value persisted for this Guidance content choice.
  String get code => switch (this) {
        KnowledgeLanguage.urdu => 'ur',
        KnowledgeLanguage.romanUrdu => 'ur_Latn',
        KnowledgeLanguage.english => 'en',
        KnowledgeLanguage.arabic => 'ar',
      };

  /// BCP 47 base language passed to the shared selector.
  String get selectorLanguageCode =>
      isRomanUrdu ? 'ur' : code;

  /// Script subtag used by the shared selector to choose LTR Latin typography.
  String? get scriptCode => isRomanUrdu ? 'Latn' : null;

  static KnowledgeLanguage? fromLocale(Locale locale) {
    if (locale.languageCode.toLowerCase() == 'ur' &&
        locale.scriptCode?.toLowerCase() == 'latn') {
      return KnowledgeLanguage.romanUrdu;
    }
    return fromCode(locale.languageCode);
  }

  static KnowledgeLanguage? fromCode(String? code) {
    switch (code?.replaceAll('-', '_').toLowerCase()) {
      case 'ur_latn':
        return KnowledgeLanguage.romanUrdu;
      case 'ur':
        return KnowledgeLanguage.urdu;
      case 'en':
        return KnowledgeLanguage.english;
      case 'ar':
        return KnowledgeLanguage.arabic;
      default:
        return null;
    }
  }
}
