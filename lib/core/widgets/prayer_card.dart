import 'package:flutter/material.dart';

import '../../core/constants/prayer_types.dart';

class PrayerCard extends StatelessWidget {
  const PrayerCard({
    super.key,
    required this.prayer,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final PrayerType prayer;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(child: Icon(prayer.icon)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(prayer.label, style: theme.textTheme.titleMedium),
                if (subtitle != null)
                  Text(subtitle!, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: onTap == null
          ? content
          : InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: content,
            ),
    );
  }
}

extension PrayerTypeVisuals on PrayerType {
  IconData get icon => switch (this) {
        PrayerType.fajr => Icons.wb_twilight_rounded,
        PrayerType.zuhr => Icons.wb_sunny_rounded,
        PrayerType.asr => Icons.wb_sunny_outlined,
        PrayerType.maghrib => Icons.nights_stay_outlined,
        PrayerType.isha => Icons.dark_mode_outlined,
        PrayerType.witr => Icons.brightness_3_outlined,
      };

  String get rakats => switch (this) {
        PrayerType.fajr => 'Fajr • 2 Rakat Fard',
        PrayerType.zuhr => 'Zuhr • 4 Rakat Fard',
        PrayerType.asr => 'Asr • 4 Rakat Fard',
        PrayerType.maghrib => 'Maghrib • 3 Rakat Fard',
        PrayerType.isha => 'Isha • 4 Rakat Fard',
        PrayerType.witr => 'Witr • 3 Rakat Wajib • Independent',
      };
}
