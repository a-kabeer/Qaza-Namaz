import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/widgets/progress_widgets.dart';

void main() {
  testWidgets('status pills use theme container colors and readable foregrounds in dark mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: Row(
            children: [
              StatusChip('3 pending', tone: StatusChipTone.pending),
              StatusChip('5 fulfilled', tone: StatusChipTone.fulfilled),
            ],
          ),
        ),
      ),
    );

    final scheme = Theme.of(tester.element(find.byType(StatusChip).first)).colorScheme;
    final containers = tester.widgetList<Container>(find.byType(Container)).where((container) => container.decoration is BoxDecoration).toList();
    expect(containers, hasLength(2));

    final decorations = containers.map((container) => container.decoration! as BoxDecoration).toList();
    expect(decorations[0].color, scheme.secondaryContainer);
    expect(decorations[1].color, scheme.tertiaryContainer);

    final texts = tester.widgetList<Text>(find.byType(Text)).toList();
    expect(texts[0].style?.color, scheme.onSecondaryContainer);
    expect(texts[1].style?.color, scheme.onTertiaryContainer);
  });
}
