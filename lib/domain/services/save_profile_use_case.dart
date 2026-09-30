import '../entities/qaza_plan_revision.dart';
import '../entities/user_profile.dart';
import 'profile_qaza_plan_reconciliation_service.dart';
import 'qaza_plan_service.dart';
import '../repositories/user_profile_repository.dart';

class ProfileSaveResult {
  const ProfileSaveResult({
    required this.qazaPlanChanged,
    required this.qazaRecordsAdded,
    required this.qazaRecordsRemoved,
    required this.keptExistingQaza,
    this.revision,
  });

  final bool qazaPlanChanged;
  final int qazaRecordsAdded;
  final int qazaRecordsRemoved;
  final bool keptExistingQaza;
  final QazaPlanRevision? revision;

  bool get ledgerChanged =>
      qazaRecordsAdded > 0 || qazaRecordsRemoved > 0;
}

class SaveProfileUseCase {
  SaveProfileUseCase({
    required UserProfileRepository profileRepository,
    required ProfileQazaPlanReconciliationService reconciliationService,
  })  : _profileRepository = profileRepository,
        _reconciliationService = reconciliationService;

  final UserProfileRepository _profileRepository;
  final ProfileQazaPlanReconciliationService _reconciliationService;

  Future<void> saveDraft(UserProfile profile) {
    return _profileRepository.save(
      profile.copyWith(onboardingCompleted: false),
    );
  }

  Future<ProfileQazaPlanPreview> prepareSettingsSave({
    required UserProfile newProfile,
  }) async {
    final oldProfile = await _profileRepository.load();
    if (oldProfile == null || !oldProfile.isComplete) {
      throw StateError('A completed profile is required for profile editing.');
    }
    return _reconciliationService.preview(
      userId: UserProfile.localLedgerUserId,
      oldProfile: oldProfile,
      newProfile: newProfile,
    );
  }

  Future<ProfileSaveResult> saveSettings({
    required UserProfile newProfile,
    required ProfileQazaPlanPreview preview,
    required ProfileQazaChangeChoice choice,
  }) async {
    final oldProfile = await _profileRepository.load();
    if (oldProfile == null || !oldProfile.isComplete) {
      throw StateError('A completed profile is required for profile editing.');
    }

    if (!preview.calculationChanged) {
      await _profileRepository.save(newProfile);
      return ProfileSaveResult(
        qazaPlanChanged: false,
        qazaRecordsAdded: 0,
        qazaRecordsRemoved: 0,
        keptExistingQaza: false,
        revision: preview.oldRevision,
      );
    }

    await _profileRepository.save(newProfile);
    try {
      final result = await _reconciliationService.apply(
        userId: UserProfile.localLedgerUserId,
        newProfile: newProfile,
        preview: preview,
        choice: choice,
      );
      return ProfileSaveResult(
        qazaPlanChanged: true,
        qazaRecordsAdded: result.added,
        qazaRecordsRemoved: result.removed,
        keptExistingQaza: result.keptExisting,
        revision: result.revision,
      );
    } catch (error) {
      // Restore the previous profile so a failed reconciliation never leaves
      // the profile pointing at a calculation that was not successfully saved.
      try {
        await _profileRepository.save(oldProfile);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> completeOnboarding({
    required UserProfile profile,
    required QazaPlan plan,
    String? generatedOperationId,
  }) async {
    await _profileRepository.save(profile);
    await _reconciliationService.recordInitialPlan(
      userId: UserProfile.localLedgerUserId,
      profile: profile,
      plan: plan,
      generatedOperationId: generatedOperationId,
    );
  }
}
