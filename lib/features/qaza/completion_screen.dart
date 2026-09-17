import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/date_display.dart';
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
    if (working || oldest == null) return;
    final completedPrayer = prayer;
    setState(() => working = true);
    try {
      final completed = await ref
          .read(qazaRecordsProvider.notifier)
          .completeOldestPending(completedPrayer);
      if (!mounted || !completed) return;
      HapticFeedback.mediumImpact();
      final remaining = ref.read(pendingForPrayerProvider(completedPrayer)).length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 900),
          content: Text(
            remaining == 0
                ? '${completedPrayer.label} Qaza completed successfully.'
                : '${completedPrayer.label} Qaza completed • $remaining remaining.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Qaza could not be completed. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ledger = ref.watch(qazaRecordsProvider);
    final prayerPending = pending;
    final record = prayerPending.isEmpty ? null : prayerPending.first;

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
              Text('Complete Qaza', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Choose a prayer and complete its oldest pending record. The next record becomes available immediately.'),
              const SizedBox(height: 20),
              DropdownButtonFormField<PrayerType>(
                value: prayer,
                decoration: const InputDecoration(labelText: 'Prayer', prefixIcon: Icon(Icons.mosque_outlined)),
                items: [
                  for (final item in PrayerType.values)
                    DropdownMenuItem(
                      value: item,
                      child: Text('${item.label} • ${ref.read(pendingForPrayerProvider(item)).length} pending'),
                    ),
                ],
                onChanged: working || ledger.isLoading
                    ? null
                    : (value) {
                        if (value != null) setState(() => prayer = value);
                      },
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: ledger.when(
                    loading: () => const LoadingState(message: 'Loading your Qaza…', padding: 24),
                    error: (_, __) => ErrorState(message: 'We could not load your Qaza ledger.', onRetry: _refresh),
                    data: (_) {
                      if (record == null) {
                        return const EmptyState(
                          icon: Icons.check_circle_outline_rounded,
                          title: 'No pending Qaza for this prayer.',
                          message: 'Choose another prayer or add a Qaza record first.',
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: scheme.primaryContainer,
                                foregroundColor: scheme.onPrimaryContainer,
                                child: Icon(prayer.icon),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${prayer.label} Qaza', style: theme.textTheme.titleLarge),
                                    Text('${prayerPending.length} pending • oldest first', style: theme.textTheme.bodySmall),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text('Original missed date', style: theme.textTheme.labelLarge),
                          const SizedBox(height: 4),
                          Text(formatAppDate(record.originalDate), style: theme.textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          const Text('Completion time is recorded separately.'),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AppButton(
                key: const Key('complete_oldest_pending'),
                label: working ? 'Completing…' : 'Complete oldest pending',
                icon: working ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                onPressed: record == null || ledger.isLoading || working ? null : _complete,
                expand: true,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Complete multiple Qaza',
                icon: Icons.playlist_add_check_rounded,
                secondary: true,
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(builder: (_) => const NamazWiseScreen()),
                ),
                expand: true,
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Completion is saved locally first and remains safe to repeat.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
