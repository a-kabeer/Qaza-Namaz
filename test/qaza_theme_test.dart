import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/test_app.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/features/qaza/add_qaza_screen.dart';
import 'support/in_memory_qaza_repository.dart';

void main() {
  double contrastRatio(Color first, Color second) {
    final firstLuminance = first.computeLuminance();
    final secondLuminance = second.computeLuminance();
    final lighter =
        firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
    final darker =
        firstLuminance > secondLuminance ? secondLuminance : firstLuminance;
    return (lighter + 0.05) / (darker + 0.05);
  }

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name} theme keeps Qaza step content readable',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeUserIdProvider.overrideWithValue('test-user'),
            qazaRepositoryProvider.overrideWithValue(InMemoryQazaRepository()),
          ],
          child: TestApp(
            theme: ThemeData(brightness: brightness),
            home: const AddQazaScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final theme =
          Theme.of(tester.element(find.byKey(const Key('qaza_flow_heading'))));
      final scheme = theme.colorScheme;
      final background = theme.scaffoldBackgroundColor;

      final readableTexts = [
        tester.widget<Text>(find.text('Step 1 of 3 • Select Dates')),
        tester.widget<Text>(find.byKey(const Key('qaza_flow_heading'))),
        tester.widget<Text>(find.text('Single').first),
        tester.widget<Text>(find.text('Range').first),
        tester.widget<Text>(find.text('Multiple').first),
      ];
      for (final text in readableTexts) {
        final color = text.style?.color ??
            DefaultTextStyle.of(tester.element(find.byWidget(text)))
                .style
                .color;
        expect(color, isNotNull);
        expect(contrastRatio(color!, background), greaterThanOrEqualTo(3.0));
      }

      final activeStepNumber = tester.widget<Text>(find.text('1').first);
      expect(activeStepNumber.style?.color, scheme.onPrimary);
      expect(contrastRatio(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(3.0));

      final inactiveStepNumber = tester.widget<Text>(find.text('2').first);
      expect(inactiveStepNumber.style?.color, scheme.onSurfaceVariant);
      expect(
          contrastRatio(
              scheme.onSurfaceVariant, scheme.surfaceContainerHighest),
          greaterThanOrEqualTo(3.0));
    });
  }
}
