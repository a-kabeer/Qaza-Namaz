import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/qaza_plan_service.dart';
import 'package:qaza_namaz/features/onboarding/qaza_review_dialog.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

Widget _reviewApp(Locale locale) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: QazaReviewDialog(
          profile: const UserProfile(
            languageCode: 'en',
            madhab: Madhab.hanafi,
          ),
          plan: QazaPlan(
            startDate: DateTime(2020, 1, 1),
            endDate: DateTime(2020, 1, 2),
            totalDays: 2,
            includeWitr: true,
            totalPrayers: 12,
            prayerBreakdown: {
              for (final prayer in PrayerType.values) prayer: 2,
            },
          ),
          onConfirm: () async => false,
        ),
      ),
    ),
  );
}

Future<void> _pumpReview(WidgetTester tester, Locale locale) async {
  await tester.pumpWidget(_reviewApp(locale));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('review actions have equal width and height in English',
      (tester) async {
    await _pumpReview(tester, const Locale('en'));

    final edit = tester.renderObject(find.byKey(const Key('qaza_review_edit')));
    final add = tester.renderObject(find.byKey(const Key('qaza_review_add')));

    expect(edit.size.width, add.size.width);
    expect(edit.size.height, add.size.height);
  });

  testWidgets('review actions remain usable in Urdu RTL', (tester) async {
    await _pumpReview(tester, const Locale('ur'));

    final edit = tester.renderObject(find.byKey(const Key('qaza_review_edit')));
    final add = tester.renderObject(find.byKey(const Key('qaza_review_add')));

    expect(edit.size.width, add.size.width);
    expect(edit.size.height, add.size.height);
    expect(find.text('اپنی تفصیلات میں ترمیم کریں'), findsOneWidget);
    expect(find.text('قضا کو میرے ٹریکر میں شامل کریں'), findsOneWidget);
  });
}