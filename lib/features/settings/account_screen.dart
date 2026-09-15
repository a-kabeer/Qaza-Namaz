import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/confirmation_dialog.dart';
import '../../domain/entities/app_user.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider) ?? const AppUser(id: '', email: '');
    final scheme = Theme.of(context).colorScheme;
    final name = user.displayName == null || user.displayName!.isEmpty ? user.email : user.displayName!;
    final hasPhoto = user.photoUrl != null && user.photoUrl!.isNotEmpty;

    Future<void> signOut() async {
      final confirmed = await confirmDestructive(
        context,
        title: 'Sign out?',
        message: 'Signing out returns you to the welcome screen. Your saved Qaza records are NOT deleted and will be restored the next time you sign in.',
        confirmLabel: 'Sign out',
      );
      if (!confirmed) return;
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) Navigator.maybePop(context);
    }

    return AppScaffold(
      title: 'Account',
      onBack: () => Navigator.maybePop(context),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: scheme.primaryContainer,
                  foregroundImage: hasPhoto ? NetworkImage(user.photoUrl!) : null,
                  child: Icon(Icons.person_rounded, color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(user.email.isEmpty ? 'Signed in with Google' : user.email),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: EdgeInsets.zero,
            child: const Column(
              children: [
                ListTile(leading: Icon(Icons.password_rounded), title: Text('Sign-in method'), subtitle: Text('Google authentication')),
                ListTile(leading: Icon(Icons.verified_user_rounded), title: Text('Account status'), subtitle: Text('Signed in')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Developer context', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          AppCard(padding: EdgeInsets.zero, child: ListTile(leading: const Icon(Icons.code_rounded), title: const Text('Firebase UID'), subtitle: Text(user.id.isEmpty ? 'Not available' : user.id))),
          const SizedBox(height: 24),
          AppCard(
            color: scheme.errorContainer.withValues(alpha: .35),
            padding: EdgeInsets.zero,
            onTap: signOut,
            child: ListTile(
              leading: Icon(Icons.logout, color: scheme.error),
              title: Text('Sign out', style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600)),
              subtitle: const Text('Your saved Qaza records remain stored and will be restored after the next sign-in.'),
            ),
          ),
        ],
      ),
    );
  }
}
