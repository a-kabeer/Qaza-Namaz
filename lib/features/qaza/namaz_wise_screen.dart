import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/prayer_types.dart';
import '../../core/widgets/components.dart';
import 'pending_dates_screen.dart';

class NamazWiseScreen extends ConsumerWidget {
  const NamazWiseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageScaffold(
        title: 'Namaz-wise',
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text('Choose a prayer', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Select one prayer to review its pending dates and complete multiple records together.'),
              const SizedBox(height: 18),
              for (final prayer in PrayerType.values)
                PrayerTile(
                  prayer: prayer,
                  subtitle: prayer.rakats,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PendingDatesScreen(prayer: prayer))),
                ),
            ],
          ),
        ),
      );
}
