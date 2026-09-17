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

  AsyncValue<QazaRecord?> get oldestState => ref.watch(oldestPendingProvider(prayer));
  QazaRecord? get oldest => oldestState.valueOrNull;

  Future<void> _refresh() async {
    ref.invalidate(oldestPendingProvider(prayer));
    ref.invalidate(progressSummaryProvider);
    await ref.read(oldestPendingProvider(prayer).future);
  }

  Future<void> _complete() async {
    final record = oldest;
    if (working || record == null) return;
    final completedPrayer = prayer;
    setState(() => working = true);
    try {
      final userId = ref.read(requiredUserIdProvider);
      await ref.read(qazaServiceProvider).completeRecord(
        userId: userId,
        recordId: record.id,
        completedAt: DateTime.now(),
      );
      ref.invalidate(oldestPendingProvider(completedPrayer));
      ref.invalidate(progressSummaryProvider);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      final nextPending = await ref.read(oldestPendingProvider(completedPrayer).future);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 900),
          content: Text(
            nextPending == null
                ? '${completedPrayer.label} Qaza completed successfully.'
                : '${completedPrayer.label} Qaza completed • next oldest is ready.',
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
    final state = oldestState;
    final record = state.valueOrNull;
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
              const Text('Complete one record at a time. After success, the next oldest record is shown immediately.'),
              const SizedBox(height: 20),
              DropdownButtonFormField<PrayerType>(
                value: prayer,
                decoration: const InputDecoration(labelText: 'Prayer', prefixIcon: Icon(Icons.mosque_outlined)),
                items: [for (final item in PrayerType.values) DropdownMenuItem(value: item, child: Text(item.label))],
                onChanged: working || state.isLoading ? null : (value) {
                  if (value != null) setState(() => prayer = value);
                },
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: state.when(
                    loading: () => const LoadingState(message: 'Loading oldest pending record…', padding: 24),
                    error: (_, __) => ErrorState(message: 'We could not load your Qaza record.', onRetry: _refresh),
                    data: (_) {
                      if (record == null) {
                        return const EmptyState(icon: Icons.check_circle_outline_rounded, title: 'No pending Qaza for this prayer.', message: 'Choose another prayer or add a Qaza record first.');
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const CircleAvatar(child: Icon(Icons.mosque_outlined)),
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
                          const Text('Completion timestamp is recorded separately.'),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AppButton(
                key: const Key('complete_oldest_pending'),
                label: working ? 'Completing...' : 'Complete oldest pending',
                icon: working ? Icons.hourglass_top_rounded : Icons.check_circle_rounded,
                onPressed: record == null || state.isLoading || working ? null : _complete,
                expand: true,
              ),
              const SizedBox(height: 12),
              AppButton(label: 'Open Namaz-wise completion', icon: Icons.format_list_bulleted_rounded, secondary: true, onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NamazWiseScreen())), expand: true),
            ],
          ),
        ),
      ),
    );
  }
}
