import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import 'authentication_screen.dart';
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

/// Signs in and reports what actually happened, from the prompt or Settings.
///
/// This used to report two outcomes: success, meaning
/// "{migrationDone}", and everything else, meaning
/// "{signInFailed}". Both were wrong.
/// A guest with existing records does not finish signing in at this point —
/// they still owe a Merge / Use Account / Keep Guest decision — so the done
/// message appeared before anything had been migrated. And the failure branch
/// swallowed the real error and also fired on a plain cancellation.
///
/// Started as [GuestUpgradeOrigin.inApp] so `AuthGate` leaves the caller's
/// screen alone; the pending decision is resolved on a route pushed above it,
/// and a failure leaves the user where they were with a Retry.
Future<void> startBackupSignIn(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(guestUpgradeControllerProvider.notifier);

  await controller.signInAndMigrate(origin: GuestUpgradeOrigin.inApp);
  if (!context.mounted) return;

  // A guest with records now owes an explicit data decision. Nothing has been
  // merged, and nothing may be reported as done until they make it.
  if (ref.read(guestUpgradeControllerProvider).awaitingDecision) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AuthenticationScreen(closeWhenDecided: true),
      ),
    );
    if (!context.mounted) return;
  }

  _reportBackupSignIn(context, ref);
}

/// Reports the settled outcome, and offers a retry on anything recoverable.
void _reportBackupSignIn(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final state = ref.read(guestUpgradeControllerProvider);

  // Still owed: the user backed out of the decision without choosing. Their
  // guest data is untouched and the decision survives, so say nothing.
  if (state.awaitingDecision) return;

  if (state.error != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        key: const Key('backup_sign_in_failed'),
        // The real diagnostic, not a generic stand-in: a missing SHA-1 and a
        // dropped network connection need different answers from the user.
        content: Text(l10n.backupSignInFailedReason(state.error!)),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: l10n.commonRetry,
          onPressed: () => startBackupSignIn(context, ref),
        ),
      ));
    return;
  }

  // No error and still a guest: the user cancelled at the Google chooser, or
  // chose Keep Guest Data. Neither is a failure.
  if (ref.read(isGuestProvider)) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        key: const Key('backup_sign_in_cancelled'),
        content: Text(l10n.backupSignInCancelled),
      ));
    return;
  }

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      key: const Key('backup_sign_in_done'),
      content: Text(l10n.backupMigrationDone(state.migration.added)),
    ));
}
