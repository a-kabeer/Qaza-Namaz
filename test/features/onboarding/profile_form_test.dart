import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.byKey(const Key('profile_daily_qaza_target')), findsOneWidget);
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

}
