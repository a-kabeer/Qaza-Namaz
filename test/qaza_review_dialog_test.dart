
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/qaza_plan_service.dart';
import 'package:qaza_namaz/features/onboarding/qaza_review_dialog.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  Widget host(QazaPlan plan, {required QazaReviewConfirm onConfirm}) {
    final profile = UserProfile(
      languageCode: 'en',
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(2000, 1, 1),
      pubertyAge: 12,
      startPrayingAge: 14,
      witrIncluded: true,
      onboardingCompleted: true,
    );

    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Center(
          child: FilledButton(
            key: const Key('open_review'),
            onPressed: () {
              showDialog<QazaReviewAction>(
                context: context,
                barrierDismissible: false,
                builder: (_) => QazaReviewDialog(
                  profile: profile,
                  plan: plan,
                  onConfirm: onConfirm,
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }

  final plan = QazaPlan(
    startDate: DateTime(2012, 1, 1),
    endDate: DateTime(2014, 1, 1),
    totalDays: 731,
    includeWitr: true,
    totalPrayers: 3655,
    prayerBreakdown: {
      for (final prayer in PrayerType.values)
        if (prayer != PrayerType.witr) prayer: 731,
    },
  );

  testWidgets('review shows calculated summary and lets user edit',
      (tester) async {
    await tester.pumpWidget(host(
      plan,
      onConfirm: (_) async {},
    ));

    await tester.tap(find.byKey(const Key('open_review')));
    await tester.pumpAndSettle();

    expect(find.text('Review Your Qaza Plan'), findsOneWidget);
    expect(find.text('4386'), findsOneWidget);
    expect(find.text('Hanafi'), findsOneWidget);
    expect(find.text('Prayer Breakdown'), findsOneWidget);
    expect(find.text('731'), findsNWidgets(6));
    expect(find.byKey(const Key('qaza_review_add')), findsOneWidget);
    expect(find.byKey(const Key('qaza_review_edit')), findsOneWidget);

    await tester.tap(find.byKey(const Key('qaza_review_edit')));
    await tester.pumpAndSettle();

    expect(find.text('Review Your Qaza Plan'), findsNothing);
  });

  testWidgets('confirm calls the importer and closes the review',
      (tester) async {
    var called = false;
    await tester.pumpWidget(host(
      plan,
      onConfirm: () async {
        called = true;
        return true;
      },
    ));

    await tester.tap(find.byKey(const Key('open_review')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('qaza_review_add')));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(find.text('Review Your Qaza Plan'), findsNothing);
  });
}
