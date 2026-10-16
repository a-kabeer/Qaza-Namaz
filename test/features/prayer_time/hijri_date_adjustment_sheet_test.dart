import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/features/prayer_time/presentation/hijri_date_adjustment_sheet.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> openSheet(WidgetTester tester, Locale locale) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('open_hijri_adjustment_test_sheet'),
                onPressed: () {
                  HijriDateAdjustmentSheet.show(
                    context: context,
                    date: DateTime(2026, 9, 26),
                    selectedOffset: 0,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_hijri_adjustment_test_sheet')));
    await tester.pumpAndSettle();
  }

  testWidgets('shows all options without overflow on narrow screens',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await openSheet(tester, const Locale('en'));

    expect(find.byKey(const Key('hijri_adjustment_option_-2')), findsOneWidget);
    expect(find.byKey(const Key('hijri_adjustment_option_-1')), findsOneWidget);
    expect(find.byKey(const Key('hijri_adjustment_option_0')), findsOneWidget);
    expect(find.byKey(const Key('hijri_adjustment_option_1')), findsOneWidget);
    expect(find.byKey(const Key('hijri_adjustment_option_2')), findsOneWidget);
    expect(find.text('Adjust Hijri Date'), findsOneWidget);
    expect(find.text('No adjustment'), findsOneWidget);
    expect(find.textContaining('Selected'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adjustment labels are localized', (tester) async {
    await openSheet(tester, const Locale('ur'));

    expect(find.text('ہجری تاریخ میں ترمیم'), findsOneWidget);
    expect(find.text('2 دن پہلے'), findsOneWidget);
    expect(find.text('کوئی تبدیلی نہیں'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping an option closes the sheet with its offset',
      (tester) async {
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                key: const Key('open_hijri_adjustment_result_test'),
                onPressed: () async {
                  selected = await HijriDateAdjustmentSheet.show(
                    context: context,
                    date: DateTime(2026, 9, 26),
                    selectedOffset: 0,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('open_hijri_adjustment_result_test')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('hijri_adjustment_option_2')));
    await tester.pumpAndSettle();

    expect(selected, 2);
    expect(find.byKey(const Key('hijri_adjustment_option_2')), findsNothing);
  });
}
