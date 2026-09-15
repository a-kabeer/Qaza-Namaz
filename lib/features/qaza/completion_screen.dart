import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/date_display.dart';
import '../../core/widgets/prayer_card.dart';
import '../../core/widgets/state_widgets.dart';
import '../../domain/entities/qaza_record.dart';
import 'namaz_wise_screen.dart';

class CompleteQazaScreen extends ConsumerStatefulWidget {
  const CompleteQazaScreen({super.key});
  @override
  ConsumerState<CompleteQazaScreen> createState() => _CompleteQazaScreenState();
}

class _CompleteQazaScreenState extends ConsumerState<CompleteQazaScreen> {
  PrayerType prayer = PrayerType.fajr;
  bool working = false;
  List<QazaRecord> get pending => ref.watch(pendingForPrayerProvider(prayer));
  QazaRecord? get oldest => pending.isEmpty ? null : pending.first;
  Future<void> _refresh() => ref.read(qazaRecordsProvider.notifier).refresh();

  Future<void> _complete() async {
    final record = oldest;
    if (record == null || working) return;
    setState(() => working = true);
    try {
      await ref.read(qazaServiceProvider).completeRecord(userId: ref.read(requiredUserIdProvider), recordId: record.id, completedAt: DateTime.now());
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${prayer.label} Qaza completed successfully.')));
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ledger = ref.watch(qazaRecordsProvider);
    final record = oldest;
    return AppScaffold(
      title: 'Complete Qaza',
      onBack: () => Navigator.pop(context),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              Text('Complete the oldest pending record', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Qaza is completed one individual record at a time. The original missed-prayer date is preserved.'),
              const SizedBox(height: 20),
              DropdownButtonFormField<PrayerType>(
                value: prayer,
                decoration: const InputDecoration(labelText: 'Prayer', prefixIcon: Icon(Icons.mosque_outlined)),
                items: [for (final item in PrayerType.values) DropdownMenuItem(value: item, child: Text(item.label))],
                onChanged: working || ledger.isLoading ? null : (value) { if (value != null) setState(() => prayer = value); },
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: ledger.when(
                    loading: () => const LoadingState(message: 'Loading your ledger…', padding: 24),
                    error: (_, __) => ErrorState(message: 'We could not load your Qaza ledger.', onRetry: _refresh),
                    data: (_) {
                      if (record == null) {
                        return const EmptyState(icon: Icons.check_circle_outline_rounded, title: 'No pending Qaza for this prayer.', message: 'Choose another prayer or add a Qaza record first.');
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            CircleAvatar(child: Icon(prayer.icon)),
                            const SizedBox(width: 12),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${prayer.label} Qaza', style: Theme.of(context).textTheme.titleLarge),
                              Text('Oldest pending record', style: Theme.of(context).textTheme.bodySmall),
                            ])),
                          ]),
                          const SizedBox(height: 18),
                          const Text('Original missed date'),
                          const SizedBox(height: 4),
                          Text(formatAppDate(record.originalDate), style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          const Text('Completion timestamp will be recorded separately.'),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AppButton(label: working ? 'Completing...' : 'Complete oldest pending', icon: working ? Icons.hourglass_top_rounded : Icons.check_circle_rounded, onPressed: oldest == null || ledger.isLoading || working ? null : _complete, expand: true),
              const SizedBox(height: 12),
              AppButton(label: 'Open Namaz-wise completion', icon: Icons.format_list_bulleted_rounded, secondary: true, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NamazWiseScreen())), expand: true),
            ],
          ),
        ),
      ),
    );
  }
}
