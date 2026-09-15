import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/prayer_card.dart';
import 'pending_dates_screen.dart';

class NamazWiseScreen extends ConsumerWidget {
  const NamazWiseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppScaffold(
        title: 'Namaz-wise',
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              Text('Choose a prayer', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Select one prayer to review its pending dates and complete multiple records together.'),
              const SizedBox(height: 18),
              for (final prayer in PrayerType.values)
                PrayerCard(
                  prayer: prayer,
                  subtitle: prayer.rakats,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PendingDatesScreen(prayer: prayer))),
                ),
            ],
          ),
        ),
      );
}
