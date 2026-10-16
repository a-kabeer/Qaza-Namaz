import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/core/time/local_date_service.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/services/profile_rules.dart';
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

      await tester.scrollUntilVisible(
        find.byKey(const Key('profile_puberty_age_decrement')),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(
        find.byKey(const Key('profile_puberty_age_decrement')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('profile_puberty_age_increment')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('profile_start_praying_age_decrement')),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(
        find.byKey(const Key('profile_start_praying_age_decrement')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('profile_start_praying_age_increment')),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('profile_puberty_age_increment')),
        300,
        scrollable: find.byType(Scrollable),
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

  testWidgets(
    'DOB cancel discards unconfirmed changes',
    (tester) async {
      final originalDob = DateTime(2000, 2, 29);
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
                dateOfBirth: originalDob,
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

      final yearFinder = find.byKey(const Key('profile_dob_year'));
      await tester.ensureVisible(yearFinder);
      await tester.tap(yearFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2001').last);
      await tester.pumpAndSettle();

      final cancelFinder = find.byKey(const Key('profile_dob_cancel'));
      await tester.ensureVisible(cancelFinder);
      await tester.tap(cancelFinder);
      await tester.pumpAndSettle();

      expect(changed, isNull);
      expect(
        find.byKey(const Key('profile_dob_picker_panel')),
        findsNothing,
      );

      // Reopen the inline selector to verify Cancel retained the original DOB.
      final dobButton = find.byKey(const Key('profile_dob'));
      await tester.ensureVisible(dobButton);
      await tester.tap(dobButton);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButton<int>>(
              find.byKey(const Key('profile_dob_day')),
            )
            .value,
        originalDob.day,
      );
      expect(
        tester
            .widget<DropdownButton<int>>(
              find.byKey(const Key('profile_dob_month')),
            )
            .value,
        originalDob.month,
      );
      expect(
        tester
            .widget<DropdownButton<int>>(
              find.byKey(const Key('profile_dob_year')),
            )
            .value,
        originalDob.year,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'DOB selector defaults to a valid date when no DOB is saved',
    (tester) async {
      final today = LocalDateService.today();
      final defaultYear = today.year - 18;
      final lastDayInDefaultMonth =
          DateTime(defaultYear, today.month + 1, 0).day;
      final defaultDay = today.day <= lastDayInDefaultMonth
          ? today.day
          : lastDayInDefaultMonth;

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

      final day = tester.widget<DropdownButton<int>>(
        find.byKey(const Key('profile_dob_day')),
      );
      final month = tester.widget<DropdownButton<int>>(
        find.byKey(const Key('profile_dob_month')),
      );
      final year = tester.widget<DropdownButton<int>>(
        find.byKey(const Key('profile_dob_year')),
      );

      expect(year.value, defaultYear);
      expect(month.value, today.month);
      expect(day.value, defaultDay);
      expect(day.items, hasLength(lastDayInDefaultMonth));
      expect(
        find.byKey(const Key('profile_dob_picker_panel')),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new Muslim at the maximum puberty-age cutoff uses date-based prayer start',
    (tester) async {
      final dob = DateTime(2000, 1, 1);
      final cutoff = ProfileRules.fixedMilestoneDate(
        dob,
        ProfileRules.maleMaxPubertyAge,
      );
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
                dateOfBirth: dob,
                pubertyAge: 12,
                isNewMuslim: true,
                islamAcceptanceDate: cutoff,
                startPrayingDate: cutoff.add(const Duration(days: 10)),
                witrIncluded: true,
              ),
              onSubmit: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('profile_puberty_age')), findsNothing);
      expect(find.byKey(const Key('profile_start_praying_age')), findsNothing);

      final startDate = find.byKey(const Key('profile_start_praying_date'));
      await tester.scrollUntilVisible(
        startDate,
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(startDate, findsOneWidget);
      expect(
        find.byKey(const Key('profile_islam_acceptance_date')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new Muslim before the maximum puberty-age cutoff sees puberty input',
    (tester) async {
      final dob = DateTime(2000, 1, 1);
      final cutoff = ProfileRules.fixedMilestoneDate(
        dob,
        ProfileRules.femaleMaxPubertyAge,
      );
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProfileForm(
              initialProfile: UserProfile(
                languageCode: 'en',
                gender: Gender.female,
                madhab: Madhab.hanafi,
                dateOfBirth: dob,
                pubertyAge: 12,
                isNewMuslim: true,
                islamAcceptanceDate: cutoff.subtract(const Duration(days: 1)),
                startPrayingDate: cutoff.add(const Duration(days: 10)),
                witrIncluded: true,
              ),
              onSubmit: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final puberty = find.byKey(const Key('profile_puberty_age'));
      await tester.scrollUntilVisible(
        puberty,
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(puberty, findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'new Muslim can enter a remembered puberty date independently',
    (tester) async {
      final dob = DateTime(2000, 1, 1);
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
                dateOfBirth: dob,
                isNewMuslim: true,
                islamAcceptanceDate: DateTime(2005, 1, 1),
                pubertyInputMode: ProfileInputMode.rememberedDate,
                pubertyDate: DateTime(2012, 1, 1),
                startPrayingDate: DateTime(2014, 1, 1),
                witrIncluded: true,
              ),
              onSubmit: (_) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dateMode = find.byKey(const Key('profile_puberty_input_mode'));
      await tester.scrollUntilVisible(
        dateMode,
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(dateMode, findsOneWidget);
      expect(find.byKey(const Key('profile_puberty_date')), findsOneWidget);
      expect(find.byKey(const Key('profile_puberty_age')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
