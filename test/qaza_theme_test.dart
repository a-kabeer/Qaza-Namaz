import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/qaza/add_qaza_screen.dart';

void main() {
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

      final stepText = tester.widget<Text>(find.text('Step 1 of 3 • Range Setup'));
      expect(stepText.style?.color, theme.textTheme.labelLarge?.color);

      for (final label in ['Method', 'Dates', 'Review']) {
        final text = tester.widget<Text>(find.text(label));
        expect(text.style?.color, scheme.onSurface);
      }

      final activeStepNumber = tester.widget<Text>(find.text('1').first);
      expect(activeStepNumber.style?.color, scheme.onPrimary);

      final inactiveStepNumber = tester.widget<Text>(find.text('2').first);
      expect(inactiveStepNumber.style?.color, scheme.onSurfaceVariant);

      final choiceIcon = tester.widget<Icon>(find.byIcon(Icons.calendar_month_rounded));
      expect(choiceIcon.color, scheme.onSurfaceVariant);
    });
  }
}
