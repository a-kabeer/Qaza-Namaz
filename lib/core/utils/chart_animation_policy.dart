import 'package:flutter/material.dart';

/// Keeps built-in chart transitions subtle and consistent across the app.
class ChartAnimationPolicy {
  const ChartAnimationPolicy._();

  static const duration = Duration(milliseconds: 240);
  static const curve = Curves.easeOutCubic;

  /// Honors Flutter's platform "disable animations" accessibility preference.
  static Duration durationFor(BuildContext context) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }
}
