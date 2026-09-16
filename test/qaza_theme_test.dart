import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/qaza/add_qaza_screen.dart';

void main() {
  double contrastRatio(Color first, Color second) {
    final firstLuminance = first.computeLuminance();
    final secondLuminance = second.computeLuminance();
    final lighter = firstLuminance > secondLuminance ? firstLuminance : secondLuminance;
    final darker = firstLuminance > secondLuminance ? secondLuminance : firstLuminance;
    return (lighter + 0.05) / (darker + 0.05);
  }

  for (final brightness in Brightness.values) {
    testWidgets('${brightness.name} theme keeps Qaza step content readable', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(brightness: brightness),
            home: const AddQazaScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final theme = Theme.of(tester.element(find.byKey(const Key('qaza_flow_heading'))));
      final scheme = theme.colorScheme;
      final background = theme.scaffoldBackgroundColor;

      final stepLabel = tester.widget<Text>(find.text('Step 1 of 3 • Select Dates'));
      final labelColor = stepLabel.style?.color ?? DefaultTextStyle.of(tester.element(find.byWidget(stepLabel))).style.color;
      expect(labelColor, isNotNull);
      expect(contrastRatio(labelColor!, background), greaterThanOrEqualTo(3.0));

      final heading = tester.widget<Text>(find.byKey(const Key('qaza_flow_heading')));
      final headingColor = heading.style?.color ?? DefaultTextStyle.of(tester.element(find.byWidget(heading))).style.color;
      expect(headingColor, isNotNull);
      expect(contrastRatio(headingColor!, background), greaterThanOrEqualTo(3.0));

      final choiceIcon = tester.widget<Icon>(find.byIcon(Icons.date_range_rounded).first);
      expect(choiceIcon.color, scheme.onSurfaceVariant);
      expect(contrastRatio(scheme.onSurfaceVariant, background), greaterThanOrEqualTo(3.0));

      expect(find.text('Single'), findsOneWidget);
      expect(find.text('Range'), findsOneWidget);
      expect(find.text('Multiple'), findsOneWidget);
      expect(find.byKey(const Key('qaza_calendar_picker')), findsOneWidget);
    });
  }
}
