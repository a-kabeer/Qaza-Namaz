import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qaza_namaz/app/providers.dart';
import 'package:qaza_namaz/core/constants/prayer_types.dart';
import 'package:qaza_namaz/domain/entities/qaza_operation.dart';
import 'package:qaza_namaz/domain/entities/user_profile.dart';
import 'package:qaza_namaz/domain/repositories/user_profile_repository.dart';
import 'package:qaza_namaz/domain/services/qaza_plan_service.dart';
import 'package:qaza_namaz/features/onboarding/profile_setup_screen.dart';
import 'package:qaza_namaz/features/qaza/qaza_import_controller.dart';
import 'package:qaza_namaz/features/shell/workspace_shell.dart';
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

class _OneDayQazaPlanService extends QazaPlanService {
  _OneDayQazaPlanService();

  @override
  QazaPlan? planFor(UserProfile profile) {
    return QazaPlan(
      startDate: DateTime(2012, 1, 1),
      endDate: DateTime(2012, 1, 2),
      totalDays: 1,
      includeWitr: false,
      totalPrayers: 5,
      prayerBreakdown: {
        for (final prayer in PrayerType.values)
          if (prayer != PrayerType.witr) prayer: 1,
      },
    );
  }
}

class _CompletingImportController extends QazaImportController {
  String? startedUserId;

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
    startedUserId = userId;
    state = QazaImportTaskState(
      phase: QazaImportTaskPhase.completed,
      userId: userId,
      processed: 5,
      total: 5,
      added: 5,
      completedAt: DateTime.now(),
    );
    return true;
  }
}

void main() {
  testWidgets(
    'profile onboarding imports Qaza after activating the saved local ledger',
    (tester) async {
      final repository = _FakeUserProfileRepository();
      final importController = _CompletingImportController();
      final initialProfile = UserProfile(
        languageCode: 'en',
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
            qazaPlanServiceProvider.overrideWithValue(
              _OneDayQazaPlanService(),
            ),
            qazaImportProvider.overrideWith(
              () => importController,
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ProfileSetupScreen(
              languageCode: 'en',
              initialProfile: initialProfile,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('profile_gender')),
          matching: find.text('Male'),
        ),
      );
      await tester.pump();

      await tester.scrollUntilVisible(
        find.byKey(const Key('profile_submit')),
        500,
        scrollable: find.byType(Scrollable),
      );
      await tester.tap(find.byKey(const Key('profile_submit')));
      // ProfileForm keeps its saving indicator active while the review dialog
      // is open, so pumpAndSettle() would wait forever on that animation.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const Key('qaza_review_add')), findsOneWidget);

      await tester.tap(find.byKey(const Key('qaza_review_add')));
      for (var i = 0;
          i < 20 && find.byType(WorkspaceShell).evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(importController.startedUserId, UserProfile.localLedgerUserId);
      expect(find.byType(WorkspaceShell), findsOneWidget);
      expect(
        find.text('Retry'),
        findsNothing,
      );
      expect(repository.stored?.onboardingCompleted, isTrue);
      expect(repository.saveCount, greaterThan(1));
    },
  );
}
