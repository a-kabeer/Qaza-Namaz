import 'dart:async';

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
import 'profile_overview.dart';
import 'profile_qaza_change_dialog.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserProfile? _draftProfile;
  UserProfile? _originalProfile;
  bool _isEditing = false;
  int _editSession = 0;

  bool get _hasDraftChanges {
    final original = _originalProfile;
    final draft = _draftProfile;
    if (original == null || draft == null) return false;

    return original.languageCode != draft.languageCode ||
        original.dailyQazaTarget != draft.dailyQazaTarget ||
        original.gender != draft.gender ||
        original.madhab != draft.madhab ||
        !_sameDate(original.dateOfBirth, draft.dateOfBirth) ||
        original.pubertyAge != draft.pubertyAge ||
        original.startPrayingAge != draft.startPrayingAge ||
        ProfileRules.effectiveWitr(original) !=
            ProfileRules.effectiveWitr(draft);
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final hijriOffset = ref.watch(hijriDateAdjustmentProvider).valueOrNull ?? 0;
    final l10n = AppLocalizations.of(context);

    return PopScope<void>(
      canPop: !_isEditing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isEditing) {
          unawaited(_handleBackWhileEditing());
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.profileTitle)),
        body: profileAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline),
                  const SizedBox(height: 12),
                  Text(
                    l10n.errorUnknown,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => ref.invalidate(userProfileProvider),
                    child: Text(l10n.commonRetry),
                  ),
                ],
              ),
            ),
          ),
          data: (loaded) {
            if (loaded == null) {
              return Center(child: Text(l10n.profileErrorDob));
            }

            if (!_isEditing) {
              return ProfileOverview(
                profile: loaded,
                onEdit: () => _startEditing(loaded),
              );
            }

            return ProfileForm(
              key: ValueKey<int>(_editSession),
              initialProfile: _draftProfile ?? loaded,
              hijriOffsetDays: hijriOffset,
              showIntro: false,
              showDailyQazaTarget: true,
              submitLabel: l10n.profileSave,
              onChanged: (next) {
                _draftProfile = next;
              },
              onCancel: _cancelEditing,
              onSubmit: _save,
            );
          },
        ),
      ),
    );
  }

  void _startEditing(UserProfile profile) {
    setState(() {
      _originalProfile = profile;
      _draftProfile = profile;
      _isEditing = true;
      _editSession++;
    });
  }

  void _cancelEditing() {
    if (!mounted) return;
    setState(_leaveEditMode);
  }

  void _leaveEditMode() {
    _isEditing = false;
    _draftProfile = null;
    _originalProfile = null;
  }

  Future<void> _handleBackWhileEditing() async {
    if (!_isEditing) return;

    if (!_hasDraftChanges) {
      _cancelEditing();
      return;
    }

    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileDiscardChangesTitle),
        content: Text(l10n.profileDiscardChangesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const Key('profile_discard_changes'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.profileDiscardChangesAction),
          ),
        ],
      ),
    );

    if (!mounted || discard != true) return;
    _cancelEditing();
  }

  static bool _sameDate(DateTime? first, DateTime? second) {
    if (first == null || second == null) return first == second;
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
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
          previousProfile: currentProfile,
          newProfile: finalizedProfile,
          hijriOffsetDays:
              ref.read(hijriDateAdjustmentProvider).valueOrNull ?? 0,
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
            previousProfile: currentProfile,
            newProfile: finalizedProfile,
            hijriOffsetDays:
                ref.read(hijriDateAdjustmentProvider).valueOrNull ?? 0,
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
        final totalWork = preview.pendingAdditionKeys.length +
            preview.removalRecordIds.length;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => QazaImportProgressDialog(
            title: l10n.profileQazaApplying,
            onStart: () {
              final started =
                  ref.read(qazaImportProvider.notifier).startProfilePlanApply(
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
      final result = saveResult!;

      final message = result.qazaPlanChanged
          ? l10n.profileQazaUpdatedCounts(
              result.qazaRecordsAdded,
              result.qazaRecordsRemoved,
            )
          : l10n.profileQazaUpdatedNoChange;
      snackbar.success(message);
      setState(_leaveEditMode);
    } catch (_) {
      if (!mounted) return;
      snackbar.error(l10n.errorUnknown);
    }
  }
}
