import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/features/settings/profile_overview.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  const profile = UserProfile(
    gender: Gender.female,
    madhab: Madhab.hanafi,
    dateOfBirth: null,
    pubertyAge: 12,
    startPrayingAge: 13,
    witrIncluded: true,
    dailyQazaTarget: 10,
    onboardingCompleted: true,
  );

  Widget host({required VoidCallback onEdit}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ProfileOverview(profile: profile, onEdit: onEdit),
      ),
    );
  }

  testWidgets('profile overview presents saved details read-only', (tester) async {
    await tester.pumpWidget(host(onEdit: () {}));

    expect(find.byKey(const Key('profile_overview')), findsOneWidget);
    expect(find.byKey(const Key('profile_overview_gender')), findsOneWidget);
    expect(find.byKey(const Key('profile_overview_madhab')), findsOneWidget);
    expect(find.byKey(const Key('profile_overview_daily_target')), findsOneWidget);
    expect(find.byKey(const Key('profile_gender')), findsNothing);
    expect(find.byKey(const Key('profile_dob')), findsNothing);
    expect(find.byKey(const Key('profile_submit')), findsNothing);
  });

  testWidgets('profile overview exposes an explicit edit action', (tester) async {
    var editTapped = false;
    await tester.pumpWidget(host(onEdit: () => editTapped = true));

    await tester.tap(find.byKey(const Key('profile_edit')));
    expect(editTapped, isTrue);
  });
}
