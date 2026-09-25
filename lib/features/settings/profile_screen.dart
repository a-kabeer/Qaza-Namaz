import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/services/profile_rules.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/profile_form.dart';

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
            submitLabel: l10n.profileSave,
            onChanged: (next) => _profile = next,
            onSubmit: _save,
          );
        },
      ),
    );
  }

  Future<void> _save(UserProfile profile) async {
    await ref.read(userProfileRepositoryProvider).save(
          profile.copyWith(
            onboardingCompleted: true,
            witrIncluded: ProfileRules.effectiveWitr(profile),
          ),
        );
    ref.invalidate(userProfileProvider);
    if (mounted) Navigator.of(context).pop();
  }
}
