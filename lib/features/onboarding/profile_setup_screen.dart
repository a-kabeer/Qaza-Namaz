import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/services/profile_rules.dart';
import '../../domain/services/profile_qaza_plan_reconciliation_service.dart';
import '../../l10n/app_localizations.dart';
import '../qaza/qaza_import_controller.dart';
import '../qaza/qaza_import_progress_dialog.dart';
import 'profile_form.dart';
import 'qaza_review_dialog.dart';
import 'startup_gate.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({
    super.key,
    required this.languageCode,
    this.initialProfile,
  });

  final String languageCode;
  final UserProfile? initialProfile;

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  late UserProfile _draft;
  Future<void> _saveQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _draft =
        widget.initialProfile ?? UserProfile(languageCode: widget.languageCode);
  }

  void _saveDraft(UserProfile profile) {
    _draft = profile;
    final repository = ref.read(userProfileRepositoryProvider);
    _saveQueue = _saveQueue.then(
      (_) => repository.saveLocalOnly(
        profile.copyWith(onboardingCompleted: false),
      ),
    );
  }

  Future<void> _submit(UserProfile profile) async {
    await _saveQueue;

    // Onboarding is always scoped to the account selected by the
    // account/session layer. Never force the Guest partition here.
    if (ref.read(activeUserIdProvider) == null) {
      throw StateError('No active local account exists for onboarding.');
    }

    final finalizedProfile = profile.copyWith(
      witrIncluded: ProfileRules.effectiveWitr(profile),
      onboardingCompleted: true,
    );

    final plan = ref.read(qazaPlanServiceProvider).planFor(finalizedProfile);
    if (plan == null) {
      throw StateError('A valid Qaza plan could not be calculated.');
    }

    // A zero-day/zero-record calculation is valid. There is nothing to
    // review or import, so onboarding can finish normally.
    // QazaPlan currently represents exactly five Fard prayers per day plus
    // the optional Witr count, so this is the domain result's exact number
    // of records this onboarding import would generate before duplicates.
    final revisionId = ProfileQazaPlanReconciliationService.newRevisionId();

    if (plan.totalWithWitr == 0) {
      await ref.read(qazaImportProvider.notifier).commitOnboarding(
            userId: ref.read(requiredUserIdProvider),
            profile: finalizedProfile,
            plan: plan,
            revisionId: revisionId,
          );
      if (!mounted) return;
      if (ref.read(qazaImportProvider).phase == QazaImportTaskPhase.failed) {
        await _showImportProgress();
      }
      if (!mounted) return;
      if (ref.read(qazaImportProvider).phase == QazaImportTaskPhase.completed) {
        ref.invalidate(userProfileProvider);
        ref.invalidate(progressSummaryProvider);
        _navigateHome();
      }
      return;
    }

    // The onboarding profile was created/updated locally above, but the
    // shared provider may still hold the pre-onboarding cached value. Refresh
    // it before the Qaza import so the local repository activates the ledger.
    ref.invalidate(userProfileProvider);
    await ref.read(userProfileProvider.future);

    if (!mounted) return;

    final action = await showDialog<QazaReviewAction>(
      context: context,
      barrierDismissible: false,
      builder: (_) => QazaReviewDialog(
        profile: finalizedProfile,
        plan: plan,
        onConfirm: () => _startQazaPlanImport(
          plan,
          finalizedProfile,
          revisionId: revisionId,
        ),
      ),
    );

    if (!mounted || action != QazaReviewAction.add) return;

    await _showImportProgress();

    if (!mounted) return;
    if (ref.read(qazaImportProvider).phase == QazaImportTaskPhase.completed) {
      ref.invalidate(userProfileProvider);
      ref.invalidate(progressSummaryProvider);
      _navigateHome();
    }
  }

  Future<void> _showImportProgress() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const QazaImportProgressDialog(),
    );
  }

  void _navigateHome() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const StartupGate(),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileSetupTitle),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ProfileForm(
                initialProfile: _draft,
                submitLabel: l10n.profileSubmit,
                onChanged: _saveDraft,
                onSubmit: _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
