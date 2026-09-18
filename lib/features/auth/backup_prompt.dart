import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import 'guest_upgrade_controller.dart';

/// Whether the backup prompt has been answered already.
///
/// Persisted, because "Not Now" has to mean not now *and* not every time the
/// app reopens. Signing in is the other way it is settled.
class BackupPromptNotifier extends Notifier<bool> {
  static const String storageKey = 'qaza_backup_prompt_seen';

  @override
  bool build() {
    Future.microtask(restore);
    return false;
  }

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(storageKey) ?? false) state = true;
    } catch (_) {
      // Unreadable storage only risks offering the prompt once more.
    }
  }

  Future<void> markSeen() async {
    if (state) return;
    state = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(storageKey, true);
    } catch (_) {
      // Nothing worth failing a dismissal over.
    }
  }
}

final backupPromptSeenProvider =
    NotifierProvider<BackupPromptNotifier, bool>(BackupPromptNotifier.new);

/// True when a guest has recorded their first Qaza and has not answered yet.
final shouldOfferBackupProvider = Provider<bool>((ref) {
  if (!ref.watch(isGuestProvider)) return false;
  if (ref.watch(backupPromptSeenProvider)) return false;
  final summary = ref.watch(progressSummaryProvider).valueOrNull;
  return (summary?.overall.total ?? 0) > 0;
});

/// Offers a guest a backup once they have something worth backing up.
///
/// Non-blocking in both senses: it is dismissible, and declining leaves every
/// part of the app working exactly as before.
Future<void> showBackupPrompt(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  // Marked before the dialog resolves: however it is answered, and even if
  // the app is killed while it is open, it is not offered again.
  await ref.read(backupPromptSeenProvider.notifier).markSeen();
  if (!context.mounted) return;

  final backUp = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('backup_prompt'),
      title: Text(l10n.backupPromptTitle),
      content: Text(l10n.backupPromptBody),
      actions: [
        TextButton(
          key: const Key('backup_prompt_dismiss'),
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.backupPromptDismiss),
        ),
        FilledButton(
          key: const Key('backup_prompt_confirm'),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.backupPromptConfirm),
        ),
      ],
    ),
  );

  if (backUp != true || !context.mounted) return;
  await startBackupSignIn(context, ref);
}

/// Signs in and reports what happened, from the prompt or from Settings.
Future<void> startBackupSignIn(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(guestUpgradeControllerProvider.notifier);

  final ok = await controller.signInAndMigrate();
  final migration = ref.read(guestUpgradeControllerProvider).migration;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(ok
          ? l10n.backupMigrationDone(migration.added)
          : l10n.backupSignInFailed),
    ));
}
