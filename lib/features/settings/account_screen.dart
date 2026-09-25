import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/widgets/app_card.dart';
import '../../l10n/app_localizations.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/date_display.dart';
import '../../data/sync/sync_state.dart' as sync_models;
import '../../core/widgets/confirmation_dialog.dart';
import '../../domain/entities/app_user.dart';
import 'settings_screen.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final signedInUser = ref.watch(currentUserProvider);
    final user = signedInUser ?? const AppUser(id: '', email: '');
    final scheme = Theme.of(context).colorScheme;
    final name = user.displayName == null || user.displayName!.isEmpty
        ? user.email
        : user.displayName!;
    final hasPhoto = user.photoUrl != null && user.photoUrl!.isNotEmpty;

    Future<void> signOut() async {
      final confirmed = await confirmDestructive(
        context,
        title: l10n.accountSignOutPrompt,
        message: l10n.accountSignOutExplanation,
        confirmLabel: l10n.accountSignOut,
      );
      if (!confirmed) return;
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) Navigator.maybePop(context);
    }

    return AppScaffold(
      title: l10n.accountTitle,
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
                  foregroundImage:
                      hasPhoto ? NetworkImage(user.photoUrl!) : null,
                  child: Icon(Icons.person_rounded,
                      color: scheme.onPrimaryContainer),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(user.email.isEmpty
                          ? l10n.accountSignedInWithGoogle
                          : user.email),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                    leading: const Icon(Icons.password_rounded),
                    title: Text(l10n.accountSignInMethod),
                    subtitle: Text(l10n.accountGoogleAuth)),
                ListTile(
                    leading: const Icon(Icons.verified_user_rounded),
                    title: Text(l10n.accountStatus),
                    subtitle: Text(l10n.accountSignedIn)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final summary = ref.watch(progressSummaryProvider).valueOrNull;
              final offline = ref.watch(offlineRepositoryProvider);
              final syncState =
                  ref.watch(syncStateProvider).valueOrNull ?? offline?.currentState;
              final deletedAt = signedInUser == null
                  ? null
                  : ref.watch(cloudDataDeletedAtProvider(signedInUser.id)).valueOrNull;
              final cloudDeleted = signedInUser != null &&
                  deletedAt != null &&
                  !(syncState?.lastSyncAt?.isAfter(deletedAt) ?? false);
              final syncText = cloudDeleted
                  ? l10n.cloudBackupDeleted
                  : switch (syncState?.status) {
                sync_models.SyncStatus.synced => l10n.cloudSynced,
                sync_models.SyncStatus.syncing => l10n.cloudSyncing,
                sync_models.SyncStatus.pendingSync ||
                sync_models.SyncStatus.partiallySynced =>
                  l10n.cloudPendingCount(syncState?.pendingCount ?? 0),
                sync_models.SyncStatus.offline => l10n.cloudOffline,
                sync_models.SyncStatus.retrying => l10n.cloudSyncing,
                sync_models.SyncStatus.syncError => l10n.cloudSyncProblem,
                _ => l10n.cloudInactive,
              };
              return AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cloud_outlined),
                      title: Text(l10n.cloudBackupStatus),
                      subtitle: Text(syncText),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.checklist_outlined),
                      title: Text(l10n.cloudQazaCount),
                      subtitle: Text(
                        summary == null
                            ? l10n.dataProcessing
                            : l10n.cloudQazaCountValue(summary.overall.total),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.schedule_outlined),
                      title: Text(l10n.cloudLastSynced),
                      subtitle: Text(formatAppDateTime(syncState?.lastSyncAt)),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          AppCard(
            color: scheme.errorContainer.withValues(alpha: .35),
            padding: EdgeInsets.zero,
            onTap: signOut,
            child: ListTile(
              leading: Icon(Icons.logout, color: scheme.error),
              title: Text(l10n.accountSignOut,
                  style: TextStyle(
                      color: scheme.error, fontWeight: FontWeight.w600)),
              subtitle: Text(l10n.accountRecordsRetained),
            ),
          ),
        ],
      ),
    );
  }
}
