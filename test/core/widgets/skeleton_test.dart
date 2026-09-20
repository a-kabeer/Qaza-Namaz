import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/core/widgets/skeleton.dart';

void main() {
  testWidgets('SkeletonBox renders with theme-aware shimmer surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: const Scaffold(
          body: SkeletonBox(width: 120, height: 20),
        ),
      ),
    );

    expect(find.byType(SkeletonBox), findsOneWidget);
    expect(find.byType(SkeletonShimmer), findsOneWidget);
  });

  testWidgets('SkeletonShimmer stays static when animations are disabled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const Scaffold(
            body: SkeletonText(width: 100),
          ),
        ),
      ),
    );

    expect(find.byType(SkeletonText), findsOneWidget);
    expect(find.byType(ExcludeSemantics), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
