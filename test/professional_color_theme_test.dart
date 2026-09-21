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

    expect(scheme.primary, const Color(0xFF2E7D5B));
    expect(scheme.secondary, const Color(0xFF6B8576));
    expect(scheme.tertiary, const Color(0xFFA78BFA));
    expect(scheme.surface, const Color(0xFFFAFDF9));
    expect(scheme.onSurface, const Color(0xFF0F172A));
    expect(contrast(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(4.5));
  });

  test('production dark theme exposes the Qaza brand palette', () {
    final scheme = AppTheme.dark().colorScheme;

    expect(scheme.primary, const Color(0xFF63D8A0));
    expect(scheme.secondary, const Color(0xFF8FAF9F));
    expect(scheme.tertiary, const Color(0xFFB59AFF));
    expect(scheme.surface, const Color(0xFF081612));
    expect(scheme.onSurface, const Color(0xFFF1F8F4));
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

  test('chart theme exposes the complete prayer series palette', () {
    final light = AppTheme.light().extension<AppChartColors>()!;
    final dark = AppTheme.dark().extension<AppChartColors>()!;

    expect(light.fajr, const Color(0xFF39B982));
    expect(light.zuhr, const Color(0xFFFF9248));
    expect(light.asr, const Color(0xFFFFC94D));
    expect(light.maghrib, const Color(0xFF46C6B8));
    expect(light.isha, const Color(0xFF4C9FF5));
    expect(light.witr, const Color(0xFF9B5DE5));
    expect(light.completed, const Color(0xFF22C55E));
    expect(light.pending, const Color(0xFFEF4444));
    expect(light.total, const Color(0xFFCBD5E1));
    expect(light.primary, const Color(0xFF2E7D5B));
    expect(dark.primary, const Color(0xFF63D8A0));
    expect(dark.track, const Color(0xFF20362E));
  });
}

