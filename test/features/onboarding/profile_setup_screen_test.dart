import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_operation.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/repositories/user_profile_repository.dart';
import 'package:qaza_namaz/domain/services/qaza_plan_service.dart';
import 'package:qaza_namaz/features/onboarding/previous_qaza_choice_screen.dart';
import 'package:qaza_namaz/features/onboarding/profile_setup_screen.dart';
import 'package:qaza_namaz/features/qaza/qaza_import_controller.dart';
import 'package:qaza_namaz/l10n/app_localizations.dart';

class _FakeUserProfileRepository implements UserProfileRepository {
  UserProfile? stored;
  int saveCount = 0;

  @override
  Future<UserProfile?> load() async => stored;

  @override
  Future<void> save(UserProfile profile) async {
    stored = profile;
    saveCount++;
  }

  @override
  Future<void> clear() async {
    stored = null;
  }
}

class _ThrowingQazaPlanService extends QazaPlanService {
  _ThrowingQazaPlanService();

  @override
  QazaPlan? planFor(UserProfile profile) {
    throw StateError('QazaPlanService must not be called for skip onboarding');
  }
}

class _ThrowingImportController extends QazaImportController {
  @override
  QazaImportTaskState build() => const QazaImportTaskState();

  @override
  bool start({
    required String userId,
    required Iterable<DateTime> dates,
    required Iterable<PrayerType> prayers,
    required QazaOperationType operationType,
    required Map<String, dynamic> inputSnapshot,
    DateTime? earliestDate,
    DateTime? today,
    bool witrAllowed = true,
  }) {
    throw StateError('QazaImportController must not start for skip onboarding');
  }
}

void main() {
  testWidgets('skip previous Qaza finalizes profile without calculating or importing',
      (tester) async {
    final repository = _FakeUserProfileRepository();
    final profile = UserProfile(
      languageCode: 'en',
      gender: Gender.male,
      madhab: Madhab.hanafi,
      dateOfBirth: DateTime(2000, 1, 1),
      pubertyAge: 12,
      startPrayingAge: 15,
      witrIncluded: true,
      onboardingCompleted: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileRepositoryProvider.overrideWithValue(repository),
          qazaPlanServiceProvider
              .overrideWithValue(_ThrowingQazaPlanService()),
          qazaImportProvider
              .overrideWith(_ThrowingImportController.new),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProfileSetupScreen(
            languageCode: 'en',
            previousQazaChoice: PreviousQazaChoice.skip,
            initialProfile: profile,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('profile_submit')));
    await tester.pumpAndSettle();

    expect(repository.stored, isNotNull);
    expect(repository.stored!.onboardingCompleted, isTrue);
  });
}
