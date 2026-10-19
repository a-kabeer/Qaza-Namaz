import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/core/utils/date_formatters.dart';
import 'package:qaza_namaz/features/daily_salah/daily_salah_tracking_providers.dart';
import 'package:qaza_namaz/features/settings/profile_overview.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  const profile = UserProfile(
    gender: Gender.female,
    madhab: Madhab.hanafi,
    pubertyAge: 12,
    startPrayingAge: 13,
    witrIncluded: true,
    dailyQazaTarget: 10,
    onboardingCompleted: true,
  );

  Widget host({
    required UserProfile profile,
    required VoidCallback onEdit,
  }) {
    return ProviderScope(
      overrides: [
        dailySalahTrackingEnabledProvider.overrideWith((ref) async => false),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ProfileOverview(
            profile: profile,
            onEdit: onEdit,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'profile overview presents saved details read-only',
    (tester) async {
      await tester.pumpWidget(host(profile: profile, onEdit: () {}));

      expect(find.byKey(const Key('profile_overview')), findsOneWidget);
      expect(find.byKey(const Key('profile_overview_gender')), findsOneWidget);
      expect(find.byKey(const Key('profile_overview_madhab')), findsOneWidget);
      expect(
        find.byKey(const Key('profile_overview_daily_target')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('profile_gender')), findsNothing);
      expect(find.byKey(const Key('profile_dob')), findsNothing);
      expect(find.byKey(const Key('profile_submit')), findsNothing);
    },
  );

  testWidgets(
    'childhood Muslim remembered dates are shown instead of missing ages',
    (tester) async {
      final pubertyDate = DateTime(2003, 4, 5);
      final startPrayingDate = DateTime(2005, 6, 7);
      final rememberedDateProfile = UserProfile(
        gender: Gender.female,
        madhab: Madhab.hanafi,
        dateOfBirth: DateTime(1990, 1, 1),
        pubertyInputMode: ProfileInputMode.rememberedDate,
        pubertyDateOverride: pubertyDate,
        startPrayingInputMode: ProfileInputMode.rememberedDate,
        startPrayingDateOverride: startPrayingDate,
        witrIncluded: true,
        dailyQazaTarget: 5,
        onboardingCompleted: true,
      );

      await tester.pumpWidget(
        host(profile: rememberedDateProfile, onEdit: () {}),
      );
      await tester.pumpAndSettle();

      expect(find.text('Puberty Date'), findsOneWidget);
      expect(
        find.text(DateFormatters.formatGregorianFull(pubertyDate)),
        findsOneWidget,
      );
      expect(find.text('Date I started praying'), findsOneWidget);
      expect(
        find.text(DateFormatters.formatGregorianFull(startPrayingDate)),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'profile overview exposes an explicit edit action',
    (tester) async {
      var editTapped = false;
      await tester.pumpWidget(
        host(profile: profile, onEdit: () => editTapped = true),
      );

      final editButton = find.byKey(const Key('profile_edit'));
      await tester.scrollUntilVisible(
        editButton,
        300,
        scrollable: find.descendant(
          of: find.byKey(const Key('profile_overview')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(editButton);
      expect(editTapped, isTrue);
    },
  );
}
