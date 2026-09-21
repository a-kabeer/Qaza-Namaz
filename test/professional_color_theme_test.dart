import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/theme/app_theme.dart';

void main() {
  double contrast(Color first, Color second) {
    final a = first.computeLuminance();
    final b = second.computeLuminance();
    final lighter = a > b ? a : b;
    final darker = a > b ? b : a;
    return (lighter + 0.05) / (darker + 0.05);
  }

  test('production light theme exposes the Qaza brand palette', () {
    final scheme = AppTheme.light().colorScheme;

    expect(scheme.primary, const Color(0xFF1F6B4F));
    expect(scheme.secondary, const Color(0xFF8A6338));
    expect(scheme.tertiary, const Color(0xFF2E7D59));
    expect(scheme.surface, const Color(0xFFF7F9F7));
    expect(scheme.onSurface, const Color(0xFF17221D));
    expect(contrast(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(4.5));
  });

  test('production dark theme exposes the Qaza brand palette', () {
    final scheme = AppTheme.dark().colorScheme;

    expect(scheme.primary, const Color(0xFF7FD3A4));
    expect(scheme.secondary, const Color(0xFFE2B978));
    expect(scheme.tertiary, const Color(0xFF70C995));
    expect(scheme.surface, const Color(0xFF0D1512));
    expect(scheme.onSurface, const Color(0xFFEDF4F0));
    expect(contrast(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(4.5));
  });

  test('semantic status colors are distinct and theme-derived', () {
    final light = AppTheme.light().colorScheme;
    final dark = AppTheme.dark().colorScheme;

    expect(light.secondaryContainer, isNot(light.primaryContainer));
    expect(light.tertiaryContainer, isNot(light.secondaryContainer));
    expect(dark.secondaryContainer, isNot(dark.primaryContainer));
    expect(dark.tertiaryContainer, isNot(dark.secondaryContainer));
  });
}
