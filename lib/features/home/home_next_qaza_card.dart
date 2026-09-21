import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/state_widgets.dart';
import '../../core/widgets/skeleton.dart';
import '../../domain/entities/qaza_record.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/prayer_type_l10n.dart';
import 'home_plan.dart';

class HomeNextQazaCard extends ConsumerStatefulWidget {
  const HomeNextQazaCard({super.key});

  @override
  ConsumerState<HomeNextQazaCard> createState() => _HomeNextQazaCardState();
}

class _HomeNextQazaCardState extends ConsumerState<HomeNextQazaCard> {
  bool working = false;

  Future<void> _complete(QazaRecord record) async {
    if (working) return;
    final l10n = AppLocalizations.of(context);
    setState(() => working = true);

    try {
      final userId = ref.read(requiredUserIdProvider);
      final completedPrayer = record.prayerType;
      await ref.read(qazaServiceProvider).completeRecord(
            userId: userId,
            recordId: record.id,
            completedAt: ref.read(homeNowProvider),
          );

      ref.invalidate(homeNextQazaProvider);
      ref.invalidate(progressSummaryProvider);
      ref.invalidate(homeDailyProgressProvider);

      if (!mounted) return;
      HapticFeedback.mediumImpact();

      final next = await ref.read(homeNextQazaProvider.future);
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(milliseconds: 900),
            content: Text(
              next == null
                  ? l10n.completeSuccess(
                      completedPrayer.localizedLabel(l10n),
                    )
                  : l10n.completeSuccessNext(
                      completedPrayer.localizedLabel(l10n),
                    ),
            ),
          ),
        );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.completeFailed)),
        );
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(homeNextQazaProvider);

    return state.when(
      loading: () => const _HomeNextQazaSkeleton(),
      error: (_, __) => ErrorState(
        key: const Key('home_next_qaza_error'),
        message: l10n.completeLoadError,
        onRetry: () => ref.invalidate(homeNextQazaProvider),
      ),
      data: (record) {
        if (record == null) {
          return AppCard(
            key: const Key('home_next_qaza_complete'),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.homeHeadingCompleted,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          );
        }

        return AppCard(
          key: const Key('home_next_qaza'),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.homeNextQaza,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    foregroundColor:
                        Theme.of(context).colorScheme.onPrimaryContainer,
                    child: const Icon(Icons.mosque_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.prayerType.localizedLabel(l10n),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          DateFormatters.formatGregorianDatePadded(
                            record.originalDate,
                          ),
                          key: const Key('home_next_qaza_date'),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Text(
                          DateFormatters.hijriLabel(record.originalDate),
                          key: const Key('home_next_qaza_date_hijri'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AppButton(
                key: const Key('home_complete_next_qaza'),
                expand: true,
                label: working
                    ? l10n.completeInProgress
                    : l10n.homeCompleteNextQaza,
                onPressed: working ? null : () => _complete(record),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeNextQazaSkeleton extends StatelessWidget {
  const _HomeNextQazaSkeleton();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      key: Key('home_next_qaza_loading'),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SkeletonText(width: 110, height: 18),
          SizedBox(height: 12),
          Row(
            children: [
              SkeletonCircle(size: 40),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonText(width: 90, height: 18),
                    SizedBox(height: 8),
                    SkeletonText(width: 150, height: 14),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          SkeletonBox(
            width: double.infinity,
            height: 44,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ],
      ),
    );
  }
}
