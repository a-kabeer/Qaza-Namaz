import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/services/profile_qaza_plan_reconciliation_service.dart';
import '../../domain/services/profile_rules.dart';
import '../../domain/services/save_profile_use_case.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/profile_form.dart';
import '../qaza/qaza_import_controller.dart';
import '../qaza/qaza_import_progress_dialog.dart';
import 'profile_qaza_change_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserProfile? _profile;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (loaded) {
          if (loaded == null) {
            return Center(child: Text(l10n.profileErrorDob));
          }

          final profile = _profile ?? loaded;
          return ProfileForm(
            initialProfile: profile,
            showIntro: false,
            showDailyQazaTarget: true,
            submitLabel: l10n.profileSave,
            onChanged: (next) => _profile = next,
            onSubmit: _save,
          );
        },
      ),
    );
  }

  Future<void> _save(UserProfile profile) async {
    final finalizedProfile = profile.copyWith(
      onboardingCompleted: true,
      witrIncluded: ProfileRules.effectiveWitr(profile),
    );
    final useCase = ref.read(saveProfileUseCaseProvider);
    final snackbar = ref.read(appSnackbarServiceProvider);
    final l10n = AppLocalizations.of(context);

    try {
      final currentProfile = ref.read(userProfileProvider).valueOrNull;
      final calculationFieldsChanged = currentProfile == null
          ? true
          : ProfileQazaPlanReconciliationService.changedProfileFields(
              ProfileQazaPlanReconciliationService.profileSnapshot(
                currentProfile,
              ),
              ProfileQazaPlanReconciliationService.profileSnapshot(
                finalizedProfile,
              ),
            ).isNotEmpty;

      ProfileQazaPlanPreview preview;
      ProfileQazaChangeChoice choice;

      if (calculationFieldsChanged) {
        final review = await showProfileQazaChangeDialog(
          context: context,
          preview: useCase.prepareSettingsSave(newProfile: finalizedProfile),
        );
        if (!mounted || review == null || review.choice == null) return;
        preview = review.preview;
        choice = review.choice!;
      } else {
        preview = await useCase.prepareSettingsSave(
          newProfile: finalizedProfile,
        );
        if (!mounted) return;

        if (preview.requiresUserDecision) {
          final review = await showProfileQazaChangeDialog(
            context: context,
            preview: preview,
          );
          if (!mounted || review == null || review.choice == null) return;
          preview = review.preview;
          choice = review.choice!;
        } else {
          choice = ProfileQazaChangeChoice.apply;
        }
      }

      ProfileSaveResult? saveResult;
      if (preview.requiresUserDecision) {
        final totalWork =
            preview.pendingAdditionKeys.length + preview.removalRecordIds.length;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => QazaImportProgressDialog(
            title: l10n.profileQazaApplying,
            onStart: () {
              final started = ref
                  .read(qazaImportProvider.notifier)
                  .startProfilePlanApply(
                    total: totalWork,
                    operation: (onProgress) async {
                      saveResult = await useCase.saveSettings(
                        newProfile: finalizedProfile,
                        preview: preview,
                        choice: choice,
                        onProgress: onProgress,
                      );
                    },
                  );
              if (!started) {
                throw StateError('Could not start profile Qaza update.');
              }
            },
          ),
        );

        if (!mounted) return;
        if (ref.read(qazaImportProvider).phase !=
            QazaImportTaskPhase.completed) {
          return;
        }
      } else {
        saveResult = await useCase.saveSettings(
          newProfile: finalizedProfile,
          preview: preview,
          choice: choice,
        );
      }

      ref.invalidate(userProfileProvider);
      ref.invalidate(progressSummaryProvider);
      ref.invalidate(enabledPrayerTypesProvider);
      ref.invalidate(effectiveWitrProvider);

      if (!mounted || saveResult == null) return;

      final message = saveResult.qazaPlanChanged
          ? l10n.profileQazaUpdatedCounts(
              saveResult.qazaRecordsAdded,
              saveResult.qazaRecordsRemoved,
            )
          : l10n.profileQazaUpdatedNoChange;
      snackbar.success(message);
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      snackbar.error(l10n.errorUnknown);
    }
  }
}
