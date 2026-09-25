import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/services/profile_rules.dart';
import '../../l10n/app_localizations.dart';
import '../auth/backup_prompt.dart';
import '../auth/guest_upgrade_controller.dart';
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
          return Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _GoogleAccountSection(ref: ref),
              ),
              const SizedBox(height: 4),
              const Divider(height: 1),
              Expanded(
                child: ProfileForm(
                  initialProfile: profile,
                  showIntro: false,
                  submitLabel: l10n.profileSave,
                  onChanged: (next) => _profile = next,
                  onSubmit: _save,
                ),
              ),
            ],
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

class _GoogleAccountSection extends ConsumerWidget {
  const _GoogleAccountSection({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final upgrade = ref.watch(guestUpgradeControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    if (user == null) {
      return AppCard(
        key: const Key('profile_google_account'),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(
                    Icons.account_circle_outlined,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.accountSignInMethod,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.backupPromptBody,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                key: const Key('profile_continue_google'),
                onPressed: upgrade.running
                    ? null
                    : () => startBackupSignIn(context, ref),
                icon: upgrade.running
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.g_mobiledata_rounded),
                label: Text(l10n.authContinueWithGoogle),
              ),
            ),
          ],
        ),
      );
    }

    final displayName = user.displayName?.trim();
    final name = displayName == null || displayName.isEmpty
        ? user.email
        : displayName;
    final photo = user.photoUrl?.trim();
    final hasPhoto = photo != null && photo.isNotEmpty;

    Future<void> signOut() async {
      final confirmed = await confirmDestructive(
        context,
        title: l10n.accountSignOutPrompt,
        message: l10n.accountSignOutExplanation,
        confirmLabel: l10n.accountSignOut,
      );
      if (!confirmed || !context.mounted) return;
      await ref.read(authRepositoryProvider).signOut();
    }

    return AppCard(
      key: const Key('profile_google_account'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: scheme.primaryContainer,
                foregroundImage: hasPhoto ? NetworkImage(photo!) : null,
                child: Icon(
                  Icons.person_rounded,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      key: const Key('profile_google_name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      key: const Key('profile_google_email'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              key: const Key('profile_sign_out'),
              onPressed: signOut,
              icon: const Icon(Icons.logout_rounded),
              label: Text(l10n.accountSignOut),
            ),
          ),
        ],
      ),
    );
  }
}
