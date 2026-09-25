
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/entities/user_profile.dart';
import 'profile_form.dart';

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

  @override
  void initState() {
    super.initState();
    _draft = widget.initialProfile ??
        UserProfile(languageCode: widget.languageCode);
  }

  Future<void> _saveDraft(UserProfile profile) async {
    _draft = profile;
    await ref.read(userProfileRepositoryProvider).save(
          profile.copyWith(onboardingCompleted: false),
        );
  }

  Future<void> _submit(UserProfile profile) async {
    await ref.read(userProfileRepositoryProvider).save(profile);
    ref.invalidate(userProfileProvider);
    if (mounted) Navigator.of(context).pop();
  }

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
