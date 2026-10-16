import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/features/onboarding/profile_form.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

void main() {
  testWidgets('each profile field can switch modes independently without losing values',
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
              startPrayingAge: 13,
              witrIncluded: true,
            ),
            onChanged: (profile) => changed = profile,
            onSubmit: (_) async {},
          ),
        ),
      ),
    );

    final pubertyMode = find.byKey(const Key('profile_puberty_input_mode'));
    await tester.scrollUntilVisible(
      pubertyMode,
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(
      find.descendant(
        of: pubertyMode,
        matching: find.text('I remember the date'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile_puberty_date')), findsOneWidget);
    expect(changed?.pubertyInputMode, ProfileInputMode.rememberedDate);
    expect(changed?.pubertyAge, 12);

    final startMode = find.byKey(const Key('profile_start_praying_input_mode'));
    await tester.scrollUntilVisible(
      startMode,
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(
      find.descendant(
        of: startMode,
        matching: find.text('I remember the date'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('profile_start_praying_date')),
      findsOneWidget,
    );
    expect(changed?.startPrayingInputMode, ProfileInputMode.rememberedDate);
    expect(changed?.startPrayingAge, 13);

    await tester.scrollUntilVisible(
      pubertyMode,
      300,
      scrollable: find.byType(Scrollable),
    );
    await tester.tap(
      find.descendant(
        of: pubertyMode,
        matching: find.text('Estimate using age'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile_puberty_age')), findsOneWidget);
    expect(changed?.pubertyAge, 12);
    expect(changed?.pubertyDateOverride, isNull);
    expect(tester.takeException(), isNull);
  });
}
