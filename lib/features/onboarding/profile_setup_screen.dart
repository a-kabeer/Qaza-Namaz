
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/constants/prayer_types.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/services/profile_rules.dart';
import '../../domain/services/qaza_plan_service.dart';
import '../../l10n/app_localizations.dart';
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

    final added = await showDialog<int>(
      context: context,
      barrierDismissible: false,
      builder: (_) => QazaReviewDialog(
        profile: finalizedProfile,
        plan: plan,
        onConfirm: _addQazaPlan,
      ),
    );

    if (!mounted || added == null) return;

    await ref.read(userProfileRepositoryProvider).save(finalizedProfile);
    ref.invalidate(userProfileProvider);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const StartupGate(),
      ),
      (_) => false,
    );
  }

  Future<int> _addQazaPlan(
    void Function(int processed, int total) onProgress,
  ) {
    final plan = ref.read(qazaPlanServiceProvider).planFor(_draft);
    if (plan == null) {
      throw StateError('A valid Qaza plan could not be calculated.');
    }

    return ref.read(qazaServiceProvider).recordQazaForDates(
          userId: UserProfile.localLedgerUserId,
          dates: _planDates(plan),
          prayerTypes: _planPrayerTypes(plan),
          batchSize: 500,
          onProgress: onProgress,
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
