import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/time/local_date_service.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/features/onboarding/profile_form.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  testWidgets(
    'onboarding ProfileForm does not show Daily Qaza Target',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProfileForm(
              initialProfile: const UserProfile(languageCode: 'en'),
              showDailyQazaTarget: false,
              onSubmit: (_) async {},
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('profile_daily_qaza_target')), findsNothing);
    },
  );

  testWidgets(
    'ProfileForm can expose Daily Qaza Target when requested',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProfileForm(
              initialProfile: const UserProfile(languageCode: 'en'),
              showDailyQazaTarget: true,
              onSubmit: (_) async {},
            ),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('profile_daily_qaza_target')),
        500,
        scrollable: find.byType(Scrollable),
      );
      expect(
          find.byKey(const Key('profile_daily_qaza_target')), findsOneWidget);
    },
  );

  testWidgets(
    'ProfileForm exposes bounded puberty and prayer-start age controls',
    (tester) async {
      UserProfile? changed;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProfileForm(
              initialProfile: UserProfile(
                languageCode: 'en',
                gender: Gender.male,
                madhab: Madhab.hanafi,
                dateOfBirth: DateTime(2000, 1, 1),
                pubertyAge: 12,
                startPrayingAge: 15,
                witrIncluded: true,
              ),
              onChanged: (profile) => changed = profile,
              onSubmit: (_) async {},
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('profile_puberty_age_decrement')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('profile_puberty_age_increment')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('profile_start_praying_age_decrement')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('profile_start_praying_age_increment')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('profile_puberty_age_increment')));
      await tester.pump();
      expect(changed?.pubertyAge, 13);

      await tester.tap(find.byKey(const Key('profile_puberty_age_decrement')));
      await tester.pump();
      expect(changed?.pubertyAge, 12);
    },
  );

  testWidgets(
    'DOB selector handles leap years and clamps invalid days',
    (tester) async {
      UserProfile? changed;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProfileForm(
              initialProfile: UserProfile(
                languageCode: 'en',
                gender: Gender.male,
                madhab: Madhab.hanafi,
                dateOfBirth: DateTime(2000, 2, 29),
                pubertyAge: 12,
                startPrayingAge: 15,
                witrIncluded: true,
              ),
              onChanged: (profile) => changed = profile,
              onSubmit: (_) async {},
            ),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('profile_dob')),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.byKey(const Key('profile_dob')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('profile_dob_picker_panel')),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
      expect(find.text('Year'), findsOneWidget);
      final dayFinder = find.byKey(const Key('profile_dob_day'));
      final monthFinder = find.byKey(const Key('profile_dob_month'));
      final yearFinder = find.byKey(const Key('profile_dob_year'));
      expect(tester.widget<DropdownButton<int>>(dayFinder).value, 29);
      expect(
        tester.widget<DropdownButton<int>>(dayFinder).items,
        hasLength(29),
      );

      await tester.ensureVisible(yearFinder);
      await tester.tap(yearFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2001').last);
      await tester.pumpAndSettle();
      expect(tester.widget<DropdownButton<int>>(dayFinder).value, 28);
      expect(
        tester.widget<DropdownButton<int>>(dayFinder).items,
        hasLength(28),
      );

      await tester.ensureVisible(monthFinder);
      await tester.tap(monthFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('March').last);
      await tester.pumpAndSettle();
      expect(tester.widget<DropdownButton<int>>(dayFinder).value, 28);
      expect(
        tester.widget<DropdownButton<int>>(dayFinder).items,
        hasLength(31),
      );

      final confirmFinder = find.byKey(const Key('profile_dob_confirm'));
      await tester.ensureVisible(confirmFinder);
      await tester.tap(confirmFinder);
      await tester.pumpAndSettle();
      expect(changed?.dateOfBirth, DateTime(2001, 3, 28));
      expect(
        find.byKey(const Key('profile_dob_picker_panel')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'DOB selector excludes future months and days in the current year',
    (tester) async {
      final today = LocalDateService.today();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProfileForm(
              initialProfile: UserProfile(
                languageCode: 'en',
                dateOfBirth: today,
              ),
              onSubmit: (_) async {},
            ),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('profile_dob')),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.byKey(const Key('profile_dob')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('profile_dob_picker_panel')),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);

      final day = tester.widget<DropdownButton<int>>(
        find.byKey(const Key('profile_dob_day')),
      );
      final month = tester.widget<DropdownButton<int>>(
        find.byKey(const Key('profile_dob_month')),
      );
      final year = tester.widget<DropdownButton<int>>(
        find.byKey(const Key('profile_dob_year')),
      );
      expect(year.value, today.year);
      expect(year.items, hasLength(today.year - 1900 + 1));
      expect(month.value, today.month);
      expect(month.items, hasLength(today.month));
      expect(day.value, today.day);
      expect(day.items, hasLength(today.day));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'DOB field expands and collapses the inline selector',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProfileForm(
              initialProfile: const UserProfile(languageCode: 'en'),
              onSubmit: (_) async {},
            ),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('profile_dob')),
        300,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.byKey(const Key('profile_dob')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('profile_dob_picker_panel')),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byKey(const Key('profile_dob')));
      await tester.tap(find.byKey(const Key('profile_dob')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('profile_dob_picker_panel')),
        findsNothing,
      );
      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
