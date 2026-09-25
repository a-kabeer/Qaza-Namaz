
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../domain/entities/user_profile.dart';
import '../auth/auth_startup_state.dart';
import '../auth/guest_upgrade_controller.dart';
import '../../domain/services/profile_rules.dart';
import '../../domain/entities/qaza_operation.dart';
import '../../domain/services/qaza_plan_service.dart';
import '../../l10n/app_localizations.dart';
import 'profile_form.dart';
import 'qaza_review_dialog.dart';
import 'startup_gate.dart';
import '../qaza/qaza_import_controller.dart';

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
    _draft = widget.initialProfile ??
        UserProfile(languageCode: widget.languageCode);
  }

  void _saveDraft(UserProfile profile) {
    _draft = profile;
    final repository = ref.read(userProfileRepositoryProvider);
    _saveQueue = _saveQueue.then(
      (_) => repository.save(profile.copyWith(onboardingCompleted: false)),
    );
  }

  Future<void> _submit(UserProfile profile) async {
    await _saveQueue;

    final finalizedProfile = profile.copyWith(
      witrIncluded: ProfileRules.effectiveWitr(profile),
      onboardingCompleted: true,
    );
    final plan = ref.read(qazaPlanServiceProvider).planFor(finalizedProfile);
    if (plan == null) {
      throw StateError('A valid Qaza plan could not be calculated.');
    }

    final action = await showDialog<QazaReviewAction>(
      context: context,
      barrierDismissible: false,
      builder: (_) => QazaReviewDialog(
        profile: finalizedProfile,
        plan: plan,
        onConfirm: () => _startQazaPlanImport(plan),
      ),
    );

    if (!mounted || action != QazaReviewAction.add) return;

    await ref.read(userProfileRepositoryProvider).save(finalizedProfile);
    await AuthStartupState.clear();
    ref.invalidate(userProfileProvider);
    // The startup controller holds the in-session new-account handoff. Once
    // profile setup is complete, discard that transient state as well so a
    // fresh StartupGate resolves the authenticated account to Home.
    ref.invalidate(guestUpgradeControllerProvider);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const StartupGate(),
      ),
      (_) => false,
    );
  }

  Future<bool> _startQazaPlanImport(QazaPlan plan) async {
    final userId =
        ref.read(authRepositoryProvider).currentUser?.id ??
        UserProfile.localLedgerUserId;
    final dates = _planDates(plan).toList(growable: false);
    final prayers = _planPrayerTypes(plan).toSet();
    final inputSnapshot = <String, dynamic>{
      'version': 1,
      'startDate': plan.startDate.toIso8601String(),
      'endDate': plan.endDate.toIso8601String(),
      'totalDays': plan.totalDays,
      'includeWitr': plan.includeWitr,
      'prayers': prayers.map((prayer) => prayer.name).toList(growable: false),
    };
    return ref.read(qazaImportProvider.notifier).start(
      userId: userId,
      dates: dates,
      prayers: prayers,
      operationType: QazaOperationType.calculatorImport,
      inputSnapshot: inputSnapshot,
    );
  }

  Iterable<DateTime> _planDates(QazaPlan plan) sync* {
    for (var offset = 0; offset < plan.totalDays; offset++) {
      yield plan.startDate.add(Duration(days: offset));
    }
  }

  List<PrayerType> _planPrayerTypes(QazaPlan plan) => [
        PrayerType.fajr,
        PrayerType.zuhr,
        PrayerType.asr,
        PrayerType.maghrib,
        PrayerType.isha,
        if (plan.includeWitr) PrayerType.witr,
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(l10n.profileSetupTitle),
      ),
      body: SafeArea(
        child: ProfileForm(
          initialProfile: _draft,
          submitLabel: l10n.profileSubmit,
          onChanged: _saveDraft,
          onSubmit: _submit,
        ),
      ),
    );
  }
}
