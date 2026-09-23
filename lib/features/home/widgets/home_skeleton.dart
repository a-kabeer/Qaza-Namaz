import 'package:flutter/material.dart';

import '../../../core/constants/prayer_types.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/skeleton.dart';

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('home_dashboard_skeleton'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, AppSpacing.fabClearance),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HomeTodaySkeletonCard(),
                SizedBox(height: 12),
                _HomeOverallSkeletonCard(),
                SizedBox(height: 12),
                _HomePendingByPrayerSkeletonCard(),
                SizedBox(height: 12),
                _HomeProgressSkeletonCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeTodaySkeletonCard extends StatelessWidget {
  const _HomeTodaySkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Expanded(child: SkeletonText(width: 150, height: 20)),
                SizedBox(width: 12),
                SkeletonText(width: 92, height: 14),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final progress = const Column(
                  children: [
                    SkeletonCircle(size: 150),
                  ],
                );

                final next = const Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: SkeletonText(width: 150, height: 18)),
                        SizedBox(width: 8),
                        SkeletonText(width: 74, height: 30),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonCircle(size: 52),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonText(width: 92, height: 22),
                              SizedBox(height: 7),
                              SkeletonText(width: 130, height: 14),
                              SizedBox(height: 5),
                              SkeletonText(width: 112, height: 12),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        SkeletonText(width: 72, height: 24),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SkeletonBox(
                            width: double.infinity,
                            height: 44,
                            borderRadius: BorderRadius.all(
                              Radius.circular(12),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        SkeletonBox(
                          width: 126,
                          height: 44,
                          borderRadius: BorderRadius.all(
                            Radius.circular(12),
                          ),
                        ),
                      ],
                    ),
                  ],
                );

                if (constraints.maxWidth < 500) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      progress,
                      const SizedBox(height: 18),
                      next,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: 190, child: progress),
                    const SizedBox(width: 18),
                    const SkeletonBox(width: 1, height: 128),
                    const SizedBox(width: 18),
                    Expanded(child: next),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(
                  width: 20,
                  height: 20,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonText(width: 210, height: 16),
                      SizedBox(height: 5),
                      SkeletonText(width: 120, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeOverallSkeletonCard extends StatelessWidget {
  const _HomeOverallSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stats = const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: SkeletonText(width: 130, height: 20)),
                    SizedBox(width: 12),
                    SkeletonText(width: 78, height: 18),
                  ],
                ),
                SizedBox(height: 12),
                _HomeSkeletonStatRow(),
                _HomeSkeletonStatRow(),
                _HomeSkeletonStatRow(),
              ],
            );

            final donut = const SkeletonCircle(size: 150);

            if (constraints.maxWidth < 520) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  donut,
                  const SizedBox(width: 16),
                  Expanded(child: stats),
                ],
              );
            }

            return Row(
              children: [
                donut,
                const SizedBox(width: 24),
                Expanded(child: stats),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeSkeletonStatRow extends StatelessWidget {
  const _HomeSkeletonStatRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SkeletonBox(
            width: 10,
            height: 10,
            borderRadius: BorderRadius.all(Radius.circular(999)),
          ),
          SizedBox(width: 10),
          Expanded(child: SkeletonText(width: 90, height: 16)),
          SizedBox(width: 12),
          SkeletonText(width: 42, height: 18),
        ],
      ),
    );
  }
}

class _HomePendingByPrayerSkeletonCard extends StatelessWidget {
  const _HomePendingByPrayerSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Expanded(child: SkeletonText(width: 160, height: 20)),
                SizedBox(width: 12),
                SkeletonText(width: 58, height: 18),
              ],
            ),
            const SizedBox(height: 10),
            for (var i = 0; i < PrayerType.values.length; i++) ...[
              const _HomePendingPrayerSkeletonRow(),
              if (i != PrayerType.values.length - 1) const SizedBox(height: 2),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomePendingPrayerSkeletonRow extends StatelessWidget {
  const _HomePendingPrayerSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SkeletonBox(
            width: 28,
            height: 20,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          SizedBox(width: 8),
          SkeletonText(width: 62, height: 16),
          SizedBox(width: 8),
          Expanded(
            child: SkeletonBox(
              width: double.infinity,
              height: 10,
              borderRadius: BorderRadius.all(Radius.circular(999)),
            ),
          ),
          SizedBox(width: 10),
          SkeletonText(width: 28, height: 16),
          SizedBox(width: 4),
          SkeletonBox(
            width: 20,
            height: 20,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
        ],
      ),
    );
  }
}

class _HomeProgressSkeletonCard extends StatelessWidget {
  const _HomeProgressSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SkeletonText(width: 150, height: 20),
            const SizedBox(height: 10),
            const SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SkeletonBox(
                    width: 54,
                    height: 40,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  SizedBox(width: 4),
                  SkeletonBox(
                    width: 62,
                    height: 40,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  SizedBox(width: 4),
                  SkeletonBox(
                    width: 62,
                    height: 40,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  SizedBox(width: 4),
                  SkeletonBox(
                    width: 70,
                    height: 40,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  SizedBox(width: 4),
                  SkeletonBox(
                    width: 70,
                    height: 40,
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                return SkeletonBox(
                  width: constraints.maxWidth,
                  height: 190,
                  borderRadius: const BorderRadius.all(
                    Radius.circular(12),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class HomeSkeletonCard extends StatelessWidget {
  const HomeSkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: height,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: SkeletonText(width: 160, height: 18)),
                  SizedBox(width: 12),
                  SkeletonText(width: 72, height: 14),
                ],
              ),
              Spacer(),
              SkeletonBox(
                width: double.infinity,
                height: 10,
                borderRadius: BorderRadius.all(Radius.circular(999)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeTodayProgressSkeleton extends StatelessWidget {
  const HomeTodayProgressSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonCircle(size: 138),
        SizedBox(height: 18),
        SkeletonBox(
          width: double.infinity,
          height: 56,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ],
    );
  }
}

class HomeNextQazaSkeleton extends StatelessWidget {
  const HomeNextQazaSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonBox(
          width: double.infinity,
          height: 58,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        SizedBox(height: 12),
        SkeletonBox(
          width: double.infinity,
          height: 44,
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ],
    );
  }
}