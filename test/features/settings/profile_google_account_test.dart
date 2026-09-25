import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/domain/entities/app_user.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/features/settings/profile_screen.dart';

import '../../support/test_app.dart';

final _profile = UserProfile(
  languageCode: 'en',
  gender: Gender.male,
  madhab: Madhab.hanafi,
  dateOfBirth: DateTime(2010, 6, 15),
  pubertyAge: 12,
  startPrayingAge: 12,
  witrIncluded: true,
  onboardingCompleted: true,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpProfile(
    WidgetTester tester, {
    required AppUser? user,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileProvider.overrideWith((ref) async => _profile),
          authStateProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(user),
          ),
        ],
        child: const TestApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('signed-out profile offers Continue with Google only',
      (tester) async {
    await pumpProfile(tester, user: null);

    expect(find.byKey(const Key('profile_google_account')), findsOneWidget);
    expect(find.byKey(const Key('profile_continue_google')), findsOneWidget);
    expect(find.byKey(const Key('profile_sign_out')), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('signed-in profile shows Google identity and Sign Out only',
      (tester) async {
    await pumpProfile(
      tester,
      user: const AppUser(
        id: 'google-user',
        email: 'abdul@example.com',
        displayName: 'Abdul',
        photoUrl: 'https://example.com/avatar.png',
      ),
    );

    expect(find.byKey(const Key('profile_google_account')), findsOneWidget);
    expect(find.byKey(const Key('profile_google_name')), findsOneWidget);
    expect(find.byKey(const Key('profile_google_email')), findsOneWidget);
    expect(find.text('Abdul'), findsOneWidget);
    expect(find.text('abdul@example.com'), findsOneWidget);
    expect(find.byKey(const Key('profile_sign_out')), findsOneWidget);
    expect(find.byKey(const Key('profile_continue_google')), findsNothing);
  });
}
