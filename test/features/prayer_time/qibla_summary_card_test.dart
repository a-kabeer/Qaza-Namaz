import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/prayer_time/presentation/qibla_summary_card.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  Widget buildHarness({required VoidCallback onTap}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: SizedBox(
          width: 160,
          height: 190,
          child: QiblaSummaryCard(
            bearing: 267.741,
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  testWidgets('renders bearing and invokes tap callback', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      buildHarness(onTap: () => tapped = true),
    );

    expect(find.text('268°'), findsOneWidget);
    expect(find.text('Qibla Direction'), findsOneWidget);

    await tester.tap(find.byType(QiblaSummaryCard));
    expect(tapped, isTrue);
  });

  testWidgets('keeps a narrow card free of overflow', (tester) async {
    await tester.pumpWidget(
      buildHarness(onTap: () {}),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
