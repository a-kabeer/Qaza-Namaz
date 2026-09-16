import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/qaza/add_qaza_screen.dart';

void main() {
  double contrastRatio(Color foreground, Color background) {
    final lighter = foreground.computeLuminance() > background.computeLuminance() ? foreground : background;
    final darker = identical(lighter, foreground) ? background : foreground;
    return (lighter.computeLuminance() + 0.05) / (darker.computeLuminance() + 0.05);
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

      final readableTexts = [
        tester.widget<Text>(find.text('Step 1 of 3 • Range Setup')),
        ...['Method', 'Dates', 'Review'].map((label) => tester.widget<Text>(find.text(label))),
      ];
      for (final text in readableTexts) {
        final color = text.style?.color ?? DefaultTextStyle.of(tester.element(find.byWidget(text))).style.color;
        expect(color, isNotNull);
        expect(contrastRatio(color!, background), greaterThanOrEqualTo(3.0));
      }

      final activeStepNumber = tester.widget<Text>(find.text('1').first);
      expect(activeStepNumber.style?.color, scheme.onPrimary);
      expect(contrastRatio(scheme.onPrimary, scheme.primary), greaterThanOrEqualTo(3.0));

      final inactiveStepNumber = tester.widget<Text>(find.text('2').first);
      expect(inactiveStepNumber.style?.color, scheme.onSurfaceVariant);
      expect(contrastRatio(scheme.onSurfaceVariant, scheme.surfaceContainerHighest), greaterThanOrEqualTo(3.0));

      final choiceIcon = tester.widget<Icon>(find.byIcon(Icons.calendar_month_rounded));
      expect(choiceIcon.color, scheme.onSurfaceVariant);
      expect(contrastRatio(scheme.onSurfaceVariant, background), greaterThanOrEqualTo(3.0));
    });
  }
}
