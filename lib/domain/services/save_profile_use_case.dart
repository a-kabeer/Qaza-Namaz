import '../../core/diagnostics/diagnostics.dart';
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
    DiagnosticsService diagnostics = const NoopDiagnostics(),
  })  : _profileRepository = profileRepository,
        _reconciliationService = reconciliationService,
        _diagnostics = diagnostics;

  final UserProfileRepository _profileRepository;
  final ProfileQazaPlanReconciliationService _reconciliationService;
  final DiagnosticsService _diagnostics;

  Future<void> saveDraft(UserProfile profile) {
    return _profileRepository.saveLocalOnly(
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
    try {
      return await _reconciliationService.preview(
        userId: UserProfile.localLedgerUserId,
        oldProfile: oldProfile,
        newProfile: newProfile,
      );
    } catch (error, stack) {
      _diagnostics.recordFailure(
        DiagnosticArea.uncaught,
        'profile_settings_prepare_failed',
        error,
        stack: stack,
      );
      rethrow;
    }
  }

  Future<ProfileSaveResult> saveSettings({
    required UserProfile newProfile,
    required ProfileQazaPlanPreview preview,
    required ProfileQazaChangeChoice choice,
    void Function(int processed, int total)? onProgress,
  }) async {
    final oldProfile = await _profileRepository.load();
    if (oldProfile == null || !oldProfile.isComplete) {
      throw StateError('A completed profile is required for profile editing.');
    }

    if (!preview.calculationChanged) {
      // Non-calculation profile edits (for example language or the daily
      // target) do not create a Qaza-plan revision. Revisions are an audit
      // trail for changes to the calculated Qaza scope, not every profile edit.
      await _profileRepository.save(newProfile);
      return const ProfileSaveResult(
        qazaPlanChanged: false,
        qazaRecordsAdded: 0,
        qazaRecordsRemoved: 0,
        keptExistingQaza: false,
      );
    }

    await _profileRepository.save(newProfile);
    try {
      final result = await _reconciliationService.apply(
        userId: UserProfile.localLedgerUserId,
        newProfile: newProfile,
        preview: preview,
        choice: choice,
        onProgress: onProgress,
      );
      return ProfileSaveResult(
        qazaPlanChanged: true,
        qazaRecordsAdded: result.added,
        qazaRecordsRemoved: result.removed,
        keptExistingQaza: false,
        revision: result.revision,
      );
    } catch (error, stack) {
      _diagnostics.recordFailure(
        DiagnosticArea.uncaught,
        'profile_settings_save_failed',
        error,
        stack: stack,
      );
      // Restore the previous profile so a failed reconciliation never leaves
      // the profile pointing at a calculation that was not successfully saved.
      try {
        await _profileRepository.save(oldProfile);
      } catch (_) {}
      rethrow;
    }
  }


}
