import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Presentation density for the shared language selector.
enum LanguageSelectorLayout {
  /// A bounded selector for app bars and other compact toolbars.
  compact,

  /// An outlined selector that fills the available horizontal space.
  fullWidth,
}

/// A language that may be offered by a particular language domain.
///
/// The caller owns the list of options. Application locales should come from
/// `AppLocalizations.supportedLocales`; Knowledge options should come only from
/// the Knowledge content catalogue. This type intentionally has no provider
/// or persistence responsibilities.
@immutable
class LanguageOption<T> {
  const LanguageOption({
    required this.value,
    required this.languageCode,
    this.nativeName,
  }) : assert(languageCode != '');

  final T value;

  /// BCP 47 language code used to resolve the native display name and script.
  final String languageCode;

  /// Optional domain-specific override for the native display name.
  final String? nativeName;

  String get displayName =>
      nativeName ?? NativeLanguageNames.forCode(languageCode);
}

/// Native-script display names shared by all language-selector instances.
///
/// This catalogue is presentation-only. It does not determine which languages
/// the application or Knowledge content supports.
abstract final class NativeLanguageNames {
  static const Map<String, String> _names = <String, String>{
    'ar': 'العربية',
    'bn': 'বাংলা',
    'de': 'Deutsch',
    'en': 'English',
    'es': 'Español',
    'fa': 'فارسی',
    'fr': 'Français',
    'hi': 'हिन्दी',
    'id': 'Bahasa Indonesia',
    'ms': 'Bahasa Melayu',
    'tr': 'Türkçe',
    'ur': 'اردو',
    'zh': '中文',
  };

  /// Returns a native display name, falling back safely for an unknown code.
  static String forCode(String languageCode) =>
      _names[languageCode] ?? languageCode;
}

/// Theme-aware language selector shared by independent language domains.
///
/// This widget is deliberately controlled: the owner provides the options,
/// current value and callback, and remains responsible for state and
/// persistence. [LanguageSelectorLayout] changes presentation only.
class LanguageSelector<T> extends StatelessWidget {
  const LanguageSelector({
    required this.options,
    required this.value,
    required this.onChanged,
    this.layout = LanguageSelectorLayout.fullWidth,
    this.semanticLabel = 'Language',
    this.enabled = true,
    this.optionKeyPrefix,
    this.compactWidth = 156,
    super.key,
  }) : assert(compactWidth > 0);

  final List<LanguageOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;
  final LanguageSelectorLayout layout;
  final String semanticLabel;
  final bool enabled;

  /// When supplied, menu options receive keys like
  /// `<prefix>_<language-code>` for stable integration tests.
  final String? optionKeyPrefix;

  /// Maximum width used by the compact app-bar presentation.
  final double compactWidth;

  @override
  Widget build(BuildContext context) {
    assert(
        options.isNotEmpty, 'A language selector needs at least one option.');
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final typography = AppTypography.of(context);
    final selected = _optionFor(value);
    final currentValue = selected?.value;

    TextStyle? styleFor(LanguageOption<T> option) {
      switch (option.languageCode) {
        case 'ur':
          return typography.urdu.labelLarge;
        case 'ar':
          return typography.arabic.labelLarge;
        default:
          return theme.textTheme.labelLarge;
      }
    }

    Widget label(LanguageOption<T> option) {
      final direction =
          option.languageCode == 'ur' || option.languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr;
      return Directionality(
        textDirection: direction,
        child: Text(
          option.displayName,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: styleFor(option),
        ),
      );
    }

    final dropdown = DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: currentValue,
        isExpanded: true,
        isDense: layout == LanguageSelectorLayout.compact,
        alignment: AlignmentDirectional.centerStart,
        icon: const Icon(Icons.expand_more_rounded),
        iconSize: 20,
        iconEnabledColor: scheme.onSurfaceVariant,
        dropdownColor: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        menuMaxHeight: 360,
        itemHeight: 48,
        enableFeedback: true,
        onChanged: enabled
            ? (next) {
                if (next != null) onChanged(next);
              }
            : null,
        selectedItemBuilder: (context) => [
          for (final option in options)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: label(option),
            ),
        ],
        items: [
          for (final option in options)
            DropdownMenuItem<T>(
              key: optionKeyPrefix == null
                  ? null
                  : Key('${optionKeyPrefix}_${option.languageCode}'),
              value: option.value,
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: label(option),
                    ),
                  ),
                  if (option.value == currentValue) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );

    final presentation = layout == LanguageSelectorLayout.fullWidth
        ? InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
            ),
            child: dropdown,
          )
        : dropdown;

    return Semantics(
      key: key,
      container: true,
      label: semanticLabel,
      value: selected?.displayName,
      enabled: enabled,
      child: SizedBox(
        width: layout == LanguageSelectorLayout.compact
            ? compactWidth
            : double.infinity,
        child: presentation,
      ),
    );
  }

  LanguageOption<T>? _optionFor(T candidate) {
    for (final option in options) {
      if (option.value == candidate) return option;
    }
    return null;
  }
}
