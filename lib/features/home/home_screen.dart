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