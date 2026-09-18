import 'package:flutter/material.dart';

import '../constants/prayer_types.dart';

/// Icon vocabulary for the six prayers.
///
/// Prayer *names* and rakaat metadata are localized through
/// `PrayerTypeL10n` / `PrayerRakatsL10n`; only the icon lives here, because it
/// carries no language.
extension PrayerTypeVisuals on PrayerType {
  IconData get icon => switch (this) {
        PrayerType.fajr => Icons.wb_twilight_rounded,
        PrayerType.zuhr => Icons.wb_sunny_rounded,
        PrayerType.asr => Icons.wb_sunny_outlined,
        PrayerType.maghrib => Icons.nights_stay_outlined,
        PrayerType.isha => Icons.dark_mode_outlined,
        PrayerType.witr => Icons.brightness_3_outlined,
      };
}
